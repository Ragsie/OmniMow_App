import 'package:http/http.dart' as http;

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Port of the OmniMow app backend (FastAPI). rosbridge uses 8000 on the robot.
const int backendPort = 9000;

/// Coordinates the mower WebSocket, REST commands, telemetry, and app state.
class RosService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _pollTimer;
  bool isConnected = false;

  /// Why the last connection attempt failed or dropped (null when fine).
  String? connectionError;

  String currentIp = "";
  String currentName = "OmniMow Dashboard";

  // --- ROBOT STATE (Live data) ---
  String mowerState = "STOP";
  double batteryLevel = 100.0;
  double progress = 0.0;
  String cpuLoad = "Unknown";

  // --- MOWING MISSION (mowing_control) ---
  bool missionActive = false;
  String missionState = "UNKNOWN";
  String missionMessage = "";
  bool hazardInView = false;
  String _lastMissionState = "";

  // --- STEREO CALIBRATION (first boot) ---
  String calibrationState = "unknown";
  int calibrationSamples = 0;
  int calibrationNeeded = 30;
  String calibrationMessage = "";
  double? calibrationRms;
  double? calibrationBaselineMm;
  double? calibrationFocalPx;
  bool _hasWarnedCalibration = false;

  bool get isCalibrated => calibrationState == "done";

  /// Short text for the status pill on the dashboard.
  String get calibrationLabel {
    switch (calibrationState) {
      case "done":
        return "Camera calibrated";
      case "waiting_for_board":
        return "Calibration: show board";
      case "capturing":
      case "retrying":
        return "Calibration $calibrationSamples/$calibrationNeeded";
      case "calibrating":
        return "Calibrating...";
      case "recalibration_requested":
        return "Recalibrating...";
      case "failed":
        return "Calibration failed";
      default:
        return "Calibration unknown";
    }
  }

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
  Uri _api(String path) => Uri.parse("http://$currentIp:$backendPort$path");

  /// POSTs to the backend and returns its message (or the error) for a snackbar.
  Future<String> _post(String path, [Map<String, dynamic>? body]) async {
    if (currentIp.isEmpty) return "Not connected to a mower";
    try {
      final response = await http
          .post(
            _api(path),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body ?? {}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return "Mower answered ${response.statusCode}";
      }
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return "OK";
    } catch (e) {
      return "Could not reach the mower: $e";
    }
  }

  // --- MOWING COMMANDS (REST, so the app gets the mower's answer) ---
  Future<String> startMowing() => _post("/api/mowing/start");
  Future<String> stopMowing() => _post("/api/mowing/stop");
  Future<String> returnHome() => _post("/api/mowing/return_home");

  /// The mower drives along the lawn edge by itself and saves the loop as a zone.
  Future<String> startAutoMap() => _post("/api/zones/auto_map");

  /// Starts a new stereo calibration (hold the checkerboard in front of the cameras).
  Future<String> restartCalibration() => _post("/api/calibration/restart");

  /// Loads the lawn zones (map frame, metres) for the map.
  Future<void> loadZones() async {
    if (currentIp.isEmpty) return;
    try {
      final response = await http
          .get(_api("/api/zones"))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      zones = [
        for (final zone in (data['zones'] as List? ?? []))
          if (zone is Map && zone['enabled'] != false)
            [
              for (final p in (zone['boundary'] as List? ?? []))
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
            ],
      ];
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading zones: $e");
    }
  }

  Future<void> updateRainDelayConfig(int minutes) async {
    rainDelayMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('rain_delay_minutes', minutes);
    notifyListeners();

    if (currentIp.isEmpty) return;
    final url = _api("/api/schedule/rain_delay");
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
    final url = _api("/api/schedule/skip_delay");
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
  int ramUsedMb = 0;
  int ramTotalMb = 0;
  double ramUsedPct = 0.0;

  // --- OPERATING STATISTICS ---
  double totalDistanceKm = 0.0;
  int totalMowingMinutes = 0;
  int operatingMinutes = 0; // for compatibility with NerdMetricsScreen
  int chargeCycles = 0;

  // --- MAP AND POSITIONING ---
  // Position on the mower's SLAM map in metres (x east/forward from the dock, y left),
  // the map origin is the charging station.
  double currentX = 0.0;
  double currentY = 0.0;
  double currentYaw = 0.0;
  bool hasPose = false;

  // History of every point visited by the robot (the route trace), in metres.
  final List<Offset> pathHistory = [];

  // Lawn zones recorded by the mower (metres, map frame).
  List<List<Offset>> zones = [];

  // Variables to avoid spam
  bool _hasWarnedBattery = false;
  bool _hasWarnedDocking = false;
  bool _hasWarnedCharging = false;
  bool _hasWarnedStuck = false;

  // --- POSITION AND MAP UPDATE ---
  /// Adds a map position (metres) to the route history.
  void updatePosition(double x, double y, double yaw) {
    currentX = x;
    currentY = y;
    currentYaw = yaw;
    hasPose = true;
    if (pathHistory.isEmpty ||
        (pathHistory.last - Offset(x, y)).distance >= 0.1) {
      pathHistory.add(Offset(x, y));
      if (pathHistory.length > 20000) pathHistory.removeAt(0);
    }
  }

  /// Clears the route trace.
  void clearPath() {
    pathHistory.clear();
    notifyListeners();
  }

  // --- CONNECTION ---
  /// Opens the mower WebSocket and begins processing incoming telemetry.
  Future<void> connect(String name, String ip) async {
    // Close a previous connection first, so its onDone cannot reset the new one.
    _stopPolling();
    _channel?.sink.close();
    _channel = null;
    isConnected = false;

    currentName = name;
    currentIp = ip;
    connectionError = null;
    notifyListeners();
    final url = 'ws://$ip:$backendPort/ws';

    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    try {
      // The handshake fails here (not in connect) if the mower is unreachable.
      await channel.ready.timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint("WebSocket connection to $url failed: $e");
      if (_channel == channel) {
        _channel = null;
        connectionError = e.toString();
        notifyListeners();
      }
      return;
    }
    if (_channel != channel) return; // a newer connect() took over

    isConnected = true;
    notifyListeners();
    loadZones();
    _startPolling();

    channel.stream.listen(
      (data) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            _handleIncomingMessage(decoded).catchError((Object e) {
              debugPrint("Could not parse telemetry from mower: $e");
              notifyListeners();
            });
          }
        } catch (e) {
          debugPrint("Ignoring invalid message from mower: $e");
        }
      },
      onError: (e) {
        if (_channel != channel) return;
        _stopPolling();
        connectionError = e.toString();
        isConnected = false;
        notifyListeners();
      },
      onDone: () {
        if (_channel != channel) return;
        _stopPolling();
        isConnected = false;
        notifyListeners();
      },
    );
  }

  /// The backend does not push all telemetry over the WebSocket, so poll the REST
  /// endpoints that have it.
  void _startPolling() {
    _stopPolling();
    _pollCalibration();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pollCalibration(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollCalibration() async {
    if (currentIp.isEmpty) return;
    try {
      final response = await http
          .get(_api("/api/calibration"))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return;
      final cal = jsonDecode(response.body);
      if (cal is Map<String, dynamic>) {
        await _handleIncomingMessage({'calibration': cal});
      }
    } catch (e) {
      debugPrint("Error loading calibration: $e");
    }
  }

  // --- DISCONNECT ---
  /// Closes the mower WebSocket and publishes the disconnected state.
  void disconnect() {
    _stopPolling();
    _channel?.sink.close();
    _channel = null;
    isConnected = false;
    notifyListeners();
  }

  /// Reads an int the backend may send as int, double or numeric string.
  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return num.tryParse(value)?.toInt() ?? 0;
    return 0;
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
  Future<void> _handleIncomingMessage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // Answer to a command sent over the websocket
    if (data.containsKey('command_result')) {
      final result = data['command_result'] as Map<String, dynamic>;
      debugPrint("Command ${result['command']}: ${result['message']}");
      return;
    }

    // 1. Stereo calibration (replaces GPS: the mower localizes with its cameras)
    if (data['calibration'] is Map) {
      final cal = data['calibration'] as Map<String, dynamic>;
      calibrationState = cal['state'] as String? ?? 'unknown';
      calibrationSamples = (cal['samples'] as num? ?? 0).toInt();
      calibrationNeeded = (cal['needed'] as num? ?? 30).toInt();
      calibrationMessage = cal['message'] as String? ?? '';
      final result = cal['result'];
      if (result is Map) {
        calibrationRms = (result['rms_stereo'] as num?)?.toDouble();
        final baseline = (result['baseline'] as num?)?.toDouble();
        calibrationBaselineMm = baseline == null ? null : baseline * 1000.0;
        calibrationFocalPx = (result['focal_px'] as num?)?.toDouble();
      }

      bool allowCalibration = prefs.getBool('notif_calibration') ?? true;
      if (!isCalibrated &&
          calibrationState != 'unknown' &&
          !_hasWarnedCalibration &&
          allowCalibration) {
        notificationService.showWarning(
          id: 2,
          title: "Camera calibration needed",
          body: calibrationState == 'failed'
              ? "Stereo calibration failed: $calibrationMessage"
              : "Hold the checkerboard in front of the mower's cameras to calibrate them.",
        );
        _hasWarnedCalibration = true;
      } else if (isCalibrated) {
        _hasWarnedCalibration = false;
      }
    }

    // 1b. Mowing mission: state, progress and position on the SLAM map
    if (data['mission'] is Map) {
      final mission = data['mission'] as Map<String, dynamic>;
      missionActive = mission['active'] as bool? ?? false;
      missionState = mission['state'] as String? ?? 'UNKNOWN';
      missionMessage = mission['message'] as String? ?? '';
      progress = (mission['progress_pct'] as num? ?? 0.0).toDouble();
      hazardInView = mission['hazard'] as bool? ?? false;
      final pose = mission['pose'];
      if (pose is List && pose.length >= 3) {
        updatePosition(
          (pose[0] as num).toDouble(),
          (pose[1] as num).toDouble(),
          (pose[2] as num).toDouble(),
        );
      }
      // A finished edge mapping run saved a new zone: reload the zones for the map
      if (missionState != _lastMissionState && missionState == 'DONE') {
        loadZones();
      }
      _lastMissionState = missionState;
    }

    // 2. Parse Battery Health
    if (data['battery'] is Map) {
      final battery = data['battery'] as Map<String, dynamic>;
      batteryLevel = (battery['percentage'] as num? ?? 100.0).toDouble();
      batteryVoltage = (battery['voltage'] as num? ?? 0.0).toDouble();
      batteryCurrent = (battery['current'] as num? ?? 0.0).toDouble();
      batteryTemp = (battery['temperature_celsius'] as num? ?? 0.0).toDouble();
      chargeCycles = _toInt(battery['charge_cycles']);

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

    // 3. Parse System State (the mission state is shown while a mission runs)
    if (data['state'] != null) {
      int stateCode = _toInt(data['state']);
      mowerState = missionActive && stateCode != 4 && stateCode != 5
          ? missionState
          : _mapStateCodeToString(stateCode);

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

    // 4. Parse Cutter Motor & Power Consumption (only when the payload has them,
    // so a calibration-only update does not reset the blade state)
    if (data.containsKey('cutter_status') || data['mission'] is Map) {
      int cutterStatus = _toInt(data['cutter_status']);
      bladeActive =
          (cutterStatus == 1) ||
          (data['mission'] is Map &&
              (data['mission']['blade_on'] as bool? ?? false));
    }
    if (data.containsKey('cutter_rpm')) {
      cutterRpm = _toInt(data['cutter_rpm']);
    }

    if (data['power_consumption'] is Map) {
      final power = data['power_consumption'] as Map<String, dynamic>;
      cutterAmps = (power['cutter_motor_current_ampere'] as num? ?? 0.0)
          .toDouble();
      cutterPowerWatts = (power['cutter_motor_power_watts'] as num? ?? 0.0)
          .toDouble();
      driveMotorsCurrent = (power['drive_motors_current_ampere'] as num? ?? 0.0)
          .toDouble();
    }

    // 5. Parse Statistics
    if (data['statistics'] is Map) {
      final stats = data['statistics'] as Map<String, dynamic>;
      totalDistanceKm = (stats['total_distance_km'] as num? ?? 0.0).toDouble();

      double runtimeHours = (stats['total_runtime_hours'] as num? ?? 0.0)
          .toDouble();
      totalMowingMinutes = (runtimeHours * 60).toInt();
      operatingMinutes = totalMowingMinutes; // For backward compatibility
    }

    // 6. Parse System CPU Diagnostics (Now enriched with WiFi and Rain Sensor)
    if (data['system'] is Map) {
      final sys = data['system'] as Map<String, dynamic>;
      cpuTemp = (sys['cpu_temp_celsius'] as num? ?? 0.0).toDouble();
      double cpuLoadPct = (sys['cpu_load_pct'] as num? ?? 0.0).toDouble();
      cpuLoad =
          "${cpuLoadPct.toStringAsFixed(1)}% (${cpuTemp.toStringAsFixed(1)}°C)";

      if (sys['memory'] is Map) {
        final mem = sys['memory'] as Map<String, dynamic>;
        ramUsedMb = _toInt(mem['used_mb']);
        ramTotalMb = _toInt(mem['total_mb']);
        ramUsedPct = (mem['used_pct'] as num? ?? 0.0).toDouble();
      }

      // Parse enriched system telemetry from backend.py
      // Parse enriched system telemetry (supports both nested PDF and old flat JSON structures)
      if (sys.containsKey('wifi') && sys['wifi'] is Map) {
        final wifi = sys['wifi'] as Map<String, dynamic>;
        wifiSignalPct = (wifi['percentage'] as num? ?? 0).toInt();
      } else {
        wifiSignalPct = _toInt(sys['wifi_signal_pct']);
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
  /// Sends a command payload through the active mower WebSocket
  /// ("start", "stop", "home", "auto_map"). Prefer the REST methods above, which return the answer.
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

    final url = _api("/api/schedule");
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
    _stopPolling();
    _channel?.sink.close();
    super.dispose();
  }
}

// Global service instance shared by the entire app.
final rosService = RosService();
