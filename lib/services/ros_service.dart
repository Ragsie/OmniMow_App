import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  // --- Mower Status & Cutter Telemetry ---
  String _mowerState = "offline";
  double _cutterAmps = 0.0;
  bool _bladeActive = false;

  // --- Operating Statistics & Telemetry ---
  double _totalDistanceKm = 0.0;
  int _operatingMinutes = 0;
  int _chargeCycles = 0;
  String _cpuLoad = "0%";
  String _rtkStatus = "No Fix";
  int _satellites = 0;

  // Getters
  bool get isConnected => _isConnected;
  String get mowerState => _mowerState;
  double get cutterAmps => _cutterAmps;
  bool get bladeActive => _bladeActive;
  double get totalDistanceKm => _totalDistanceKm;
  int get operatingMinutes => _operatingMinutes;
  int get chargeCycles => _chargeCycles;
  String get cpuLoad => _cpuLoad;
  String get rtkStatus => _rtkStatus;
  int get satellites => _satellites;

  void connect(String wsUrl) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      notifyListeners();

      // Subscribe to ROS topics
      _subscribeToTopic('/mower/status', 'std_msgs/String');
      _subscribeToTopic('/mower/metrics', 'std_msgs/String');
      _subscribeToTopic('/rtk/status', 'std_msgs/String');

      _channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isConnected = false;
      notifyListeners();
    }
  }

  void _subscribeToTopic(String topic, String type) {
    if (_channel != null && _isConnected) {
      final subMsg = jsonEncode({
        "op": "subscribe",
        "topic": topic,
        "type": type,
      });
      _channel!.sink.add(subMsg);
    }
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawMessage);
      final String? topic = data['topic'];
      final dynamic msg = data['msg'];

      if (topic == '/mower/status') {
        // Håndterer både standard streng og JSON payload
        if (msg is Map<String, dynamic>) {
          _parseMowerStatus(msg);
        } else if (msg is String) {
          try {
            final parsedJson = jsonDecode(msg);
            if (parsedJson is Map<String, dynamic>) {
              _parseMowerStatus(parsedJson);
            } else {
              _mowerState = msg;
            }
          } catch (_) {
            _mowerState = msg;
          }
        }
        notifyListeners();
      } else if (topic == '/mower/metrics') {
        final Map<String, dynamic> metrics =
            msg is String ? jsonDecode(msg) : msg;
        _totalDistanceKm = (metrics['total_distance_km'] as num?)?.toDouble() ?? _totalDistanceKm;
        _operatingMinutes = metrics['total_operating_minutes'] ?? _operatingMinutes;
        _chargeCycles = metrics['charge_cycles'] ?? _chargeCycles;
        _cpuLoad = metrics['cpu_load']?.toString() ?? _cpuLoad;
        notifyListeners();
      } else if (topic == '/rtk/status') {
        final Map<String, dynamic> rtk = msg is String ? jsonDecode(msg) : msg;
        _rtkStatus = rtk['fix_type'] ?? _rtkStatus;
        _satellites = rtk['satellites'] ?? _satellites;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error parsing ROS message: $e");
    }
  }

  void _parseMowerStatus(Map<String, dynamic> json) {
    _mowerState = json['state']?.toString() ?? _mowerState;
    _cutterAmps = (json['cutter_amps'] as num?)?.toDouble() ?? 0.0;
    _bladeActive = json['blade_active'] ?? false;
  }

  void disconnect() {
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }
}
