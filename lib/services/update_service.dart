import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // =========================================================================
  // IMPORTANT: Ensure this matches your GitHub username and repository name!
  // =========================================================================
  static const String repoOwner = "Ragsie";
  static const String repoName = "OmniMow_App"; // Your GitHub repository name

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String currentVersion = packageInfo.version;

      // We call the full /releases list endpoint instead of /releases/latest.
      // Why? Because /releases/latest completely ignores pre-releases (which our rolling release is)!
      // Calling /releases returns a list of all releases (including pre-releases) sorted by date (newest first).
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases');
      
      if (showNoUpdateDialog) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Checking for updates in $repoOwner/$repoName..."),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode != 200) {
        debugPrint("GitHub API error: ${response.statusCode} - ${response.body}");
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("API Error (${response.statusCode}). Is the repo name correct?"),
              backgroundColor: Colors.red.withOpacity(0.8),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isEmpty) {
        debugPrint("No releases found on GitHub.");
        if (showNoUpdateDialog && context.mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text("No releases found on GitHub."),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
        return;
      }

      // The first release in the array is always the absolute newest (whether rolling pre-release or stable tag)
      final releaseData = releases[0] as Map<String, dynamic>;
      final String tagName = releaseData['tag_name'] ?? '';
      final String releaseName = releaseData['name'] ?? '';
      final String bodyText = releaseData['body'] ?? 'No release notes provided.';
      final String releaseHtmlUrl = releaseData['html_url'] ?? 'https://github.com/$repoOwner/$repoName/releases/latest';

      // Smart parsing of version and build number.
      // If the tag_name is "latest" (used by our rolling development build), we extract the
      // actual version and build number from the release name: "OmniMow Latest Build (v2.1.0-64)"
      String targetString = tagName;
      if (tagName == 'latest' || !RegExp(r'\d').hasMatch(tagName)) {
        targetString = releaseName;
      }

      // 1. Extract version name (e.g. "2.1.0" or "1.0.63")
      String latestVersion = "0.0.0";
      final versionMatch = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(targetString);
      if (versionMatch != null) {
        latestVersion = versionMatch.group(1)!;
      }

      // 2. Extract build number (e.g. 64)
      int latestBuildNumber = 0;
      final dashMatch = RegExp(r'-(\d+)').firstMatch(targetString);
      if (dashMatch != null) {
        latestBuildNumber = int.tryParse(dashMatch.group(1)!) ?? 0;
      } else {
        final buildWordMatch = RegExp(r'Build\s+(\d+)', caseSensitive: false).firstMatch(targetString);
        if (buildWordMatch != null) {
          latestBuildNumber = int.tryParse(buildWordMatch.group(1)!) ?? 0;
        } else {
          final allNumbers = RegExp(r'\d+').allMatches(targetString).map((m) => m.group(0)!).toList();
          if (allNumbers.length >= 4) {
            latestBuildNumber = int.tryParse(allNumbers.last) ?? 0;
          }
        }
      }

      debugPrint("Local Build: $currentBuildNumber | GitHub Release Build: $latestBuildNumber");
      debugPrint("Local Version: $currentVersion | GitHub Release Tag/Name: $targetString");

      // Show diagnostic info if triggered manually by user
      if (showNoUpdateDialog && context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              "Local: v$currentVersion ($currentBuildNumber) | GitHub: v$latestVersion ($latestBuildNumber)",
              style: const TextStyle(fontSize: 12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // 3. Make robust semantic version and build check
      if (_isNewerVersion(latestVersion, currentVersion, latestBuildNumber, currentBuildNumber)) {
        final List assets = releaseData['assets'] ?? [];
        final apkAsset = assets.firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        final String? apkDownloadUrl = apkAsset != null ? apkAsset['browser_download_url'] : null;

        if (context.mounted) {
          _showUpdateDialog(
            context: context,
            version: "v$latestVersion-$latestBuildNumber",
            changelog: bodyText,
            apkDownloadUrl: apkDownloadUrl,
            releaseHtmlUrl: releaseHtmlUrl,
          );
        }
      } else if (showNoUpdateDialog && context.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("OmniMow is up to date! You have the latest version."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Network or unexpected error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Robust comparison algorithm that checks both versions (major.minor.patch) and build numbers
  static bool _isNewerVersion(String latestVersionStr, String currentVersionStr, int latestBuild, int currentBuild) {
    final String cleanLatest = latestVersionStr.replaceAll(RegExp(r'[^0-9.]'), '');
    final String cleanCurrent = currentVersionStr.replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleanLatest.isEmpty || cleanCurrent.isEmpty) {
      return latestBuild > currentBuild;
    }

    final List<int> latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final List<int> currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final int maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    while (latestParts.length < maxLen) latestParts.add(0);
    while (currentParts.length < maxLen) currentParts.add(0);

    for (int i = 0; i < maxLen; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    return latestBuild > currentBuild;
  }

  static void _showUpdateDialog({
    required BuildContext context,
    required String version,
    required String changelog,
    required String? apkDownloadUrl,
    required String releaseHtmlUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("New Update Available ($version)"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Changelog:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(changelog),
              if (Platform.isIOS) ...[
                const SizedBox(height: 12),
                const Text(
                  "Note: On iOS, this will open the GitHub releases page in your browser so you can download the package and sideload it using Sideloadly.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Later"),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (Platform.isIOS) {
                final uri = Uri.parse(releaseHtmlUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } else if (Platform.isAndroid && apkDownloadUrl != null) {
                _downloadAndInstallApk(context, apkDownloadUrl);
              }
            },
            child: Text(Platform.isIOS ? "Open Release" : "Update Now"),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstallApk(BuildContext context, String url) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text("Downloading update...")),
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Download failed with status code: ${response.statusCode}")),
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      
      if (await file.exists()) {
        await file.delete();
      }

      await file.writeAsBytes(response.bodyBytes, flush: true);

      final result = await OpenFilex.open(
        file.path,
        type: "application/vnd.android.package-archive",
      );

      if (result.type != ResultType.done) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Failed to initiate installation: ${result.message}")),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Error during installation: $e")),
      );
    }
  }
}
