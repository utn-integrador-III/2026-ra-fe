import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_models.dart';

/// La "línea azul en el suelo": una alfombra que se angosta hacia el
/// horizonte, proyectada con el mismo truco de brújula que la flecha
/// (no es anclaje 3D real, pero da la sensación de un camino pintado).
class ArPathOverlay extends StatelessWidget {
  final double currentLat;
  final double currentLng;
  final double deviceHeadingDeg;
  final List<RoutePoint> pathPoints; // próximos waypoints, en orden
  final double fovDeg;
  final double maxLookaheadM;
  final bool danger; // la IA de percepción detectó un obstáculo en el tramo

  const ArPathOverlay({
    super.key,
    required this.currentLat,
    required this.currentLng,
    required this.deviceHeadingDeg,
    required this.pathPoints,
    this.fovDeg = 60,
    this.maxLookaheadM = 35,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final halfFov = fovDeg / 2;
        final horizonY = size.height * 0.34;
        final groundY = size.height * 0.98;

        final screenPoints = <Offset>[Offset(size.width / 2, groundY)];

        for (final p in pathPoints.take(3)) {
          final dist = Geolocator.distanceBetween(currentLat, currentLng, p.lat, p.lng);
          final bearing = Geolocator.bearingBetween(currentLat, currentLng, p.lat, p.lng);
          double rel = (bearing - deviceHeadingDeg) % 360;
          if (rel > 180) rel -= 360;
          if (rel < -180) rel += 360;

          final t = (dist / maxLookaheadM).clamp(0.0, 1.0);
          final x = size.width / 2 +
              (rel.clamp(-halfFov, halfFov) / halfFov) * (size.width / 2 - 20);
          final y = groundY - t * (groundY - horizonY);
          screenPoints.add(Offset(x, y));
        }

        if (screenPoints.length < 2) return const SizedBox.shrink();

        return CustomPaint(size: size, painter: _CarpetPainter(screenPoints, danger: danger));
      },
    );
  }
}

class _CarpetPainter extends CustomPainter {
  final List<Offset> points;
  final bool danger;
  _CarpetPainter(this.points, {this.danger = false});

  @override
  void paint(Canvas canvas, Size size) {
    final left = <Offset>[];
    final right = <Offset>[];

    for (int i = 0; i < points.length; i++) {
      final t = i / (points.length - 1);
      final halfWidth = 50 * (1 - t) + 8;
      final dir = i == points.length - 1
          ? points[i] - points[i - 1]
          : points[i + 1] - points[i];
      final len = dir.distance == 0 ? 1 : dir.distance;
      final normal = Offset(-dir.dy / len, dir.dx / len);
      left.add(points[i] + normal * halfWidth);
      right.add(points[i] - normal * halfWidth);
    }

    final fillPaint = Paint()
      ..color = (danger ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)).withOpacity(0.55)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPath = Path()..addPolygon([...left, ...right.reversed], true);
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(Path()..addPolygon(left, false), borderPaint);
    canvas.drawPath(Path()..addPolygon(right, false), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CarpetPainter oldDelegate) => true;
}
