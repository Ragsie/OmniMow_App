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
  // ⚠️ VIGTIGT: TJEK DISSE TO LINJER!
  // Hvis dit repository på GitHub stadig hedder "OpenMow-AI_app", men du har 
  // ændret "repoName" til "NuroMow" her, vil opdateringen FEJLE med en 404-fejl.
  // Repository-navnet på GitHub ændrer sig IKKE automatisk, fordi appen skifter navn!
  // =========================================================================
  static const String repoOwner = "Ragsie";
  static const String repoName = "NuroMow-AI_app"; // Ret til "NuroMow" HVIS og kun HVIS du har omdøbt dit repo på GitHub!

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final String currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      
      if (showNoUpdateDialog) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Tjekker $repoOwner/$repoName på GitHub..."),
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode != 200) {
        debugPrint("GitHub API fejl: ${response.statusCode} - ${response.body}");
        if (context.mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text("API Fejl (${response.statusCode}). Er repo-navnet '$repoName' rigtigt?"),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      final releaseData = jsonDecode(response.body);
      final String tagName = releaseData['tag_name'] ?? '';
      final String bodyText = releaseData['body'] ?? 'Ingen changelog angivet.';
      final String releaseHtmlUrl = releaseData['html_url'] ?? 'https://github.com/$repoOwner/$repoName/releases/latest';

      // 1. Ekstraher build-nummer (virker både for "v1.0.63-63" og "v1.0.63")
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

      debugPrint("Lokal Build: $currentBuildNumber | GitHub Release Build: $latestBuildNumber");
      debugPrint("Lokal Version: $currentVersion | GitHub Release Tag: $tagName");

      // Vis diagnostisk info hvis brugeren klikkede manuelt
      if (showNoUpdateDialog && context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              "Lokal: v$currentVersion ($currentBuildNumber) | GitHub: $tagName ($latestBuildNumber)",
              style: const TextStyle(fontSize: 12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // 2. Lav semantisk versionstjek
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
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text("NuroMow er helt opdateret! Du har den nyeste version."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Fejl ved tjek efter opdatering: $e");
      if (context.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text("Netværksfejl eller uventet fejl: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Robust sammenlignings-algoritme, der tjekker både versions-strenge og build-numre
  static bool _isNewerVersion(String latestTag, String currentVersion, int latestBuild, int currentBuild) {
    // Rens strenge for alt andet end tal og punkter (f.eks. "v1.0.63-63" -> "1.0.63")
    final String cleanLatest = latestTag.split('-').first.replaceAll(RegExp(r'[^0-9.]'), '');
    final String cleanCurrent = currentVersion.replaceAll(RegExp(r'[^0-9.]'), '');

    if (cleanLatest.isEmpty || cleanCurrent.isEmpty) {
      return latestBuild > currentBuild;
    }

    final List<int> latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final List<int> currentParts = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Sørg for at listerne er lige lange ved at fylde op med 0'er (f.eks. "1.1" vs "1.0.63")
    final int maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
    while (latestParts.length < maxLen) latestParts.add(0);
    while (currentParts.length < maxLen) currentParts.add(0);

    // Sammenlign segment for segment (Major, Minor, Patch)
    for (int i = 0; i < maxLen; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    // Hvis de semantiske versionsnumre er fuldstændig identiske, falder vi tilbage på build-nummeret
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
        title: Text("Ny opdatering fundet ($version)"),
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
                  "Bemærk: På iOS åbnes GitHub Releases i browseren, så du kan hente filen til Sideloadly.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Senere"),
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
            child: Text(Platform.isIOS ? "Åbn Release" : "Opdater nu"),
          ),
        ],
      ),
    );
  }

  static Future<void> _downloadAndInstallApk(BuildContext context, String url) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(content: Text("Downloader opdatering...")),
    );

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text("Download fejlede med status: ${response.statusCode}")),
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
          SnackBar(content: Text("Kunne ikke starte installationen: ${result.message}")),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Fejl under installation: $e")),
      );
    }
  }
}
