import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  static const String repoOwner = "Ragsie";
  static const String repoName = "OpenMow-AI_app";

  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Kunne ikke hente versionsinfo fra GitHub")),
          );
        }
        return;
      }

      final releaseData = jsonDecode(response.body);
      final String tagName = releaseData['tag_name'] ?? '';
      final String bodyText = releaseData['body'] ?? 'Ingen changelog angivet.';

      final buildRegex = RegExp(r'-(\d+)$');
      final match = buildRegex.firstMatch(tagName);
      final latestBuildNumber = match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;

      if (latestBuildNumber > currentBuildNumber) {
        final List assets = releaseData['assets'] ?? [];
        final apkAsset = assets.firstWhere(
          (asset) => (asset['name'] as String).endsWith('.apk'),
          orElse: () => null,
        );

        if (apkAsset != null && context.mounted) {
          _showUpdateDialog(context, tagName, bodyText, apkAsset['browser_download_url']);
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

  static void _showUpdateDialog(BuildContext context, String version, String changelog, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Ny opdatering ($version)"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Changelog:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(changelog),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Senere"),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstallApk(context, downloadUrl);
            },
            child: const Text("Opdater nu"),
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

      await OpenFilex.open(file.path);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Fejl under hentning af opdatering: $e")),
      );
    }
  }
}
