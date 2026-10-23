import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/ros_service.dart';
import 'services/notification_service.dart';
import 'services/update_service.dart';
import 'screens/connection_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/nerd_metrics_screen.dart';
import 'screens/schedule_screen.dart';
import 'services/live_feed.dart';
import 'widgets/mower_map_painter.dart';
import 'widgets/glass_card.dart'; // Direct GlassCard import
import 'widgets/mower_update_dialog.dart';

// Global ValueNotifier to handle System, Light, and Dark themes dynamically
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(
  ThemeMode.system,
);

/// Loads persisted app settings and starts the provider-backed Flutter app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final savedThemeIndex =
      prefs.getInt('theme_mode') ?? 0; // 0=System, 1=Light, 2=Dark
  themeNotifier.value = ThemeMode.values[savedThemeIndex];

  // Initialize local notifications and request permission before alerts are shown
  await notificationService.init();

  // Initialize rosService settings (Rain delay values etc.)
  await rosService.initSettings();

  // Check if mower list is empty to decide initial screen
  final List<String> mowerStrings = prefs.getStringList('mower_list') ?? [];
  final bool hasMowers = mowerStrings.isNotEmpty;

  // Reconnect to the last used mower (or the first saved one) on startup.
  if (hasMowers) {
    final lastIp = prefs.getString('robot_ip');
    final saved = [
      for (final str in mowerStrings)
        if (str.split('|').length == 2) str.split('|'),
    ];
    final mower = saved.firstWhere(
      (m) => m[1] == lastIp,
      orElse: () => saved.isNotEmpty ? saved.first : const [],
    );
    if (mower.length == 2) rosService.connect(mower[0], mower[1]);
  }

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => rosService)],
      child: OmniMowApp(hasMowers: hasMowers),
    ),
  );
}

/// Configures themes, shared services, and the initial route for OmniMow.
class OmniMowApp extends StatelessWidget {
  final bool hasMowers;
  const OmniMowApp({super.key, required this.hasMowers});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'OmniMow',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,

          // Light Theme Design Configuration (Off-white canvas, Emerald green accents)
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00C853),
              brightness: Brightness.light,
              primary: const Color(0xFF00C853),
              secondary: const Color(0xFF0288D1),
              surface: const Color(0xFFF5F6FA),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F6FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Dark Theme Design Configuration (Midnight charcoal, glowing Emerald accents)
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00C853),
              brightness: Brightness.dark,
              primary: const Color(0xFF00C853),
              secondary: const Color(0xFF03A9F4),
              surface: const Color(0xFF121214),
            ),
            scaffoldBackgroundColor: const Color(0xFF0C0C0E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          home: hasMowers ? const DashboardScreen() : const ConnectionScreen(),
        );
      },
    );
  }
}

/// Displays live mower telemetry, map activity, and primary mower controls.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Schedules a silent update check after the first dashboard frame.
  @override
  void initState() {
    super.initState();
    // Silent background update check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context, showNoUpdateDialog: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ros = Provider.of<RosService>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ros.currentName),
            if (ros.isConnected) ...[
              const SizedBox(width: 10),
              // Dynamic Wi-Fi Signal Strength Indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    ros.wifiSignalPct >= 75
                        ? Icons.wifi
                        : (ros.wifiSignalPct >= 45
                              ? Icons.wifi_2_bar
                              : (ros.wifiSignalPct > 0
                                    ? Icons.wifi_1_bar
                                    : Icons.wifi_off)),
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "${ros.wifiSignalPct}%",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              // Rain / Rain Delay Badge directly in app bar
              if (ros.rainDetected || ros.isRainDelayActive) ...[
                const SizedBox(width: 12),
                Icon(
                  ros.rainDetected ? Icons.water_drop : Icons.hourglass_empty,
                  size: 16,
                  color: Colors.amberAccent,
                ),
              ],
            ],
          ],
        ),
        centerTitle: false,
        actions: [
          // New mower software release, or an update in progress
          if (ros.isConnected &&
              (ros.softwareUpdateAvailable || ros.isSoftwareUpdating))
            IconButton(
              icon: Badge(
                backgroundColor: ros.isSoftwareUpdating
                    ? Colors.blueAccent
                    : Colors.greenAccent,
                child: const Icon(Icons.system_update_alt),
              ),
              tooltip: ros.isSoftwareUpdating
                  ? 'Mower update in progress'
                  : 'Mower update available',
              onPressed: () => showMowerUpdateDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Layer 1: Map-First Fullscreen Canvas (Interactive Map Background)
          Positioned.fill(
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(500),
              minScale: 0.1,
              maxScale: 4.0,
              child: Center(
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: CustomPaint(
                    painter: MowerMapPainter(
                      path: ros.pathHistory,
                      zones: ros.zones,
                      robotPos: Offset(ros.currentX, ros.currentY),
                      robotYaw: ros.currentYaw,
                      hasPose: ros.hasPose,
                      isDark: isDark,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Layer 2: Top Floating Telemetry Pills (Frosted Glass Indicators)
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Battery Indicator Pill
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    borderRadius: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          ros.batteryLevel < 20
                              ? Icons.battery_alert
                              : (ros.mowerState == "CHARGING"
                                    ? Icons.battery_charging_full
                                    : Icons.battery_full),
                          color: ros.batteryLevel < 20
                              ? Colors.redAccent
                              : (ros.mowerState == "CHARGING"
                                    ? Colors.blueAccent
                                    : Colors.greenAccent),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${ros.batteryLevel.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Stereo Camera Calibration Pill (tap for details / recalibrate)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showCalibrationDialog(context, ros),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      borderRadius: 30,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ros.isCalibrated
                                  ? Colors.greenAccent
                                  : (ros.calibrationState == "failed"
                                        ? Colors.redAccent
                                        : Colors.orangeAccent),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ros.calibrationLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Layer 3: Bottom Control Panel & Menu Actions
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floating Translucent Menu Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Schedule Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.9),
                        foregroundColor: theme.colorScheme.onSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ScheduleScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: const Text('Schedule'),
                    ),
                    // Automatic lawn mapping (edge following)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.9),
                        foregroundColor: theme.colorScheme.onSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                      onPressed: () => _confirmAutoMap(context, ros),
                      icon: const Icon(Icons.fence, size: 18),
                      label: const Text('Map lawn'),
                    ),
                    // Nerd Metrics Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.black.withOpacity(0.5)
                            : Colors.white.withOpacity(0.9),
                        foregroundColor: theme.colorScheme.onSurface,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NerdMetricsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('Metrics'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Primary Navimow-style Translucent Control Dashboard
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 24,
                  child: Column(
                    children: [
                      // Header: Mower State and Progress Line
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _getStateColor(ros.mowerState),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ros.mowerState +
                                    (ros.rainDetected
                                        ? " (RAINING)"
                                        : (ros.isRainDelayActive
                                              ? " (RAIN DELAY)"
                                              : "")),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${ros.progress.toStringAsFixed(0)}% Done',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (ros.isRainDelayActive) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amberAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amberAccent.withOpacity(0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.hourglass_empty,
                                size: 16,
                                color: Colors.amberAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "Rain Delay active: Drying lawn... (${ros.remainingRainDelayMinutes} min left)",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amberAccent,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  ros.skipRainDelay();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Rain delay skipped manually!',
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  "Skip",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Sleek Progress Line Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ros.progress / 100.0,
                          backgroundColor: theme.colorScheme.onSurface
                              .withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Control Panel Buttons Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Send Home Button
                          _buildCircleButton(
                            context: context,
                            icon: Icons.home_outlined,
                            label: 'Home',
                            onPressed: () async {
                              final message = await ros.returnHome();
                              if (context.mounted) {
                                _showMessage(context, message);
                              }
                            },
                          ),

                          // Large Glowing Start / Pause Button
                          GestureDetector(
                            onTap: () async {
                              final message = ros.missionActive
                                  ? await ros.stopMowing()
                                  : await ros.startMowing();
                              if (context.mounted) {
                                _showMessage(context, message);
                              }
                            },
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.4),
                                    blurRadius: 18,
                                    spreadRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                ros.missionActive
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                          ),

                          // Live Video Stream Button (WebRTC camera)
                          _buildCircleButton(
                            context: context,
                            icon: Icons.videocam_outlined,
                            label: 'Live YOLO',
                            onPressed: () {
                              if (ros.currentIp.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select and connect to a mower first!',
                                    ),
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ConnectionScreen(),
                                  ),
                                );
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LiveFeedScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a compact labeled control button for the dashboard action row.
  Widget _buildCircleButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(icon, size: 24),
          onPressed: onPressed,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case "MOWING":
      case "MAPPING":
        return Colors.greenAccent;
      case "DOCKING":
      case "RETURNING":
      case "UNDOCKING":
      case "PLANNING":
        return Colors.blueAccent;
      case "CHARGING":
      case "PAUSED":
        return Colors.amberAccent;
      case "STOP":
      case "STOPPED":
      case "ERROR":
      case "EMERGENCY STOP":
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Explains and starts automatic lawn mapping (the mower follows the lawn edge).
  Future<void> _confirmAutoMap(BuildContext context, RosService ros) async {
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map the lawn'),
        content: const Text(
          'The mower leaves the dock, finds the edge of the lawn and drives around it '
          'with the edge on its right side. When it is back where it started, the loop is '
          'saved as a mowing zone and the mower returns to the dock.\n\n'
          'The blade stays off. Stay close the first time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start mapping'),
          ),
        ],
      ),
    );
    if (start != true) return;
    final message = await ros.startAutoMap();
    if (context.mounted) {
      _showMessage(context, message);
    }
  }

  /// Shows the stereo camera calibration status and lets the user recalibrate.
  void _showCalibrationDialog(BuildContext context, RosService ros) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Camera calibration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ros.calibrationLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (ros.calibrationMessage.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(ros.calibrationMessage),
            ],
            if (ros.isCalibrated && ros.calibrationRms != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error ${ros.calibrationRms!.toStringAsFixed(2)} px · '
                'baseline ${ros.calibrationBaselineMm?.toStringAsFixed(1) ?? "-"} mm · '
                'focal ${ros.calibrationFocalPx?.toStringAsFixed(0) ?? "-"} px',
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'To calibrate, hold a checkerboard (11 x 8 squares of 25 mm, i.e. 10 x 7 inner corners) '
              '0.5 - 2 m in front of '
              'the mower so both cameras see it, and move it slowly to different positions and angles.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (ros.isCalibrated)
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final message = await ros.restartCalibration();
                if (context.mounted) {
                  _showMessage(context, message);
                }
              },
              child: const Text('Recalibrate'),
            ),
        ],
      ),
    );
  }
}
