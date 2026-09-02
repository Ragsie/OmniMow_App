import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutCreditsDialog extends StatelessWidget {
  const AboutCreditsDialog({Key? key}) : super(key: key);

  // Helper method to safely launch URLs
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
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
          const Text('Om & Anerkendelser'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'OmniMow',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 2.1.0\nBygget til det fantastiske DIY-robotfællesskab.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const Divider(height: 24),
            const Text(
              'Dette projekt står på skuldrene af giganter. En stor tak til de fantastiske open-source projekter og udviklere bag:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),

            // Main Platforms
            _buildSectionHeader(context, 'Platforme & Fundament'),
            _buildCreditItem(
              title: 'OpenMower',
              subtitle: 'Det banebrydende open-source DIY-plæneklipper projekt.',
              url: 'https://github.com/ClemensElflein/openmower',
            ),
            _buildCreditItem(
              title: 'ROS 2 (Robot Operating System)',
              subtitle: 'Middleware og styringslogik i robottens backend.',
              url: 'https://www.ros.org/',
            ),
            _buildCreditItem(
              title: 'Flutter & Dart',
              subtitle: 'Google UI-toolkit til hurtige, responsive mobilapps.',
              url: 'https://flutter.dev/',
            ),

            // Hardware & Vision
            _buildSectionHeader(context, 'Hardware & Computervision'),
            _buildCreditItem(
              title: 'VESC (Benjamin Vedder)',
              subtitle: 'Open-source motorstyring med præcis telemetri.',
              url: 'https://vesc-project.com/',
            ),
            _buildCreditItem(
              title: 'micro-ROS',
              subtitle: 'ESP32-mikrocontrollerintegration direkte til ROS 2.',
              url: 'https://micro.ros.org/',
            ),
            _buildCreditItem(
              title: 'YOLO (You Only Look Once)',
              subtitle: 'Lynhurtig objektgenkendelse i live-videostrømmen.',
              url: 'https://github.com/ultralytics',
            ),

            // Key Libraries
            _buildSectionHeader(context, 'Centrale Flutter-biblioteker'),
            _buildCreditItem(
              title: 'flutter_webrtc',
              subtitle: 'Ultralav forsinkelse på live-video streaming.',
              url: 'https://pub.dev/packages/flutter_webrtc',
            ),
            _buildCreditItem(
              title: 'open_filex',
              subtitle: 'Sikre in-app APK-opdateringer på moderne Android.',
              url: 'https://pub.dev/packages/open_filex',
            ),
            _buildCreditItem(
              title: 'web_socket_channel',
              subtitle: 'Stabil realtidsforbindelse til FastAPI-backenden på port 8000.',
              url: 'https://pub.dev/packages/web_socket_channel',
            ),
            _buildCreditItem(
              title: 'flutter_local_notifications',
              subtitle: 'Styrer de kritiske push-alarmer på mobilen.',
              url: 'https://pub.dev/packages/flutter_local_notifications',
            ),

            // Distribution Tools
            _buildSectionHeader(context, 'Distribution'),
            _buildCreditItem(
              title: 'Sideloadly',
              subtitle: 'Gør det nemt for iOS-brugere at sideloade og opdatere.',
              url: 'https://sideloadly.io/',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _launchURL('https://buymeacoffee.com/ragsie'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.red[400], size: 16),
              const SizedBox(width: 4),
              const Text('Støt med en donation'),
            ],
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Luk'),
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
