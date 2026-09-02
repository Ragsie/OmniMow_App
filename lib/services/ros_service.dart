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
  String currentName = "NuroMow Dashboard";

  // --- ROBOT STATE (Live data) ---
  String mowerState = "STOP";
  double batteryLevel = 100.0;
  double progress = 0.0;
  String rtkStatus = "Waiting for Fix...";
  String cpuLoad = "Unknown";
  int satellites = 0;

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

  // --- STATISTICS ---
  double totalDistanceKm = 0.0;
  int totalMowingMinutes = 0;
  int operatingMinutes = 0; // For backward compatibility with screens
  int chargeCycles = 0;

  // --- KORT & POSITIONERING ---
  double currentX = 0.0;
  double currentY = 0.0;

  // Historik-liste over alle punkter robotten har kørt igennem (Sporet)
  final List<Offset> pathHistory = [];

  // GPS-referencepunkter til lokal projektion
  double? _referenceLat;
  double? _referenceLon;

  // Variabler til at undgå notifikations-spam
  bool _hasWarnedBattery = false;
  bool _hasWarnedRtk = false;
  bool _hasWarnedDocking = false;
  bool _hasWarnedCharging = false;
  bool _hasWarnedStuck = false;

  // --- POSITION & MAP UPDATE ---
  void updatePosition(double x, double y) {
    currentX = x;
    currentY = y;
    pathHistory.add(Offset(x, y));
    notifyListeners();
  }

  // Projekterer Lat/Lon geografiske koordinater til lokale pixels på kortet
  void updateGPSPosition(double lat, double lon) {
    if (lat == 0.0 || lon == 0.0) return;

    if (_referenceLat == null || _referenceLon == null) {
      _referenceLat = lat;
      _referenceLon = lon;
    }

    // Enkel flad projektion til lokale meter
    double latRad = lat * math.pi / 180.0;
    double dy = (lat - _referenceLat!) * 111111.0;
    double dx = (lon - _referenceLon!) * 111111.0 * math.cos(latRad);

    // Centrer på et 300x300 canvas område (midtpunkt 150, 150)
    double mapX = 150.0 + dx;
    double mapY = 150.0 - dy; // Inverter Y fordi canvas Y går nedad

    updatePosition(mapX, mapY);
  }

  // Rydder kørte spor
  void clearPath() {
    pathHistory.clear();
    _referenceLat = null;
    _referenceLon = null;
    notifyListeners();
  }

  // --- FORBINDELSE ---
  void connect(String name, String ip) {
    currentName = name;  
    currentIp = ip;
    final url = 'ws://$ip:8000/ws'; // FastAPI WebSocket endpoint på port 8000

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

  // Map state codes from the API dictionary to readable English text
  String _mapStateCodeToString(int code) {
    switch (code) {
      case 0:
        return "STOP";
      case 1:
        return "MOWING";
      case 2:
        return "RETURNING TO DOCK";
      case 3:
        return "CHARGING";
      case 4:
        return "STUCK";
      case 5:
        return "EMERGENCY STOP";
      case 6:
        return "BLADE BLOCKED";
      case 7:
        return "SEARCHING EDGE";
      default:
        return "Unknown state ($code)";
    }
  }

  // --- PARSING AF INDKOMMENDE JSON PAYLOAD ---
  void _handleIncomingMessage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Parse GPS Diagnostics
    if (data.containsKey('gps')) {
      final gps = data['gps'] as Map<String, dynamic>;
      double lat = (gps['lat'] as num? ?? 0.0).toDouble();
      double lon = (gps['lon'] as num? ?? 0.0).toDouble();

      updateGPSPosition(lat, lon);

      rtkStatus = gps['rtk_text'] ?? gps['status'] ?? 'No Fix';
      satellites = gps['satellites'] as int? ?? 0;

      // RTK Advarsel
      bool allowRtk = prefs.getBool('notif_rtk') ?? true;
      int rtkCode = gps['rtk_code'] as int? ?? 0;
      if (rtkCode != 3 && !_hasWarnedRtk && allowRtk) {
        notificationService.showWarning(
          id: 2,
          title: "GNSS Warning",
          body: "Lost RTK centimeter fix! Current status: $rtkStatus."
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

      // Battery alert below 20%
      bool allowBattery = prefs.getBool('notif_battery') ?? true;
      if (batteryLevel < 20.0 && !_hasWarnedBattery && allowBattery) {
        notificationService.showWarning(
          id: 1,
          title: "Low Battery!",
          body: "OpenMow AI only has ${batteryLevel.toInt()}% battery left."
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

      // State 4 = STUCK / SIDDER FAST
      bool allowStuck = prefs.getBool('notif_stuck') ?? true;
      if (stateCode == 4 && !_hasWarnedStuck && allowStuck) {
        notificationService.showWarning(
          id: 5,
          title: "CRITICAL WARNING",
          body: "The mower is stuck and needs help!"
        );
        _hasWarnedStuck = true;
      } else if (stateCode != 4) {
        _hasWarnedStuck = false;
      }

      // State 2 = DOCKING / SØGER DOCK
      bool allowDocking = prefs.getBool('notif_docking') ?? false;
      if (stateCode == 2 && !_hasWarnedDocking && allowDocking) {
        notificationService.showWarning(
          id: 3,
          title: "Landroid",
          body: "The mower is returning to the charging dock."
        );
        _hasWarnedDocking = true;
      } else if (stateCode != 2) {
        _hasWarnedDocking = false;
      }

      // State 3 = CHARGING / OPLADER
      bool allowCharging = prefs.getBool('notif_charging') ?? false;
      if (stateCode == 3 && !_hasWarnedCharging && allowCharging) {
        notificationService.showWarning(
          id: 4,
          title: "Charging",
          body: "The mower is now on the dock and charging."
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
      cutterAmps = (power['cutter_motor_current_ampere'] as num? ?? 0.0).toDouble();
      cutterPowerWatts = (power['cutter_motor_power_watts'] as num? ?? 0.0).toDouble();
      driveMotorsCurrent = (power['drive_motors_current_ampere'] as num? ?? 0.0).toDouble();
    }

    // 5. Parse Statistics
    if (data.containsKey('statistics')) {
      final stats = data['statistics'] as Map<String, dynamic>;
      totalDistanceKm = (stats['total_distance_km'] as num? ?? 0.0).toDouble();

      double runtimeHours = (stats['total_runtime_hours'] as num? ?? 0.0).toDouble();
      totalMowingMinutes = (runtimeHours * 60).toInt();
      operatingMinutes = totalMowingMinutes;
    }

    // 6. Parse System CPU Diagnostics (Orange Pi 5 Ultra)
    if (data.containsKey('system')) {
      final sys = data['system'] as Map<String, dynamic>;
      cpuTemp = (sys['cpu_temp_celsius'] as num? ?? 0.0).toDouble();
      double cpuLoadPct = (sys['cpu_load_pct'] as num? ?? 0.0).toDouble();
      cpuLoad = "${cpuLoadPct.toStringAsFixed(1)}% (${cpuTemp.toStringAsFixed(1)}°C)";
    }

    notifyListeners();
  }

  // --- COMMANDS FOR THE ROBOT ---
  void sendCommand(String command) {
    if (!isConnected) return;

    debugPrint("Command sent to robot: $command");

    final msg = {
      'command': command
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  // Gem og send klippedage og klokkeslæt
  void saveSchedule(List<String> days, TimeOfDay time) {
    if (!isConnected) return;

    final scheduleData = {
      'days': days,
      'hour': time.hour,
      'minute': time.minute,
    };

    debugPrint("Schedule saved and sent: $scheduleData");

    final msg = {
      'schedule': scheduleData
    };
    _channel?.sink.add(jsonEncode(msg));
  }

  // --- OFFLINE SIMULATOR FOR TEST ---
  Timer? _simTimer;
  double _simHeading = 0.0;

  void startSimulation() {
    isConnected = true;
    rtkStatus = "RTK Centimeter-Fix (Perfekt)";
    satellites = 24;
    cpuLoad = "42.0% (45.0°C)";
    bladeActive = true;
    cutterAmps = 4.2;
    cutterRpm = 2850;
    cutterPowerWatts = 43.6;
    totalDistanceKm = 12.5;
    totalMowingMinutes = 145;
    operatingMinutes = 145;
    chargeCycles = 12;
    cpuTemp = 45.0;
    batteryVoltage = 24.2;
    batteryCurrent = -3.2;
    batteryTemp = 28.5;

    if (currentX == 0 && currentY == 0) {
      currentX = 150.0;
      currentY = 150.0;
    }

    _simTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _simHeading += 0.05;
      double speed = 2.0;

      double newX = currentX + (speed * math.cos(_simHeading));
      double newY = currentY + (speed * math.sin(_simHeading));

      updatePosition(newX, newY);

      batteryLevel = math.max(0.0, batteryLevel - 0.01);
      progress = math.min(100.0, progress + 0.05);
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