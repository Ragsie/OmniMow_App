import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String repoOwner = "Ragsie";
  static const String repoName = "OpenMow-AI_app";

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final int currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(url, headers: {'Accept': 'application/vnd.github.v3+json'});

      if (response.statusCode != 200) {
        debugPrint("GitHub API fejl: ${response.statusCode}");
        if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Kunne ikke hente release (Status: ${response.statusCode})")),
          );
        }
        return;
      }

      final releaseData = jsonDecode(response.body);
      final String tagName = releaseData['tag_name'] ?? '';
      final String bodyText = releaseData['body'] ?? 'Ingen changelog angivet.';
      final String releaseHtmlUrl = releaseData['html_url'] ?? 'https://github.com/$repoOwner/$repoName/releases/latest';

      // Trækker build-nummeret ud (virker både for "v1.0.42-42" og "v1.0.42")
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

      if (latestBuildNumber > currentBuildNumber) {
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
          const SnackBar(content: Text("Du har allerede den nyeste version installeret!")),
        );
      }
    } catch (e) {
      debugPrint("Fejl ved tjek efter opdatering: $e");
      if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Fejl ved tjek: $e")),
        );
      }
    }
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
                // Åbn GitHub Release-siden på iOS
                final uri = Uri.parse(releaseHtmlUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              } else if (Platform.isAndroid && apkDownloadUrl != null) {
                // Hent og installer direkte på Android
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
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/update.apk');
      await file.writeAsBytes(response.bodyBytes);

      // Starter Android pakkeinstallationen
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