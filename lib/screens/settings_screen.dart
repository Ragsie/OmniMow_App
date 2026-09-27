import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/ros_service.dart';
import '../services/update_service.dart';
import '../widgets/about_credits_dialog.dart';
import '../main.dart'; // To use themeNotifier
import '../widgets/glass_card.dart'; // Direct GlassCard import
import 'connection_screen.dart';

/// Provides connection, theme, notification, rain-delay, and update settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedThemeIndex = 0; // 0=System, 1=Light, 2=Dark
  bool _notifBattery = true;
  bool _notifRtk = true;
  bool _notifDocking = false;
  bool _notifCharging = false;
  bool _notifStuck = true;
  bool _notifRain = true;
  bool _isLoading = true;
  bool _isCheckingUpdate = false;

  String _appVersion = "Unknown";
  String _buildNumber = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppInfo();
  }

  /// Loads the installed app version and build number for the about section.
  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  /// Restores all user-configurable settings from local preferences.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifBattery = prefs.getBool('notif_battery') ?? true;
      _notifRtk = prefs.getBool('notif_rtk') ?? true;
      _notifDocking = prefs.getBool('notif_docking') ?? false;
      _notifCharging = prefs.getBool('notif_charging') ?? false;
      _notifStuck = prefs.getBool('notif_stuck') ?? true;
      _notifRain = prefs.getBool('notif_rain') ?? true;
      _selectedThemeIndex = prefs.getInt('theme_mode') ?? 0;
      _isLoading = false;
    });
  }

  /// Persists one boolean notification preference.
  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Persists the selected theme and updates the app-wide theme notifier.
  Future<void> _saveThemePreference(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', index);
    themeNotifier.value = ThemeMode.values[index];
    setState(() {
      _selectedThemeIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ros = Provider.of<RosService>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section 1: Connection & Fleet
          const Text(
            'FLEET CONNECTION',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.router, color: theme.colorScheme.primary),
              title: const Text('Manage Mowers'),
              subtitle: Text(
                ros.isConnected
                    ? 'Connected to ${ros.currentIp}'
                    : 'No connected devices',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConnectionScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Visual Themes
          const Text(
            'THEME SETTINGS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                RadioListTile<int>(
                  title: const Text('System Default'),
                  value: 0,
                  groupValue: _selectedThemeIndex,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => _saveThemePreference(val!),
                ),
                RadioListTile<int>(
                  title: const Text('Light Mode'),
                  value: 1,
                  groupValue: _selectedThemeIndex,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => _saveThemePreference(val!),
                ),
                RadioListTile<int>(
                  title: const Text('Dark Mode'),
                  value: 2,
                  groupValue: _selectedThemeIndex,
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) => _saveThemePreference(val!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3: Granular Push Notifications Control
          const Text(
            'PUSH NOTIFICATIONS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Low Battery Alerts',
                  subtitle: 'Notify me when mower battery drops below 20%',
                  value: _notifBattery,
                  onChanged: (val) {
                    setState(() => _notifBattery = val);
                    _savePreference('notif_battery', val);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSwitchTile(
                  title: 'RTK Connection Alerts',
                  subtitle: 'Notify me immediately when RTK GPS is lost',
                  value: _notifRtk,
                  onChanged: (val) {
                    setState(() => _notifRtk = val);
                    _savePreference('notif_rtk', val);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSwitchTile(
                  title: 'Docking Updates',
                  subtitle: 'Notify me when mower successfully returns to dock',
                  value: _notifDocking,
                  onChanged: (val) {
                    setState(() => _notifDocking = val);
                    _savePreference('notif_docking', val);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSwitchTile(
                  title: 'Charging Status',
                  subtitle: 'Notify me when charging cycle starts',
                  value: _notifCharging,
                  onChanged: (val) {
                    setState(() => _notifCharging = val);
                    _savePreference('notif_charging', val);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSwitchTile(
                  title: 'Mower Stuck Alerts',
                  subtitle: 'Notify me if wheels slip or mower stalls',
                  value: _notifStuck,
                  onChanged: (val) {
                    setState(() => _notifStuck = val);
                    _savePreference('notif_stuck', val);
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSwitchTile(
                  title: 'Rain Alerts',
                  subtitle: 'Notify me when rain sensor is triggered',
                  value: _notifRain,
                  onChanged: (val) {
                    setState(() => _notifRain = val);
                    _savePreference('notif_rain', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 3.5: Rain Delay Settings
          const Text(
            'RAIN SENSOR SETTINGS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rain Delay Timer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      ros.rainDelayMinutes == 0
                          ? 'Disabled'
                          : '${ros.rainDelayMinutes} min',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Wait time after rain stops before resuming operation.',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Slider(
                  value: ros.rainDelayMinutes.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 24, // 5 min increments
                  label: '${ros.rainDelayMinutes} min',
                  activeColor: theme.colorScheme.primary,
                  onChanged: (val) {
                    ros.updateRainDelayConfig(val.toInt());
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 4: System Updates & Credits
          const Text(
            'UPDATES & ABOUT',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: _isCheckingUpdate
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update),
                  title: const Text('Check for App Updates'),
                  subtitle: const Text(
                    'Checks GitHub for rolling binary releases',
                  ),
                  onTap: _isCheckingUpdate
                      ? null
                      : () async {
                          setState(() => _isCheckingUpdate = true);
                          await UpdateService.checkForUpdates(
                            context,
                            showNoUpdateDialog: true,
                          );
                          if (mounted)
                            setState(() => _isCheckingUpdate = false);
                        },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.volunteer_activism_outlined),
                  title: const Text('Om & Anerkendelser'),
                  subtitle: const Text('OpenMow and ROS developers credits'),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) =>
                          const AboutCreditsDialog(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// Builds a reusable notification preference row.
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      onChanged: onChanged,
    );
  }
}
