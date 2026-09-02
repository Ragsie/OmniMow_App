import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  // TODO: REMEMBER TO CHANGE THESE IF YOUR GITHUB REPOSITORY HAS CHANGED NAME!
  static const String repoOwner = "Ragsie";
  static const String repoName = "NuroMow-AI_app"; // e.g. Change to "NuroMow" if your repo is renamed

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode != 200) {
        debugPrint("GitHub API error: ${response.statusCode}");
        if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Could not fetch the release. Is your repository name correct? (Status: ${response.statusCode})")),
          );
        }
        return;
      }

      final releaseData = jsonDecode(response.body);
      final String tagName = releaseData['tag_name'] ?? '';
      final String bodyText = releaseData['body'] ?? 'No changelog provided.';
      final String releaseHtmlUrl = releaseData['html_url'] ?? 'https://github.com/$repoOwner/$repoName/releases/latest';

      // 1. Extract build number (works for both "v1.0.63-63" and "v1.0.63")
      int latestBuildNumber = 0;
      final dashMatch = RegExp(r'-(\d+)$').firstMatch(tagName);
      if (dashMatch != null) {
        latestBuildNumber = int.tryParse(dashMatch.group(1)!) ?? 0;
      } else {
        final dotMatch = RegExp(r'\.(\d+)$').firstMatch(tagName);
        if (dotMatch != null) {
          latestBuildNumber = int.tryParse(dotMatch.group(1)!) ?? 0;
        }
      }

      debugPrint("Local Build: $currentBuildNumber | GitHub Release Build: $latestBuildNumber");
      debugPrint("Local Version: $currentVersion | GitHub Release Tag: $tagName");

      // 2. Perform a fully robust semantic version check
      if (_isNewerVersion(tagName, currentVersion, latestBuildNumber, currentBuildNumber)) {
        final List assets = releaseData['assets'] ?? [];
        final apkAsset = assets.firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        final String? apkDownloadUrl = apkAsset != null ? apkAsset['browser_download_url'] : null;

        if (context.mounted) {
          _showUpdateDialog(
            context: context,
            version: tagName,
            changelog: bodyText,
            apkDownloadUrl: apkDownloadUrl,
            releaseHtmlUrl: releaseHtmlUrl,
          );
        }
      } else if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You already have the latest version installed!")),
        );
      }
    } catch (e) {
      debugPrint("Error while checking for updates: $e");
      if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error while checking: $e")),
        );
      }
    }
  }

  // Robust comparison algorithm checking both version strings and build numbers
  static bool _isNewerVersion(String latestTag, String currentVersion, int latestBuild, int currentBuild) {
    // Clean strings of anything except digits and dots
    final String cleanLatest = latestTag.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final String cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleanLatest.isEmpty || cleanCurrent.isEmpty) {
      return latestBuild > currentBuild;
    }

    final List<int> latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final List<int> currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure lists are of equal length by filling up with 0s
    final int maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    while (latestParts.length < maxLen) latestParts.add(0);
    while (currentParts.length < maxLen) currentParts.add(0);

    // Compare segment by segment (Major, Minor, Patch)
    for (int i = 0; i < maxLen; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    // If the semantic version numbers are identical, fall back to build number
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
        title: Text("New update found ($version)"),
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
                  "Note: On iOS, GitHub Releases will open in the browser so you can download the file for Sideloadly.",
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
          SnackBar(content: Text("Download failed with status: ${response.statusCode}")),
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
          SnackBar(content: Text("Could not start installation: ${result.message}")),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Installation error: $e")),
      );
    }
  }
}
