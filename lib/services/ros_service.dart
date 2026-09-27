import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Coordinates the mower WebSocket, REST commands, telemetry, and app state.
class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool isConnected = false;

  String currentIp = "";
  String currentName = "OmniMow Dashboard";

  // --- ROBOT STATE (Live data) ---
  String mowerState = "STOP";
  double batteryLevel = 100.0;
  double progress = 0.0;
  String rtkStatus = "Waiting for Fix...";
  String cpuLoad = "Unknown";
  int satellites = 0;

  // --- NEW TELEMETRY INTEGRATIONS (WIFI & RAIN) ---
  int wifiSignalPct = 0;
  bool rainDetected = false;
  bool _hasWarnedRain = false;

  // --- RAIN DELAY CONFIGURATION & STATE ---
  int rainDelayMinutes = 15;
  DateTime? rainStoppedAt;
  bool _hasWarnedRainDelay = false;

  /// Loads persisted rain-delay settings and the last rain-stop timestamp.
  Future<void> initSettings() async {
    final prefs = await SharedPreferences.getInstance();
    rainDelayMinutes = prefs.getInt('rain_delay_minutes') ?? 15;
    final stoppedStr = prefs.getString('rain_stopped_at');
    if (stoppedStr != null) {
      rainStoppedAt = DateTime.tryParse(stoppedStr);
    }
    notifyListeners();
  }

  /// Stores the rain-delay duration and forwards it to the connected mower.
  Future<void> updateRainDelayConfig(int minutes) async {
    rainDelayMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rain_delay_minutes', minutes);
    notifyListeners();

    if (currentIp.isEmpty) return;
    final url = Uri.parse("http://$currentIp:8000/api/schedule/rain_delay");
    final payload = {"duration_seconds": minutes * 60};
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        debugPrint(
          "Rain delay updated successfully on the robot via REST API: ${response.body}",
        );
      } else {
        debugPrint(
          "Failed to update rain delay on robot: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error calling rain_delay API: $e");
    }
  }

  /// Cancels the local and remote rain-delay state.
  Future<void> skipRainDelay() async {
    _clearRainStoppedTime();
    _hasWarnedRainDelay = false;
    notifyListeners();

    if (currentIp.isEmpty) return;
    final url = Uri.parse("http://$currentIp:8000/api/schedule/skip_delay");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({}),
      );
      if (response.statusCode == 200) {
        debugPrint(
          "Skip rain delay sent successfully to robot via REST API: ${response.body}",
        );
      } else {
        debugPrint(
          "Failed to skip rain delay on robot: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error calling skip_delay API: $e");
    }
  }

  /// Whether the mower is currently waiting for the lawn to dry.
  bool get isRainDelayActive {
    if (rainDetected) return false;
    if (rainStoppedAt == null) return false;
    if (rainDelayMinutes == 0) return false;

    final elapsed = DateTime.now().difference(rainStoppedAt!).inMinutes;
    if (elapsed >= rainDelayMinutes) {
      _clearRainStoppedTime();
      return false;
    }
    return true;
  }

  /// Returns the number of whole minutes remaining in the rain delay.
  int get remainingRainDelayMinutes {
    if (!isRainDelayActive || rainStoppedAt == null) return 0;
    final elapsed = DateTime.now().difference(rainStoppedAt!).inMinutes;
    final remaining = rainDelayMinutes - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  void _clearRainStoppedTime() {
    rainStoppedAt = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('rain_stopped_at');
    });
  }

  void _saveRainStoppedTime(DateTime time) {
    rainStoppedAt = time;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('rain_stopped_at', time.toIso8601String());
    });
  }

  // --- ADDITIONAL TELEMETRY ---
  double batteryVoltage = 0.0;
  double batteryCurrent = 0.0;
  double batteryTemp = 0.0;
  double cutterAmps = 0.0;
  bool bladeActive = false;
  int cutterRpm = 0;
  double cutterPowerWatts = 0.0;
  double driveMotorsCurrent = 0.0;
  double cpuTemp = 0.0;

  // --- OPERATING STATISTICS ---
  double totalDistanceKm = 0.0;
  int totalMowingMinutes = 0;
  int operatingMinutes = 0; // for compatibility with NerdMetricsScreen
  int chargeCycles = 0;

  // --- MAP AND POSITIONING ---
  double currentX = 0.0;
  double currentY = 0.0;

  // History of every point visited by the robot (the route trace).
  final List<Offset> pathHistory = [];

  // For GPS Projection to Local Meters
  double? _referenceLat;
  double? _referenceLon;

  // Variables to avoid spam
  bool _hasWarnedBattery = false;
  bool _hasWarnedRtk = false;
  bool _hasWarnedDocking = false;
  bool _hasWarnedCharging = false;
  bool _hasWarnedStuck = false;

  // --- POSITION AND MAP UPDATE ---
  /// Adds a local map coordinate to the route history.
  void updatePosition(double x, double y) {
    currentX = x;
    currentY = y;
    pathHistory.add(Offset(x, y));
    notifyListeners();
  }

  /// Converts GPS coordinates into local canvas offsets using a local origin.
  void updateGPSPosition(double lat, double lon) {
    if (lat == 0.0 || lon == 0.0) return;

    if (_referenceLat == null || _referenceLon == null) {
      _referenceLat = lat;
      _referenceLon = lon;
    }

    // Simple equirectangular projection to local meters
    double latRad = lat * math.pi / 180.0;
    double dy = (lat - _referenceLat!) * 111111.0;
    double dx = (lon - _referenceLon!) * 111111.0 * math.cos(latRad);

    // Map to canvas coordinates centered around 150, 150
    double mapX = 150.0 + dx;
    double mapY = 150.0 - dy; // Invert Y because canvas Y goes down

    updatePosition(mapX, mapY);
  }

  /// Clears the route and resets the GPS projection origin.
  void clearPath() {
    pathHistory.clear();
    _referenceLat = null;
    _referenceLon = null;
    notifyListeners();
  }

  // --- CONNECTION ---
  /// Opens the mower WebSocket and begins processing incoming telemetry.
  void connect(String name, String ip) {
    currentName = name;
    currentIp = ip;
    // Updated to Port 8000 and /ws endpoint for the optimized FastAPI backend
    final url = 'ws://$ip:8000/ws';

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
    } catch (e) {
      isConnected = false;
      notifyListeners();
    }
  }

  // --- DISCONNECT ---
  /// Closes the mower WebSocket and publishes the disconnected state.
  void disconnect() {
    _channel?.sink.close();
    isConnected = false;
    notifyListeners();
  }

  /// Maps the backend's numeric state code to user-facing text.
  String _mapStateCodeToString(int code) {
    switch (code) {
      case 0:
        return "STOP";
      case 1:
        return "MOWING";
      case 2:
        return "DOCKING";
      case 3:
        return "CHARGING";
      case 4:
        return "STUCK";
      case 5:
        return "EMERGENCY STOP";
      case 6:
        return "BLADE BLOCKED";
      case 7:
        return "SEEKING WIRE";
      case 8:
        return "RAIN";
      case 9:
        return "DRYING";
      default:
        return "UNKNOWN STATE ($code)";
    }
  }

  // --- MESSAGE PARSING ---
  /// Parses one telemetry payload and updates the relevant observable fields.
  void _handleIncomingMessage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Parse GPS Diagnostics
    if (data.containsKey('gps')) {
      final gps = data['gps'] as Map<String, dynamic>;
      double lat = (gps['lat'] as num? ?? 0.0).toDouble();
      double lon = (gps['lon'] as num? ?? 0.0).toDouble();

      // Update coordinates dynamically on the map
      updateGPSPosition(lat, lon);

      rtkStatus = gps['rtk_text'] ?? gps['status'] ?? 'No Fix';
      satellites = gps['satellites'] as int? ?? 0;

      // Check RTK Warning settings
      bool allowRtk = prefs.getBool('notif_rtk') ?? true;
      int rtkCode = gps['rtk_code'] as int? ?? 0;
      if (rtkCode != 3 && !_hasWarnedRtk && allowRtk) {
        notificationService.showWarning(
          id: 2,
          title: "GNSS Warning",
          body: "Lost RTK Centimeter Fix! Current status: $rtkStatus.",
        );
        _hasWarnedRtk = true;
      } else if (rtkCode == 3) {
        _hasWarnedRtk = false;
      }
    }

    // 2. Parse Battery Health
    if (data.containsKey('battery')) {
      final battery = data['battery'] as Map<String, dynamic>;
      batteryLevel = (battery['percentage'] as num? ?? 100.0).toDouble();
      batteryVoltage = (battery['voltage'] as num? ?? 0.0).toDouble();
      batteryCurrent = (battery['current'] as num? ?? 0.0).toDouble();
      batteryTemp = (battery['temperature_celsius'] as num? ?? 0.0).toDouble();
      chargeCycles = battery['charge_cycles'] as int? ?? 0;

      // Check Low Battery settings
      bool allowBattery = prefs.getBool('notif_battery') ?? true;
      if (batteryLevel < 20.0 && !_hasWarnedBattery && allowBattery) {
        notificationService.showWarning(
          id: 1,
          title: "Low Battery!",
          body: "OmniMow has only ${batteryLevel.toInt()}% battery remaining.",
        );
        _hasWarnedBattery = true;
      } else if (batteryLevel > 25.0) {
        _hasWarnedBattery = false;
      }
    }

    // 3. Parse System State
    if (data.containsKey('state')) {
      int stateCode = data['state'] as int? ?? 0;
      mowerState = _mapStateCodeToString(stateCode);

      // Check State-based warnings
      // State 4 = STUCK.
      bool allowStuck = prefs.getBool('notif_stuck') ?? true;
      if (stateCode == 4 && !_hasWarnedStuck && allowStuck) {
        notificationService.showWarning(
          id: 5,
          title: "CRITICAL WARNING",
          body: "The robot is stuck and requires assistance!",
        );
        _hasWarnedStuck = true;
      } else if (stateCode != 4) {
        _hasWarnedStuck = false;
      }

      // State 2 = DOCKING.
      bool allowDocking = prefs.getBool('notif_docking') ?? false;
      if (stateCode == 2 && !_hasWarnedDocking && allowDocking) {
        notificationService.showWarning(
          id: 3,
          title: "OmniMow",
          body: "Returning to docking station.",
        );
        _hasWarnedDocking = true;
      } else if (stateCode != 2) {
        _hasWarnedDocking = false;
      }

      // State 3 = CHARGING.
      bool allowCharging = prefs.getBool('notif_charging') ?? false;
      if (stateCode == 3 && !_hasWarnedCharging && allowCharging) {
        notificationService.showWarning(
          id: 4,
          title: "Charging",
          body: "The robot is now in the charger and receiving power.",
        );
        _hasWarnedCharging = true;
      } else if (stateCode != 3) {
        _hasWarnedCharging = false;
      }
    }

    // 4. Parse Cutter Motor & Power Consumption
    int cutterStatus = data['cutter_status'] as int? ?? 0;
    bladeActive = (cutterStatus == 1);
    cutterRpm = data['cutter_rpm'] as int? ?? 0;

    if (data.containsKey('power_consumption')) {
      final power = data['power_consumption'] as Map<String, dynamic>;
      cutterAmps = (power['cutter_motor_current_ampere'] as num? ?? 0.0)
          .toDouble();
      cutterPowerWatts = (power['cutter_motor_power_watts'] as num? ?? 0.0)
          .toDouble();
      driveMotorsCurrent = (power['drive_motors_current_ampere'] as num? ?? 0.0)
          .toDouble();
    }

    // 5. Parse Statistics
    if (data.containsKey('statistics')) {
      final stats = data['statistics'] as Map<String, dynamic>;
      totalDistanceKm = (stats['total_distance_km'] as num? ?? 0.0).toDouble();

      double runtimeHours = (stats['total_runtime_hours'] as num? ?? 0.0)
          .toDouble();
      totalMowingMinutes = (runtimeHours * 60).toInt();
      operatingMinutes = totalMowingMinutes; // For backward compatibility
    }

    // 6. Parse System CPU Diagnostics (Now enriched with WiFi and Rain Sensor)
    if (data.containsKey('system')) {
      final sys = data['system'] as Map<String, dynamic>;
      cpuTemp = (sys['cpu_temp_celsius'] as num? ?? 0.0).toDouble();
      double cpuLoadPct = (sys['cpu_load_pct'] as num? ?? 0.0).toDouble();
      cpuLoad =
          "${cpuLoadPct.toStringAsFixed(1)}% (${cpuTemp.toStringAsFixed(1)}°C)";

      // Parse enriched system telemetry from backend.py
      // Parse enriched system telemetry (supports both nested PDF and old flat JSON structures)
      if (sys.containsKey('wifi') && sys['wifi'] is Map) {
        final wifi = sys['wifi'] as Map<String, dynamic>;
        wifiSignalPct = (wifi['percentage'] as num? ?? 0).toInt();
      } else {
        wifiSignalPct = sys['wifi_signal_pct'] as int? ?? 0;
      }

      bool wasRaining = rainDetected;
      rainDetected = sys['rain_detected'] as bool? ?? false;

      // Transition detection
      if (wasRaining && !rainDetected) {
        _saveRainStoppedTime(DateTime.now());
        _hasWarnedRainDelay = false;
      } else if (rainDetected) {
        _clearRainStoppedTime();
      }

      // Smart Rain Detection Warning and local push notification alert
      bool allowRain = prefs.getBool('notif_rain') ?? true;
      if (rainDetected && !_hasWarnedRain && allowRain) {
        notificationService.showWarning(
          id: 6,
          title: "Rain Detected!",
          body: "OmniMow has detected rain. Returning to docking station to protect the lawn.",
        );
        _hasWarnedRain = true;
      } else if (!rainDetected) {
        _hasWarnedRain = false;

        // Push notification when rain delay starts
        if (isRainDelayActive && !_hasWarnedRainDelay && allowRain) {
          notificationService.showWarning(
            id: 7,
            title: "Rain Stopped",
            body:
                "Rain has stopped. Rain delay active for $rainDelayMinutes minutes to let the lawn dry.",
          );
          _hasWarnedRainDelay = true;
        }
      }
    }

    notifyListeners();
  }

  // --- COMMANDS FOR THE ROBOT ---
  /// Sends a command payload through the active mower WebSocket.
  void sendCommand(String command) {
    if (!isConnected) return;

    debugPrint("Command sent to robot: $command");

    // Direct FastAPI WebSocket payload
    final msg = {'command': command};
    _channel?.sink.add(jsonEncode(msg));
  }

  /// Converts the selected schedule into the backend's weekly JSON format.
  Future<void> saveSchedule(
    List<String> selectedDays,
    TimeOfDay startTime,
    int durationHours,
  ) async {
    if (currentIp.isEmpty) return;

    // Map weekday name to the PDF index string (0 = Monday, 6 = Sunday)
    final Map<String, String> dayMapping = {
      'Mon': '0',
      'Man': '0',
      'Tue': '1',
      'Tir': '1',
      'Wed': '2',
      'Ons': '2',
      'Thu': '3',
      'Tor': '3',
      'Fri': '4',
      'Fre': '4',
      'Sat': '5',
      'Lør': '5',
      'Sun': '6',
      'Søn': '6',
    };

    // Format start time as HH:MM
    final String startStr =
        "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}";

    // Calculate end time on the same day
    int endHour = startTime.hour + durationHours;
    int endMinute = startTime.minute;
    if (endHour >= 24) {
      endHour = 23;
      endMinute = 59;
    }
    final String endStr =
        "${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}";

    // Build the "days" map according to the PDF
    final Map<String, List<Map<String, String>>> daysJson = {};
    for (int i = 0; i < 7; i++) {
      daysJson[i.toString()] = [];
    }

    for (var day in selectedDays) {
      final String? key = dayMapping[day];
      if (key != null) {
        daysJson[key] = [
          {"start": startStr, "end": endStr},
        ];
      }
    }

    final payload = {"enabled": true, "days": daysJson};

    final url = Uri.parse("http://$currentIp:8000/api/schedule");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        debugPrint(
          "Schedule updated successfully on the robot via REST API: ${response.body}",
        );
      } else {
        debugPrint(
          "Failed to update schedule via REST API: ${response.statusCode}",
        );
      }
    } catch (e) {
      debugPrint("Error sending schedule to robot REST API: $e");
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}

// Global service instance shared by the entire app.
final rosService = RosService();
