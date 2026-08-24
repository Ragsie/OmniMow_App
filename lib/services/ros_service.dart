import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  // --- ROBOT STATE (Live data) ---
  double batteryLevel = 100.0;
  double progress = 0.0;
  String rtkStatus = "Waiting for Fix...";
  String cpuLoad = "Unknown";
  int satellites = 0;
  
  // Navigation data
  List<Offset> pathPoints = [const Offset(0, 0)];
  Offset currentPosition = const Offset(0, 0);
  double robotHeading = 0.0;

  void connect(String url) {
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

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final topic = data['topic'];
    final msg = data['msg'];

    if (topic == '/battery_status') {
      batteryLevel = msg['percentage'] * 100;
    } else if (topic == '/rtk/status') {
      rtkStatus = msg['status_string'];
      satellites = msg['satellites'];
    }
    
    notifyListeners();
  }

  // --- COMMANDS TO THE ROBOT ---
  void sendCommand(String command) {
    if (!isConnected && _simTimer == null) return;
    
    // Use debugPrint instead of print during development
    debugPrint("Command sent to robot: $command");
    
    /*
    // The real implementation over WebSocket:
    final msg = {
      'op': 'publish',
      'topic': '/mower/command',
      'msg': {'data': command}
    };
    _channel?.sink.add(jsonEncode(msg));
    */
  }

  void saveSchedule(List<String> days, TimeOfDay time) {
    final scheduleData = {
      'days': days,
      'hour': time.hour,
      'minute': time.minute,
    };
    
    // Use debugPrint instead of print
    debugPrint("Schedule saved and sent to ROS: $scheduleData");
  }

  // --- SIMULATOR ---
  Timer? _simTimer;
  void startSimulation() {
    isConnected = true;
    rtkStatus = "RTK Fixed";
    satellites = 24;
    cpuLoad = "Core 0: 42% | Core 1: 30%";
    
    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      robotHeading += 0.05; 
      double speed = 2.0;
      currentPosition = Offset(
        currentPosition.dx + (speed * math.cos(robotHeading)),
        currentPosition.dy + (speed * math.sin(robotHeading)),
      );
      
      if (timer.tick % 10 == 0) {
        pathPoints.add(currentPosition);
      }

      batteryLevel = math.max(0, batteryLevel - 0.01);
      progress = math.min(100, progress + 0.05);

      notifyListeners();
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