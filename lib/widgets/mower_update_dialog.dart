import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ros_service.dart';

/// Shows the mower's software version, the notes of a new release, and lets
/// the user install it. Updates live while the mower installs.
Future<void> showMowerUpdateDialog(BuildContext context) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  Future<void> run(Future<String> Function() action) async {
    final message = await action();
    scaffoldMessenger.showSnackBar(SnackBar(content: Text(message)));
  }

  return showDialog(
    context: context,
    builder: (dialogContext) => Consumer<RosService>(
      builder: (_, ros, _) => AlertDialog(
        title: const Text('Mower software'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ros.softwareLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (ros.softwareInstalled.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Installed: ${ros.softwareInstalled}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              if (ros.isSoftwareUpdating) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (ros.softwareMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ros.softwareMessage, style: const TextStyle(fontSize: 12)),
              ],
              if (ros.softwareUpdateAvailable &&
                  ros.softwareNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  "What's new:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(ros.softwareNotes, style: const TextStyle(fontSize: 12)),
              ],
              if (ros.softwareUpdateAvailable && !ros.isSoftwareUpdating) ...[
                const SizedBox(height: 12),
                const Text(
                  'The mower must be stopped or docked. It rebuilds and restarts its '
                  'services, which can take a while; the app reconnects by itself.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (!ros.isSoftwareUpdating && !ros.softwareUpdateAvailable)
            TextButton(
              onPressed: ros.isConnected
                  ? () => run(ros.checkSoftwareUpdate)
                  : null,
              child: const Text('Check now'),
            ),
          if (ros.softwareUpdateAvailable && !ros.isSoftwareUpdating)
            FilledButton(
              onPressed: ros.isConnected
                  ? () => run(ros.installSoftwareUpdate)
                  : null,
              child: const Text('Install update'),
            ),
        ],
      ),
    ),
  );
}
