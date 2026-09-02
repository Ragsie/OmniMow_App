import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCreditsDialog extends StatelessWidget {
  const AboutCreditsDialog({Key? key}) : super(key: key);

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Text('About & Credits'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'NuroMow',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 2.1.0 (Alpha)\nBuilt for the amazing DIY mower community.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            const Text(
              'This project stands on the shoulders of giants. A big thank you to the amazing open-source projects and developers behind it:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Platforms & Foundations
            _buildSectionHeader(context, 'Platforms & Foundations'),
            _buildCreditItem(
              title: 'OpenMower',
              subtitle: 'The amazing open-source Landroid DIY control project.',
              url: 'https://github.com/ClemensElflein/openmower',
            ),
            _buildCreditItem(
              title: 'ROS 2 (Robot Operating System)',
              subtitle: 'The foundation and control logic of the robot backend.',
              url: 'https://www.ros.org/',
            ),
            _buildCreditItem(
              title: 'Flutter & Dart',
              subtitle: 'Google’s amazing framework for beautiful mobile user interfaces.',
              url: 'https://flutter.dev/',
            ),

            // Hardware & Vision
            _buildSectionHeader(context, 'Hardware & Computer Vision'),
            _buildCreditItem(
              title: 'VESC (Benjamin Vedder)',
              subtitle: 'Professional and widely used motor control and telemetry technology.',
              url: 'https://vesc-project.com/',
            ),
            _buildCreditItem(
              title: 'micro-ROS',
              subtitle: 'Fast microcontroller integration for devices such as ESP32.',
              url: 'https://micro.ros.org/',
            ),
            _buildCreditItem(
              title: 'YOLO (You Only Look Once)',
              subtitle: 'The computer vision model behind the mower’s lawn-edge detection.',
              url: 'https://github.com/ultralytics',
            ),

            // Key Flutter libraries
            _buildSectionHeader(context, 'Key Flutter Libraries'),
            _buildCreditItem(
              title: 'flutter_webrtc',
              subtitle: 'Very low latency for the mower’s live YOLO video stream.',
              url: 'https://pub.dev/packages/flutter_webrtc',
            ),
            _buildCreditItem(
              title: 'open_filex',
              subtitle: 'Makes it possible to safely install APK updates in-app.',
              url: 'https://pub.dev/packages/open_filex',
            ),
            _buildCreditItem(
              title: 'web_socket_channel',
              subtitle: 'Stable WebSocket connection to the FastAPI backend on port 8000.',
              url: 'https://pub.dev/packages/web_socket_channel',
            ),
            _buildCreditItem(
              title: 'flutter_local_notifications',
              subtitle: 'Triggers local push notifications when action is required.',
              url: 'https://pub.dev/packages/flutter_local_notifications',
            ),

            // Sideloadly
            _buildSectionHeader(context, 'Distribution'),
            _buildCreditItem(
              title: 'Sideloadly',
              subtitle: 'Makes it easy for our iOS users to run the app without the App Store.',
              url: 'https://sideloadly.io/',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _launchURL('INSERT_YOUR_DONATION_LINK_HERE'), // Add your donation link here!
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.red[400], size: 16),
              const SizedBox(width: 4),
              const Text('Support with a donation'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCreditItem({
    required String title,
    required String subtitle,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => _launchURL(url),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}