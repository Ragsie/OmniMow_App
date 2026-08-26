import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  String currentIp = "";
  String currentName = "OpenMow AI";

  // --- ROBOT STATE ---
  String mowerState = "offline";
  double batteryLevel = 100.0;
  double progress = 0.0;
  String rtkStatus = "Waiting for Fix...";
  String cpuLoad = "Unknown";
  int satellites = 0;

  // --- CUTTER TELEMETRY ---
  double cutterAmps = 0.0;
  bool bladeActive = false;

  // --- OPERATING METRICS ---
  double totalDistanceKm = 0.0;
  int operatingMinutes = 0;
  int chargeCycles = 0;

  // --- POSITION / MAP ---
  double currentX = 0.0;
  double currentY = 0.0;
  final List<Offset> pathHistory = [];

  void updatePosition(double x, double y) {
    currentX = x;
    currentY = y;
    pathHistory.add(Offset(x, y));
    notifyListeners();
  }

  void clearPath() {
    pathHistory.clear();
    notifyListeners();
  }

  Future<bool> connect(String name, String ip) async {
    currentName = name;
    currentIp = ip;
    final url = 'ws://$ip:9090';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (data) => _handleIncomingMessage(jsonDecode(data)),
        onError: (_) {
          isConnected = false;
          notifyListeners();
        },
        onDone: () {
          isConnected = false;
          notifyListeners();
        },
      );
      return true;
    } catch (e) {
      isConnected = false;
      notifyListeners();
      return false;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) async {
    final topic = data['topic'];
    final msg = data['msg'];

    if (topic == '/battery_status') {
      batteryLevel = (msg['percentage'] as num? ?? 1.0).toDouble() * 100;
    } else if (topic == '/rtk/status') {
      rtkStatus = msg['status_string'] ?? 'No Fix';
      satellites = msg['satellites'] ?? 0;
    } else if (topic == '/mower/status') {
      mowerState = msg['state'] ?? mowerState;
      cutterAmps = (msg['cutter_amps'] as num?)?.toDouble() ?? 0.0;
      bladeActive = msg['blade_active'] ?? false;
    } else if (topic == '/mower/metrics') {
      totalDistanceKm = (msg['distance_meters'] as num? ?? 0.0).toDouble() / 1000.0;
      operatingMinutes = msg['mowing_minutes'] ?? operatingMinutes;
      chargeCycles = msg['charge_cycles'] ?? chargeCycles;
      cpuLoad = msg['cpu_load']?.toString() ?? cpuLoad;
    }

    notifyListeners();
  }

  void sendCommand(String command) {
    if (!isConnected) return;
    debugPrint("Command sent: $command");
    final msg = {
      'op': 'publish',
      'topic': '/mower/command',
      'msg': {'data': command}
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  void saveSchedule(List<String> days, TimeOfDay time) {
    if (!isConnected) return;
    final scheduleData = {
      'days': days,
      'hour': time.hour,
      'minute': time.minute,
    };
    final msg = {
      'op': 'publish',
      'topic': '/mower/schedule',
      'msg': {'data': jsonEncode(scheduleData)}
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  // Simulator
  Timer? _simTimer;
  double _simHeading = 0.0;

  void startSimulation() {
    isConnected = true;
    rtkStatus = "RTK Fixed";
    satellites = 24;
    cpuLoad = "Core 0: 42% | Core 1: 30%";
    bladeActive = true;
    cutterAmps = 8.5;

    if (currentX == 0 && currentY == 0) {
      currentX = 150;
      currentY = 150;
    }

    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _simHeading += 0.05;
      updatePosition(
        currentX + (2.0 * math.cos(_simHeading)),
        currentY + (2.0 * math.sin(_simHeading)),
      );
      batteryLevel = math.max(0, batteryLevel - 0.005);
      progress = math.min(100, progress + 0.02);
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

// Global instans til hele appen
final rosService = RosService();
