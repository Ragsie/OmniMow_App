import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/update_service.dart';
import '../services/ros_service.dart';
import '../widgets/about_credits_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifBattery = true;
  bool _notifRtk = true;
  bool _notifDocking = false;
  bool _notifCharging = false;
  bool _notifStuck = true;
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

  Future<void> _loadAppInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
      _buildNumber = info.buildNumber;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifBattery = prefs.getBool('notif_battery') ?? true;
      _notifRtk = prefs.getBool('notif_rtk') ?? true;
      _notifDocking = prefs.getBool('notif_docking') ?? false;
      _notifCharging = prefs.getBool('notif_charging') ?? false;
      _notifStuck = prefs.getBool('notif_stuck') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- THEME SETTINGS ---
          const Text("Udseende", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                return ListTile(
                  leading: const Icon(Icons.palette),
                  title: const Text("App Theme"),
                  trailing: DropdownButton<ThemeMode>(
                    value: mode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text("System (Auto)")),
                      DropdownMenuItem(value: ThemeMode.light, child: Text("Light Theme")),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark Theme")),
                    ],
                    onChanged: (newMode) {
                      if (newMode != null) themeNotifier.value = newMode;
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // --- NOTIFICATION PREFERENCES ---
          const Text("Vælg Notifikationer", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.battery_alert, color: Colors.orange),
                  title: const Text("Low Battery"),
                  subtitle: const Text("Alert when battery drops below 20%"),
                  value: _notifBattery,
                  onChanged: (val) {
                    setState(() => _notifBattery = val);
                    _savePreference('notif_battery', val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.satellite_alt, color: Colors.redAccent),
                  title: const Text("RTK / GNSS Status"),
                  subtitle: const Text("Warning if GPS loses its Fix"),
                  value: _notifRtk,
                  onChanged: (val) {
                    setState(() => _notifRtk = val);
                    _savePreference('notif_rtk', val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.home, color: Colors.blueAccent),
                  title: const Text("Returning Home / Docking"),
                  subtitle: const Text("When the machine is heading to the charger"),
                  value: _notifDocking,
                  onChanged: (val) {
                    setState(() => _notifDocking = val);
                    _savePreference('notif_docking', val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.bolt, color: Colors.amber),
                  title: const Text("Charging Status"),
                  subtitle: const Text("When the machine is receiving power"),
                  value: _notifCharging,
                  onChanged: (val) {
                    setState(() => _notifCharging = val);
                    _savePreference('notif_charging', val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.warning, color: Colors.red),
                  title: const Text("Stuck"),
                  subtitle: const Text("Critical alert if the robot stops and is unable to proceed"),
                  value: _notifStuck,
                  onChanged: (val) {
                    setState(() => _notifStuck = val);
                    _savePreference('notif_stuck', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- ABOUT APP, UPDATES & CREDITS ---
          const Text("Om Appen", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text("NuroMow"),
                  subtitle: Text("Version: $_appVersion${_buildNumber.isNotEmpty ? ' (Build $_buildNumber)' : ''}"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.link),
                  title: const Text("Connected Robot"),
                  subtitle: Text(
                    rosService.isConnected
                        ? "${rosService.currentName} (${rosService.currentIp})"
                        : "No active connection",
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.favorite_border, color: Colors.pinkAccent),
                  title: const Text("Credits & Attributions"),
                  subtitle: const Text("View open-source attributions and support development"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => const AboutCreditsDialog(),
                    );
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: _isCheckingUpdate
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.system_update),
                      label: Text(_isCheckingUpdate ? "Checking..." : "Check for Updates"),
                      onPressed: _isCheckingUpdate
                          ? null
                          : () async {
                              setState(() => _isCheckingUpdate = true);
                              await UpdateService.checkForUpdates(context, showNoUpdateDialog: true);
                              if (mounted) setState(() => _isCheckingUpdate = false);
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}