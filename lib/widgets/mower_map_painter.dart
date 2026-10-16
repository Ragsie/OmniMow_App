import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the mower's SLAM map: lawn zones, route history, dock and the robot.
///
/// All inputs are in metres on the mower's map (x forward from the dock, y to the left,
/// the charging station is the origin). The view is scaled so everything fits the canvas.
class MowerMapPainter extends CustomPainter {
  final List<Offset> path;
  final List<List<Offset>> zones;
  final Offset robotPos;
  final double robotYaw;
  final bool hasPose;
  final bool isDark;

  MowerMapPainter({
    required this.path,
    required this.zones,
    required this.robotPos,
    required this.robotYaw,
    required this.hasPose,
    required this.isDark,
  });

  /// Draws the map layers in back-to-front order on the supplied canvas.
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Infinite Grid Background (Seamless technical blueprint lines)
    final gridPaint = Paint()
      ..color = isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.black.withOpacity(0.03)
      ..strokeWidth = 1.0;

    const double gridSpacing = 20.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. World (metres) -> canvas: fit zones, route, dock and robot, at least 10 m across
    double minX = 0, maxX = 0, minY = 0, maxY = 0;
    void include(Offset p) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    for (final zone in zones) {
      zone.forEach(include);
    }
    path.forEach(include);
    if (hasPose) {
      include(robotPos);
    }
    final double span = math.max(10.0, math.max(maxX - minX, maxY - minY));
    final double scale = (math.min(size.width, size.height) - 24.0) / span;
    final Offset worldCentre = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final Offset canvasCentre = Offset(size.width / 2, size.height / 2);
    // Canvas y points down, map y points up
    Offset toCanvas(Offset p) => Offset(
      canvasCentre.dx + (p.dx - worldCentre.dx) * scale,
      canvasCentre.dy - (p.dy - worldCentre.dy) * scale,
    );

    // 3. Lawn zones recorded by the mower
    final zoneColor = isDark
        ? const Color(0xFF00C853)
        : const Color(0xFF4CAF50);
    final zoneFill = Paint()
      ..color = zoneColor.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;
    final zoneLine = Paint()
      ..color = zoneColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    for (final zone in zones) {
      if (zone.length < 3) continue;
      final zonePath = Path()..addPolygon(zone.map(toCanvas).toList(), true);
      canvas.drawPath(zonePath, zoneFill);
      canvas.drawPath(zonePath, zoneLine);
    }

    // 4. Charging dock station at the map origin
    final dockPos = toCanvas(Offset.zero);
    final dockBasePaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dockPos, 10.0, dockBasePaint);

    final dockInnerPaint = Paint()
      ..color = isDark ? const Color(0xFF0288D1) : Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dockPos, 5.0, dockInnerPaint);

    // 5. Draw Mowed Path (Glowing green track line)
    if (path.length > 1) {
      final pathPoints = Path();
      final first = toCanvas(path.first);
      pathPoints.moveTo(first.dx, first.dy);
      for (var i = 1; i < path.length; i++) {
        final p = toCanvas(path[i]);
        pathPoints.lineTo(p.dx, p.dy);
      }

      final paintPath = Paint()
        ..color = isDark
            ? const Color(0xFF00C853).withOpacity(0.7)
            : const Color(0xFF4CAF50).withOpacity(0.8)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(pathPoints, paintPath);
    }

    // 6. Draw Robot Beacon (Glowing white pearl with glowing radar halo)
    if (!hasPose) return;
    final robot = toCanvas(robotPos);

    final radarPaint = Paint()
      ..color = isDark
          ? const Color(0xFF00C853).withOpacity(0.15)
          : const Color(0xFF4CAF50).withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robot, 22.0, radarPaint);

    final radarRingPaint = Paint()
      ..color = isDark
          ? const Color(0xFF00C853).withOpacity(0.4)
          : const Color(0xFF4CAF50).withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(robot, 22.0, radarRingPaint);

    final coreShadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robot + const Offset(0, 2), 7.0, coreShadowPaint);

    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(robot, 7.0, corePaint);

    // Heading arrow from the mower's yaw (map y up = canvas y down, so the angle flips)
    final double angle = -robotYaw;
    const double arrowSize = 5.0;
    final arrowPath = Path()
      ..moveTo(
        robot.dx + arrowSize * 1.5 * math.cos(angle),
        robot.dy + arrowSize * 1.5 * math.sin(angle),
      )
      ..lineTo(
        robot.dx + arrowSize * math.cos(angle + 5 * math.pi / 6),
        robot.dy + arrowSize * math.sin(angle + 5 * math.pi / 6),
      )
      ..lineTo(
        robot.dx + arrowSize * math.cos(angle - 5 * math.pi / 6),
        robot.dy + arrowSize * math.sin(angle - 5 * math.pi / 6),
      )
      ..close();
    final arrowPaint = Paint()
      ..color = zoneColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);
  }

  /// Repaints on every telemetry update (the route list is mutated in place).
  @override
  bool shouldRepaint(covariant MowerMapPainter oldDelegate) => true;
}
