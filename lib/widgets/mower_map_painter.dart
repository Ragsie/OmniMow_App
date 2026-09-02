import 'package:flutter/material.dart';

class MowerMapPainter extends CustomPainter {
  final List<Offset> path;
  final Offset currentRobotPos;

  MowerMapPainter({required this.path, required this.currentRobotPos});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Definer pensler til tegning
    final paintGrassArea = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.fill;

    final paintPath = Paint()
      ..color = Colors.lightGreenAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintRobot = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    // 2. Tegn selve plæne-området (Baggrund)
    final rect = Rect.fromLTWH(20, 20, size.width - 40, size.height - 40);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)), paintGrassArea);

    // 3. Tegn køresporet (Historik over kørte punkter)
    if (path.length > 1) {
      final pathPoints = Path();
      pathPoints.moveTo(path.first.dx, path.first.dy);
      for (var i = 1; i < path.length; i++) {
        pathPoints.lineTo(path[i].dx, path[i].dy);
      }
      canvas.drawPath(pathPoints, paintPath);
    }

    // 4. Tegn robotten som en rød lysende prik
    canvas.drawCircle(currentRobotPos, 8.0, paintRobot);
  }

  @override
  bool shouldRepaint(covariant MowerMapPainter oldDelegate) {
    return oldDelegate.path != path || oldDelegate.currentRobotPos != currentRobotPos;
  }
}