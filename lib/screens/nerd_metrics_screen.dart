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
          // Udregn timer og minutter pænt (f.eks. 125 min = 2 timer og 5 min)
          int hours = rosService.totalMowingMinutes ~/ 60;
          int minutes = rosService.totalMowingMinutes % 60;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text("Driftsstatistik", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.straighten, color: Colors.blueAccent),
                      title: const Text("Samlet kørt distance"),
                      trailing: Text(
                        "${rosService.totalDistanceKm.toStringAsFixed(2)} km",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.timer, color: Colors.greenAccent),
                      title: const Text("Samlet driftstid"),
                      trailing: Text(
                        "$hours timer $minutes min",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.ev_station, color: Colors.amber),
                      title: const Text("Ladecyklusser"),
                      trailing: Text(
                        "${rosService.chargeCycles} stk",
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