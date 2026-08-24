import 'package:flutter/material.dart';
import 'widgets/mower_map_painter.dart';
import 'services/ros_service.dart';
import 'screens/schedule_screen.dart';

void main() => runApp(const RobotApp());

class RobotApp extends StatelessWidget {
  const RobotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROS 2 Mower',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const DashboardScreen(),
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
    // Start the simulation when the app opens (remove this when connecting the real robot!)
    rosService.startSimulation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mower Dashboard"),
        actions: [
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
            }
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Live map preview (made significantly larger)
            SizedBox(
              height: 380, // Height increased here for a larger map
              width: double.infinity,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: ListenableBuilder(
                  listenable: rosService,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: MowerMapPainter(
                        pathPoints: rosService.pathPoints,
                        currentPosition: rosService.currentPosition,
                        robotHeading: rosService.robotHeading,
                      ),
                    );
                  }
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 2. Live progress and battery
            ListenableBuilder(
              listenable: rosService,
              builder: (context, _) {
                return Row(
                  children: [
                    Expanded(child: StatusCard(
                      title: "Battery", 
                      value: "${rosService.batteryLevel.toStringAsFixed(1)}%", 
                      icon: Icons.battery_charging_full,
                    )),
                    Expanded(child: StatusCard(
                      title: "Progress", 
                      value: "${rosService.progress.toStringAsFixed(1)}%", 
                      icon: Icons.grass,
                    )),
                  ],
                );
              }
            ),
            const SizedBox(height: 24),
            
            // --- MANUAL CONTROL (START / STOP / HOME) ---
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

            // --- MENU (LIVE FEED, SCHEDULE, METRICS) ---
            const Text("Menu", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            
            // Live Feed gets its own large primary button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveFeedScreen())),
                icon: const Icon(Icons.videocam),
                label: const Text("Live Feed", style: TextStyle(fontSize: 16)),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(height: 10),
            
            // Schedule and Metrics sit side by side below Live Feed.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Schedule"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NerdMetricsScreen())),
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

// --- NERD METRICS SCREEN (Live data) ---
class NerdMetricsScreen extends StatelessWidget {
  const NerdMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Diagnostics")),
      body: ListenableBuilder(
        listenable: rosService,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Hardware Telemetry", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              ListTile(
                leading: const Icon(Icons.memory),
                title: const Text("Main Controller CPU Load"),
                subtitle: Text(rosService.cpuLoad),
              ),
              ListTile(
                leading: const Icon(Icons.satellite_alt),
                title: const Text("RTK GNSS Status"),
                subtitle: Text("Fix Type: ${rosService.rtkStatus} | Satellites: ${rosService.satellites}"),
              ),
              const Divider(),
              // More metrics can easily be added here
            ],
          );
        }
      ),
    );
  }
}

// --- LIVE FEED SCREEN (Placeholder) ---
class LiveFeedScreen extends StatelessWidget {
  const LiveFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Camera Feed")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text("Waiting for video stream..."),
            const SizedBox(height: 8),
            Text(
              "Here we will implement flutter_webrtc\nto stream the YOLO camera feed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widget for status fields on the dashboard
class StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const StatusCard({super.key, required this.title, required this.value, required this.icon});

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