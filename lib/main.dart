import 'package:flutter/material.dart';
import 'widgets/mower_map_painter.dart';
import 'services/ros_service.dart';
import 'services/notification_service.dart';
import 'services/live_feed.dart';
import 'screens/schedule_screen.dart';
import 'screens/connection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/nerd_metrics_screen.dart';

// Global ValueNotifier for light/dark theme
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notificationService.init();
  
  runApp(const RobotApp());
}

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'OpenMow AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: currentMode,
          home: const ConnectionScreen(),
        );
      },
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    //rosService.startSimulation(); // simulation kode
  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(rosService.currentName),
        leading: IconButton(
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Switch robot',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectionScreen()),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          ListenableBuilder(
            listenable: rosService,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: Text(
                    rosService.isConnected ? "ONLINE" : "OFFLINE",
                    style: TextStyle(
                      color: rosService.isConnected ? Colors.greenAccent : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Live Map Preview
            SizedBox(
              height: 380,
              width: double.infinity,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(
                  listenable: rosService,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: MowerMapPainter(
                        path: rosService.pathHistory,
                        currentRobotPos: Offset(rosService.currentX, rosService.currentY),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Battery & Progress
            ListenableBuilder(
              listenable: rosService,
              builder: (context, _) {
                return Row(
                  children: [
                    Expanded(
                      child: StatusCard(
                        title: "Battery",
                        value: "${rosService.batteryLevel.toStringAsFixed(1)}%",
                        icon: Icons.battery_charging_full,
                      ),
                    ),
                    Expanded(
                      child: StatusCard(
                        title: "Progress",
                        value: "${rosService.progress.toStringAsFixed(1)}%",
                        icon: Icons.grass,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // 3. Robot State tekst
            ListenableBuilder(
              listenable: rosService,
              builder: (context, _) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.greenAccent),
                    title: const Text("Current Action", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(
                      rosService.mowerState.toUpperCase(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // 4. Manual Control (Start / Stop / Home)
            const Text("Manual Control", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: "btn_start",
                  backgroundColor: Colors.green,
                  onPressed: () => rosService.sendCommand("start"),
                  child: const Icon(Icons.play_arrow, size: 32, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: "btn_stop",
                  backgroundColor: Colors.red,
                  onPressed: () => rosService.sendCommand("stop"),
                  child: const Icon(Icons.stop, size: 32, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: "btn_home",
                  backgroundColor: Colors.blueAccent,
                  onPressed: () => rosService.sendCommand("home"),
                  child: const Icon(Icons.home, size: 32, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 5. Menu knapper
            const Text("Menu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LiveFeedScreen()),
                ),
                icon: const Icon(Icons.videocam),
                label: const Text("Live Feed", style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                    ),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Schedule"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NerdMetricsScreen()),
                    ),
                    icon: const Icon(Icons.analytics),
                    label: const Text("Metrics"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Helper widget for status cards on the Dashboard
class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const StatusCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.greenAccent),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
