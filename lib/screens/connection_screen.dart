import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ros_service.dart';
import '../services/update_service.dart';
import '../main.dart'; // To use themeNotifier
import '../widgets/glass_card.dart'; // Direct GlassCard import

/// Manages saved mowers and discovers reachable mower backends on the LAN.
class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final List<Map<String, String>> _mowers = [];
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();

  // Onboarding & Auto-Discovery States
  bool _isLoading = true;
  bool _isOnboarding = false;
  bool _isScanning = false;
  double _scanProgress = 0.0;
  String _scanStatus = "";
  String _checkingIp = "";
  String? _discoveredIp;
  bool _showManualFallback = false;

  @override
  void initState() {
    super.initState();
    _loadMowers();
  }

  /// Restores saved mower entries and starts onboarding when none exist.
  Future<void> _loadMowers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> mowerStrings = prefs.getStringList('mower_list') ?? [];

    setState(() {
      _mowers.clear();
      for (var str in mowerStrings) {
        final parts = str.split('|');
        if (parts.length == 2) {
          _mowers.add({'name': parts[0], 'ip': parts[1]});
        }
      }
      _isLoading = false;

      // FIRST TIME LAUNCH: Trigger onboarding and auto-discovery scanner!
      if (_mowers.isEmpty) {
        _isOnboarding = true;
        _startAutoDiscovery();
      } else {
        // Only trigger update check if we already have configured mowers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          UpdateService.checkForUpdates(context);
        });
      }
    });
  }

  /// Persists the configured mower list as compact name/IP pairs.
  Future<void> _saveMowers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> mowerStrings = _mowers
        .map((m) => "${m['name']}|${m['ip']}")
        .toList();
    await prefs.setStringList('mower_list', mowerStrings);
  }

  // --- AUTO-DISCOVERY PORT SCANNER ---
  /// Finds private IPv4 subnets available on the current device.
  Future<List<String>> _getLocalSubnets() async {
    final List<String> subnets = [];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              subnets.add('${parts[0]}.${parts[1]}.${parts[2]}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error detecting subnets: $e");
    }
    // Standard fallbacks if detection fails
    if (subnets.isEmpty) {
      subnets.add('192.168.1');
      subnets.add('192.168.0');
    }
    return subnets.toSet().toList(); // Deduplicate
  }

  /// Scans candidate hosts in bounded concurrent batches with a short timeout.
  Future<void> _startAutoDiscovery() async {
    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _scanProgress = 0.0;
      _discoveredIp = null;
      _showManualFallback = false;
      _scanStatus = "Identifying network interfaces...";
      _checkingIp = "";
    });

    try {
      final subnets = await _getLocalSubnets();

      // Collect target IP addresses
      final List<String> targetIps = [];
      for (var subnet in subnets) {
        for (int i = 1; i <= 254; i++) {
          targetIps.add("$subnet.$i");
        }
      }

      int checkedCount = 0;
      final int totalTargets = targetIps.length;
      bool found = false;

      // We run the scans concurrently in small batches to protect file descriptors
      const int batchSize = 35;

      // Strict 5-second total timeout
      final Future<void> scanTask = Future.sync(() async {
        for (int i = 0; i < totalTargets; i += batchSize) {
          if (found || !mounted || !_isScanning) break;

          final batch = targetIps.sublist(
            i,
            math.min(i + batchSize, totalTargets),
          );
          final batchFutures = batch.map((ip) async {
            if (found) return;

            if (mounted) {
              // Throttled setState for UI update to prevent stutter
              if (checkedCount % 8 == 0 || checkedCount == totalTargets) {
                setState(() {
                  _checkingIp = ip;
                  _scanProgress = checkedCount / totalTargets;
                });
              } else {
                _checkingIp = ip;
              }
            }

            final isAlive = await _checkIpPort(ip, 8000);
            checkedCount++;

            if (isAlive && !found) {
              found = true;
              _discoveredIp = ip;
            }
          }).toList();

          await Future.wait(batchFutures);
        }
      });

      // Execute scan with strict 5-second timeout
      await scanTask.timeout(const Duration(seconds: 5));

      if (found && _discoveredIp != null) {
        _handleRobotDiscovered(_discoveredIp!);
      } else {
        _handleNoRobotFound();
      }
    } catch (_) {
      _handleNoRobotFound();
    }
  }

  /// Checks whether the mower's backend port accepts a TCP connection.
  Future<bool> _checkIpPort(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip,
        port,
        timeout: const Duration(milliseconds: 400),
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Updates the onboarding UI after a mower responds to the scan.
  void _handleRobotDiscovered(String ip) {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _discoveredIp = ip;
      _showManualFallback = false;
      _nameController.text = "My OmniMow";
    });
  }

  /// Shows the manual connection form when discovery finds no mower.
  void _handleNoRobotFound() {
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _discoveredIp = null;
      _showManualFallback = true;
      _nameController.clear();
      _ipController.clear();
    });
  }

  /// Opens the dialog used to add a mower by name and IP address.
  void _addMower() {
    _nameController.clear();
    _ipController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Add Robot Mower'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Mower Name',
                  hintText: 'e.g., Front Yard',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address',
                  hintText: 'e.g., 192.168.1.100',
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.isNotEmpty &&
                    _ipController.text.isNotEmpty) {
                  setState(() {
                    _mowers.add({
                      'name': _nameController.text.trim(),
                      'ip': _ipController.text.trim(),
                    });
                  });
                  _saveMowers();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Removes a saved mower and persists the updated list.
  void _deleteMower(int index) {
    setState(() {
      _mowers.removeAt(index);
    });
    _saveMowers();
  }

  /// Connects to the selected mower and replaces the current route with the dashboard.
  void _connectAndNavigate(String name, String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('robot_ip', ip);

    rosService.connect(name, ip);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ros = Provider.of<RosService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- ONBOARDING / AUTO-DISCOVERY VIEW STATE ---
    if (_isOnboarding) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0C0C0E), const Color(0xFF16161C)]
                  : [const Color(0xFFF5F6FA), const Color(0xFFE2E4EC)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Welcome to OmniMow",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Let's set up and connect your first lawn mower.",
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),

                  // GLASS CARD CARD CONTAINER
                  SizedBox(
                    width: double.infinity,
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isScanning
                            ? Column(
                                key: const ValueKey('scanning_view'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 16),
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        height: 80,
                                        child: CircularProgressIndicator(
                                          value: _scanProgress,
                                          strokeWidth: 6,
                                          backgroundColor: theme
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.12),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                theme.colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.radar,
                                        size: 36,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _scanStatus,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Checking address: $_checkingIp",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  TextButton(
                                    onPressed: _handleNoRobotFound,
                                    child: const Text("Skip to Manual Setup"),
                                  ),
                                ],
                              )
                            : _discoveredIp != null
                            ? Column(
                                key: const ValueKey('discovered_view'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.check_circle,
                                      size: 64,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: Text(
                                      "OmniMow Discovered!",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  Center(
                                    child: Text(
                                      "Robot found at IP: $_discoveredIp",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    "NAME YOUR ROBOT",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: "Mower Name",
                                      hintText: "e.g., Grass Slayer",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: () {
                                        if (_nameController.text.isNotEmpty) {
                                          final newMower = {
                                            'name': _nameController.text.trim(),
                                            'ip': _discoveredIp!,
                                          };
                                          setState(() {
                                            _mowers.add(newMower);
                                            _isOnboarding = false;
                                          });
                                          _saveMowers();
                                          _connectAndNavigate(
                                            newMower['name']!,
                                            newMower['ip']!,
                                          );
                                        }
                                      },
                                      child: const Text("Save & Connect"),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: TextButton(
                                      onPressed: _startAutoDiscovery,
                                      child: const Text("Scan Again"),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                key: const ValueKey('manual_view'),
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.wifi_off_rounded,
                                        color: Colors.amber[700],
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          "No Robot Found Automatically",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "We checked your network but couldn't locate an OmniMow robot. Please enter its IP address manually to connect.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  const Text(
                                    "MOWER DETAILS",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: "Name (e.g. My Lawnmower)",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _ipController,
                                    decoration: const InputDecoration(
                                      labelText:
                                          "IP Address (e.g. 192.168.1.150)",
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.text,
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: () {
                                        if (_nameController.text.isNotEmpty &&
                                            _ipController.text.isNotEmpty) {
                                          final newMower = {
                                            'name': _nameController.text.trim(),
                                            'ip': _ipController.text.trim(),
                                          };
                                          setState(() {
                                            _mowers.add(newMower);
                                            _isOnboarding = false;
                                          });
                                          _saveMowers();
                                          _connectAndNavigate(
                                            newMower['name']!,
                                            newMower['ip']!,
                                          );
                                        }
                                      },
                                      child: const Text("Save & Connect"),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: TextButton.icon(
                                      onPressed: _startAutoDiscovery,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text(
                                        "Try Auto-Discovery Again",
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // --- NORMAL FLEET CONNECTION MANAGER SCREEN ---
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Connection Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'Scan for Robots',
            onPressed: () {
              setState(() {
                _isOnboarding = true;
              });
              _startAutoDiscovery();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0C0C0E), const Color(0xFF16161C)]
                : [const Color(0xFFF5F6FA), const Color(0xFFE2E4EC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Summary Cards
              const Text(
                'ACTIVE ROBOT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),

              // Active mower glass card
              GlassCard(
                padding: const EdgeInsets.all(18),
                borderRadius: 16,
                customColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.airport_shuttle,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ros.isConnected
                                ? ros.currentName
                                : "No Active Mower Connected",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ros.isConnected
                                ? "WebSocket: ws://${ros.currentIp}:8000/ws"
                                : "Disconnected",
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ros.isConnected)
                      const CircleAvatar(
                        radius: 6,
                        backgroundColor: Colors.greenAccent,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AVAILABLE FLEET DEVICES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isOnboarding = true;
                          });
                          _startAutoDiscovery();
                        },
                        icon: const Icon(Icons.radar, size: 18),
                        label: const Text('Scan'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: _addMower,
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView.builder(
                  itemCount: _mowers.length,
                  itemBuilder: (context, index) {
                    final mower = _mowers[index];
                    final isCurrent =
                        ros.isConnected && ros.currentIp == mower['ip'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        borderRadius: 16,
                        customColor: isCurrent
                            ? theme.colorScheme.primary.withOpacity(0.06)
                            : null,
                        child: Row(
                          children: [
                            Icon(
                              Icons.precision_manufacturing_outlined,
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withOpacity(
                                      0.5,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mower['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    mower['ip'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Connect/Disconnect controls
                            if (isCurrent)
                              IconButton(
                                icon: const Icon(
                                  Icons.portable_wifi_off,
                                  color: Colors.redAccent,
                                ),
                                tooltip: 'Disconnect',
                                onPressed: () {
                                  ros.disconnect();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Disconnected from mower.'),
                                    ),
                                  );
                                },
                              )
                            else
                              IconButton(
                                icon: Icon(
                                  Icons.wifi,
                                  color: theme.colorScheme.primary,
                                ),
                                tooltip: 'Connect',
                                onPressed: () {
                                  _connectAndNavigate(
                                    mower['name']!,
                                    mower['ip']!,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Connecting to ${mower['name']}...',
                                      ),
                                    ),
                                  );
                                },
                              ),

                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteMower(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
