import 'package:flutter/material.dart';
import '../services/ros_service.dart';

class NerdMetricsScreen extends StatelessWidget {
  const NerdMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nerd Metrics & Diagnostics")),
      body: ListenableBuilder(
        listenable: rosService,
        builder: (context, _) {
          // Calculates hours and minutes neatly based on total operating time.
          final int hours = rosService.operatingMinutes ~/ 60;
          final int minutes = rosService.operatingMinutes % 60;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- CUTTER MOTOR TELEMETRY ---
              const Text(
                "Cutting System",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.content_cut,
                        color: rosService.bladeActive ? Colors.greenAccent : Colors.grey,
                      ),
                      title: const Text("Cutter Motor"),
                      subtitle: Text(
                        rosService.bladeActive
                            ? (rosService.cutterAmps >= 12.0
                                ? "High Load / Heavy Grass"
                                : "Active / Spinning")
                            : "Idle (Stopped)",
                      ),
                      trailing: Text(
                        "${rosService.cutterAmps.toStringAsFixed(1)} A",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: rosService.cutterAmps >= 14.0
                              ? Colors.redAccent
                              : (rosService.cutterAmps >= 12.0 ? Colors.orangeAccent : null),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (rosService.cutterAmps / 15.0).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white12
                              : Colors.black12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            rosService.cutterAmps >= 14.0
                                ? Colors.redAccent
                                : (rosService.cutterAmps >= 12.0 ? Colors.orangeAccent : Colors.greenAccent),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- BATTERY SYSTEM ---
              const Text(
                "Battery System",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bolt, color: Colors.amber),
                      title: const Text("Battery Voltage"),
                      trailing: Text(
                        "${rosService.batteryVoltage.toStringAsFixed(1)} V",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.electric_meter, color: Colors.blueAccent),
                      title: const Text("Battery Current"),
                      trailing: Text(
                        "${rosService.batteryCurrent.toStringAsFixed(1)} A",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.thermostat, color: Colors.orangeAccent),
                      title: const Text("Battery Temperature"),
                      trailing: Text(
                        "${rosService.batteryTemp.toStringAsFixed(1)} °C",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- OPERATING STATISTICS ---
              const Text(
                "Operating Statistics",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.straighten, color: Colors.blueAccent),
                      title: const Text("Total Distance"),
                      trailing: Text(
                        "${rosService.totalDistanceKm.toStringAsFixed(2)} km",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer, color: Colors.greenAccent),
                      title: const Text("Total Operating Time"),
                      trailing: Text(
                        "$hours hr $minutes min",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.ev_station, color: Colors.amber),
                      title: const Text("Charge Cycles"),
                      trailing: Text(
                        "${rosService.chargeCycles}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- HARDWARE TELEMETRY ---
              const Text(
                "Hardware Telemetry",
                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.memory),
                      title: const Text("Main Controller CPU Load"),
                      subtitle: Text(rosService.cpuLoad),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.satellite_alt),
                      title: const Text("RTK GNSS Status"),
                      subtitle: Text("Fix Type: ${rosService.rtkStatus} | Satellites: ${rosService.satellites}"),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}