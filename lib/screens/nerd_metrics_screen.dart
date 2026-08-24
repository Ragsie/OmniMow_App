import 'package:flutter/material.dart';
import '../services/ros_service.dart';

class NerdMetricsScreen extends StatelessWidget {
  const NerdMetricsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Diagnostics & Metrics")),
      body: ListenableBuilder(
        listenable: rosService,
        builder: (context, _) {
          // Convert total minutes into a readable hours-and-minutes value.
          int hours = rosService.totalMowingMinutes ~/ 60;
          int minutes = rosService.totalMowingMinutes % 60;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Operating Statistics", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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

              const Text("Hardware Telemetry", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
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