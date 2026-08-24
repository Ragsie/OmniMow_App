import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
          const Text("Appearance", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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
              }
            ),
          ),
          const SizedBox(height: 24),

          // --- NOTIFICATION OPTIONS ---
          const Text("Notification Options", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.battery_alert, color: Colors.orange),
                  title: const Text("Low Battery"),
                  subtitle: const Text("Notify me when the battery drops below 20%"),
                  value: _notifBattery,
                  onChanged: (val) {
                    setState(() => _notifBattery = val);
                    _savePreference('notif_battery', val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.satellite_alt, color: Colors.redAccent),
                  title: const Text("RTK / GNSS status"),
                  subtitle: const Text("Warn me if the robot loses its fix"),
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
                  subtitle: const Text("When the mower is navigating to the charger"),
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
                  subtitle: const Text("When the mower is connected to power"),
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
                  subtitle: const Text("Critical warning when the mower stops and cannot continue"),
                  value: _notifStuck,
                  onChanged: (val) {
                    setState(() => _notifStuck = val);
                    _savePreference('notif_stuck', val);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}