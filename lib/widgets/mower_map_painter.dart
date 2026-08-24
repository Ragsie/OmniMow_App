import 'dart:math' as math;
import 'package:flutter/material.dart';

class MowerMapPainter extends CustomPainter {
  final List<Offset> pathPoints; // History of points traveled by the robot
  final Offset currentPosition; // Robot's current position (x, y in meters/pixels)
  final double robotHeading;    // Robot's heading (radians)

  MowerMapPainter({
    required this.pathPoints,
    required this.currentPosition,
    required this.robotHeading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the background (dark grass/garden look)
    final Paint bgPaint = Paint()
      ..color = const Color(0xFF1E272E)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw a subtle grid for a technical, modern look
    final Paint gridPaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.0;
    
    double gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Draw the traveled path (route/history)
    if (pathPoints.length > 1) {
      final Paint pathPaint = Paint()
        ..color = Colors.greenAccent.withValues(alpha: 0.6) // Updated from withOpacity
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      Path path = Path();
      Offset centerOffset = Offset(size.width / 2, size.height / 2);
      
      path.moveTo(centerOffset.dx + pathPoints.first.dx, centerOffset.dy + pathPoints.first.dy);
      for (int i = 1; i < pathPoints.length; i++) {
        path.lineTo(centerOffset.dx + pathPoints[i].dx, centerOffset.dy + pathPoints[i].dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    // 3. Draw the robot as a dot/icon on the map
    final Paint robotPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    Offset robotScreenPos = Offset(
      (size.width / 2) + currentPosition.dx,
      (size.height / 2) + currentPosition.dy,
    );

    // Draw the robot body
    canvas.drawCircle(robotScreenPos, 12.0, robotPaint);

    // Draw a direction arrow in front of the robot
    final Paint arrowPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    Offset frontPoint = Offset(
      robotScreenPos.dx + (20 * math.cos(robotHeading)),
      robotScreenPos.dy + (20 * math.sin(robotHeading)),
    );
    canvas.drawLine(robotScreenPos, frontPoint, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant MowerMapPainter oldDelegate) {
    return oldDelegate.pathPoints != pathPoints ||
        oldDelegate.currentPosition != currentPosition ||
        oldDelegate.robotHeading != robotHeading;
  }
}