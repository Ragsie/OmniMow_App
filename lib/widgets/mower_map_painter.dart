import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the mower map, route history, dock marker, and current robot beacon.
class MowerMapPainter extends CustomPainter {
  final List<Offset> path;
  final Offset currentRobotPos;
  final bool isDark;

  MowerMapPainter({
    required this.path,
    required this.currentRobotPos,
    required this.isDark,
  });

  /// Draws the map layers in back-to-front order on the supplied canvas.
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

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

    // 3. Draw charging dock station reference point at the center
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final dockPos = Offset(centerX, centerY);
    final dockBasePaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dockPos, 10.0, dockBasePaint);

    final dockInnerPaint = Paint()
      ..color = isDark ? const Color(0xFF0288D1) : Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(dockPos, 5.0, dockInnerPaint);

    // 4. Draw Mowed Path (Glowing green track line)
    if (path.length > 1) {
      final pathPoints = Path();
      pathPoints.moveTo(path.first.dx, path.first.dy);
      for (var i = 1; i < path.length; i++) {
        pathPoints.lineTo(path[i].dx, path[i].dy);
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

    // 5. Draw Robot Beacon (Glowing white pearl with glowing radar halo)
    // Only draw if the robot is active and not at origin (0, 0)
    if (currentRobotPos != Offset.zero) {
      // Draw radar pulse outer wave
      final radarPaint = Paint()
        ..color = isDark
            ? const Color(0xFF00C853).withOpacity(0.15)
            : const Color(0xFF4CAF50).withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentRobotPos, 22.0, radarPaint);

      final radarRingPaint = Paint()
        ..color = isDark
            ? const Color(0xFF00C853).withOpacity(0.4)
            : const Color(0xFF4CAF50).withOpacity(0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(currentRobotPos, 22.0, radarRingPaint);

      // Draw white glowing inner core
      final coreShadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        currentRobotPos + const Offset(0, 2),
        7.0,
        coreShadowPaint,
      );

      final corePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(currentRobotPos, 7.0, corePaint);

      // Dynamic direction arrow (Heading indicator)
      if (path.length > 1) {
        // Calculate angle based on the last segment
        final Offset lastSegment = currentRobotPos - path[path.length - 2];
        final double angle = math.atan2(lastSegment.dy, lastSegment.dx);

        // Draw a small directional pointer triangle on top of the core
        final arrowPath = Path();
        const double arrowSize = 5.0;

        // Vertices of the directional triangle rotated by heading angle
        final double p1x =
            currentRobotPos.dx + (arrowSize * 1.5 * math.cos(angle));
        final double p1y =
            currentRobotPos.dy + (arrowSize * 1.5 * math.sin(angle));

        final double p2x =
            currentRobotPos.dx +
            (arrowSize * math.cos(angle + (5 * math.pi / 6)));
        final double p2y =
            currentRobotPos.dy +
            (arrowSize * math.sin(angle + (5 * math.pi / 6)));

        final double p3x =
            currentRobotPos.dx +
            (arrowSize * math.cos(angle - (5 * math.pi / 6)));
        final double p3y =
            currentRobotPos.dy +
            (arrowSize * math.sin(angle - (5 * math.pi / 6)));

        arrowPath.moveTo(p1x, p1y);
        arrowPath.lineTo(p2x, p2y);
        arrowPath.lineTo(p3x, p3y);
        arrowPath.close();

        final arrowPaint = Paint()
          ..color = isDark ? const Color(0xFF00C853) : const Color(0xFF4CAF50)
          ..style = PaintingStyle.fill;
        canvas.drawPath(arrowPath, arrowPaint);
      } else {
        // Fallback simple center emerald dot if stationary
        final dotPaint = Paint()
          ..color = isDark ? const Color(0xFF00C853) : const Color(0xFF4CAF50)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(currentRobotPos, 4.0, dotPaint);
      }
    }
  }

  /// Repaints when the route, robot position, or theme changes.
  @override
  bool shouldRepaint(covariant MowerMapPainter oldDelegate) {
    return oldDelegate.path != path ||
        oldDelegate.currentRobotPos != currentRobotPos ||
        oldDelegate.isDark != isDark;
  }
}
