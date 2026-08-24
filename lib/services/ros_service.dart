import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  String currentIp = "";
  String currentName = "Mower Dashboard";

  // --- ROBOT STATE (Live data) ---
  // State received from /mower/status.
  String mowerState = "Standby";
  double batteryLevel = 100.0;
  double progress = 0.0;
  String rtkStatus = "Waiting for Fix...";
  String cpuLoad = "Unknown";
  int satellites = 0;
  
  // --- OPERATING STATISTICS ---
  double totalDistanceKm = 0.0;
  int totalMowingMinutes = 0;
  int chargeCycles = 0;
  
  // --- MAP AND POSITIONING ---
  double currentX = 0.0; 
  double currentY = 0.0; 
  
  // History of every point visited by the mower.
  final List<Offset> pathHistory = [];

  // Called when a new position arrives from ROS, such as /odom or /gps/fix.
  void updatePosition(double x, double y) {
    currentX = x;
    currentY = y;
    pathHistory.add(Offset(x, y));
    notifyListeners();
  }
  
  // Clear the recorded route.
  void clearPath() {
    pathHistory.clear();
    notifyListeners();
  }

  // --- FORBINDELSE ---
  void connect(String name, String ip) {
    currentName = name;   
    currentIp = ip; 
    final url = 'ws://$ip:9090'; 

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      isConnected = true;
      notifyListeners();

      _channel!.stream.listen(
        (data) => _handleIncomingMessage(jsonDecode(data)),
        onError: (_) { isConnected = false; notifyListeners(); },
        onDone: () { isConnected = false; notifyListeners(); },
      );
    } catch (e) {
      isConnected = false;
      notifyListeners();
    }
  }

  // Variables to avoid spam
  bool _hasWarnedBattery = false;
  bool _hasWarnedRtk = false;
  bool _hasWarnedDocking = false;
  bool _hasWarnedCharging = false;
  bool _hasWarnedStuck = false;

  void _handleIncomingMessage(Map<String, dynamic> data) async {
    final topic = data['topic'];
    final msg = data['msg'];
    final prefs = await SharedPreferences.getInstance();

    if (topic == '/battery_status') {
      batteryLevel = msg['percentage'] * 100;
      bool allowBattery = prefs.getBool('notif_battery') ?? true;
      
      if (batteryLevel < 20.0 && !_hasWarnedBattery && allowBattery) {
        notificationService.showWarning(
          id: 1, 
          title: "Low Battery!",
          body: "The mower has only ${batteryLevel.toInt()}% battery remaining."
        );
        _hasWarnedBattery = true;
      } else if (batteryLevel > 25.0) {
        _hasWarnedBattery = false;
      }
      
    } else if (topic == '/rtk/status') {
      rtkStatus = msg['status_string'];
      satellites = msg['satellites'];
      bool allowRtk = prefs.getBool('notif_rtk') ?? true;
      
      if (rtkStatus != "Fix" && !_hasWarnedRtk && allowRtk) {
         notificationService.showWarning(
          id: 2, 
          title: "GNSS Warning",
          body: "RTK fix lost. Current status: $rtkStatus."
        );
        _hasWarnedRtk = true;
      } else if (rtkStatus == "Fix") {
        _hasWarnedRtk = false;
      }
    } else if (topic == '/mower/status') {
      final state = msg['state'] ?? '';
      mowerState = state;

      if (state == 'docking') {
        bool allowDocking = prefs.getBool('notif_docking') ?? false;
        if (!_hasWarnedDocking && allowDocking) {
          notificationService.showWarning(id: 3, title: "Landroid", body: "The mower is returning to the docking station.");
          _hasWarnedDocking = true;
        }
      } else {
        _hasWarnedDocking = false;
      }

      if (state == 'charging') {
        bool allowCharging = prefs.getBool('notif_charging') ?? false;
        if (!_hasWarnedCharging && allowCharging) {
          notificationService.showWarning(id: 4, title: "Charging", body: "The mower is docked and charging.");
          _hasWarnedCharging = true;
        }
      } else {
        _hasWarnedCharging = false;
      }

      if (state == 'stuck') {
        bool allowStuck = prefs.getBool('notif_stuck') ?? true;
        if (!_hasWarnedStuck && allowStuck) {
          notificationService.showWarning(id: 5, title: "CRITICAL WARNING", body: "The mower is stuck and needs assistance!");
          _hasWarnedStuck = true;
        }
      } else {
        _hasWarnedStuck = false;
      }
    } else if (topic == '/mower/metrics') {
      totalDistanceKm = (msg['distance_meters'] ?? 0.0) / 1000.0;
      totalMowingMinutes = msg['mowing_minutes'] ?? 0;
      chargeCycles = msg['charge_cycles'] ?? 0;
      notifyListeners();
    } else if (topic == '/odom' || topic == '/gps/fix') {
      // When real coordinates arrive from ROS 2:
      // double x = msg['x'];
      // double y = msg['y'];
      // updatePosition(x, y);
    }
  }

  // --- COMMANDS FOR THE ROBOT ---
  void sendCommand(String command) {
    if (!isConnected) return; 
    
    debugPrint("Command sent to robot: $command");
    
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
    
    debugPrint("Schedule saved and sent to ROS: $scheduleData");

    final msg = {
      'op': 'publish',
      'topic': '/mower/schedule',
      'msg': {'data': jsonEncode(scheduleData)}
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  // --- SIMULATOR ---
  Timer? _simTimer;
  double _simHeading = 0.0;

  void startSimulation() {
    isConnected = true;
    rtkStatus = "RTK Fixed";
    satellites = 24;
    cpuLoad = "Core 0: 42% | Core 1: 30%";
    
    // Place the simulated mower near the center of the map on first start.
    if (currentX == 0 && currentY == 0) {
      currentX = 150;
      currentY = 150;
    }

    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _simHeading += 0.05; 
      double speed = 2.0;
      
      // Calculate the next simulated position.
      double newX = currentX + (speed * math.cos(_simHeading));
      double newY = currentY + (speed * math.sin(_simHeading));
      
      updatePosition(newX, newY);

      batteryLevel = math.max(0, batteryLevel - 0.01);
      progress = math.min(100, progress + 0.05);
    });
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}

final rosService = RosService();