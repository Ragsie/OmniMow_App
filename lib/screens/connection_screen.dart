import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ros_service.dart';
import '../services/update_service.dart';
import '../main.dart';

class RobotDevice {
  final String name;
  final String ip;

  RobotDevice({required this.name, required this.ip});

  Map<String, dynamic> toJson() => {'name': name, 'ip': ip};
  factory RobotDevice.fromJson(Map<String, dynamic> json) =>
      RobotDevice(name: json['name'], ip: json['ip']);
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  List<RobotDevice> _savedRobots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRobots();

    // Checks for in-app updates on GitHub the moment the app starts!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  Future<void> _loadRobots() async {
    final prefs = await SharedPreferences.getInstance();
    final robotListStrings = prefs.getStringList('robot_fleet') ?? [];

    setState(() {
      _savedRobots = robotListStrings
          .map((e) => RobotDevice.fromJson(jsonDecode(e)))
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _saveFleet() async {
    final prefs = await SharedPreferences.getInstance();
    final robotListStrings = _savedRobots.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('robot_fleet', robotListStrings);
  }

  Future<void> _addOrUpdateRobot(String name, String ip, {int? editIndex}) async {
    setState(() {
      if (editIndex != null) {
        _savedRobots[editIndex] = RobotDevice(name: name, ip: ip);
      } else {
        _savedRobots.add(RobotDevice(name: name, ip: ip));
      }
    });
    await _saveFleet();
  }

  Future<void> _deleteRobot(int index) async {
    setState(() {
      _savedRobots.removeAt(index);
    });
    await _saveFleet();
  }

  void _connectToRobot(String name, String ip) async {
    // Saves the selected IP so WebRTC can access it later
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('robot_ip', ip);

    rosService.connect(name, ip);

    if (!mounted) return;

    // Clears the stack and forces a fresh Dashboard load
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (Route<dynamic> route) => false,
    );
  }

  void _showRobotDialog({RobotDevice? robotToEdit, int? editIndex}) {
    final nameController = TextEditingController(text: robotToEdit?.name ?? '');
    final ipController = TextEditingController(text: robotToEdit?.ip ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(robotToEdit == null ? "Add New Robot" : "Edit Robot"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Name (e.g. 'Worx Landroid')",
                  prefixIcon: Icon(Icons.smart_toy),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: const InputDecoration(
                  labelText: "IP Address (e.g. 192.168.1.50)",
                  prefixIcon: Icon(Icons.wifi),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && ipController.text.isNotEmpty) {
                  _addOrUpdateRobot(
                    nameController.text.trim(),
                    ipController.text.trim(),
                    editIndex: editIndex,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Select Robot')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRobotDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Add"),
      ),
      body: _savedRobots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.precision_manufacturing, size: 80, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  const Text(
                    "No robots found.\nPress 'Add' to create one.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _savedRobots.length,
              itemBuilder: (context, index) {
                final robot = _savedRobots[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.grass, color: Colors.white),
                    ),
                    title: Text(robot.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    subtitle: Text("IP: ${robot.ip}"),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'connect') {
                          _connectToRobot(robot.name, robot.ip);
                        } else if (value == 'edit') {
                          _showRobotDialog(robotToEdit: robot, editIndex: index);
                        } else if (value == 'delete') {
                          _deleteRobot(index);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'connect',
                          child: Row(
                            children: [
                              Icon(Icons.link, color: Colors.green),
                              SizedBox(width: 8),
                              Text("Connect"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text("Edit"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text("Delete"),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _connectToRobot(robot.name, robot.ip),
                  ),
                );
              },
            ),
    );
  }
}