import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_models.dart';

/// La "línea azul en el suelo": una alfombra que se angosta hacia el
/// horizonte, proyectada con el mismo truco de brújula que la flecha
/// (no es anclaje 3D real, pero da la sensación de un camino pintado).
///
/// La posición vertical usa una proyección de perspectiva real (cámara a
/// [cameraHeightM] del piso, mirando con una inclinación [devicePitchDeg]
/// relativa a como estaba el teléfono al calibrar) en vez de una
/// interpolación fija — así la línea sube/baja en pantalla según hacia
/// dónde apuntás el teléfono, no según una posición de cámara asumida fija.
class ArPathOverlay extends StatelessWidget {
  final double currentLat;
  final double currentLng;
  final double deviceHeadingDeg;
  final double devicePitchDeg; // 0 = como se calibró; positivo = inclinado hacia el piso
  final List<RoutePoint> pathPoints; // próximos waypoints, en orden
  final double fovDeg;
  final double fovVDeg;
  final double cameraHeightM;
  final double maxLookaheadM;
  final bool danger; // la IA de percepción detectó un obstáculo en el tramo

  const ArPathOverlay({
    super.key,
    required this.currentLat,
    required this.currentLng,
    required this.deviceHeadingDeg,
    this.devicePitchDeg = 0,
    required this.pathPoints,
    this.fovDeg = 60,
    this.fovVDeg = 45,
    this.cameraHeightM = 1.3,
    this.maxLookaheadM = 35,
    this.danger = false,
  });

  double _projectY(double distM, Size size) {
    final safeDist = math.max(distM, 0.3);
    // Ángulo al que "mira hacia abajo" un punto del piso a esta distancia,
    // visto desde una cámara a cameraHeightM de altura sobre terreno plano.
    final depressionDeg = math.atan(cameraHeightM / safeDist) * 180 / math.pi;
    // Relativo al eje óptico real de la cámara (que ya mira devicePitchDeg
    // hacia el piso respecto a la calibración).
    final relativeDeg = depressionDeg - devicePitchDeg;
    final halfFovV = fovVDeg / 2;
    final t = (0.5 + relativeDeg / halfFovV * 0.5).clamp(0.0, 1.0);
    return t * size.height;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final halfFov = fovDeg / 2;

        final screenPoints = <Offset>[Offset(size.width / 2, _projectY(0.3, size))];

        for (final p in pathPoints.take(3)) {
          final dist = Geolocator.distanceBetween(currentLat, currentLng, p.lat, p.lng);
          final bearing = Geolocator.bearingBetween(currentLat, currentLng, p.lat, p.lng);
          double rel = (bearing - deviceHeadingDeg) % 360;
          if (rel > 180) rel -= 360;
          if (rel < -180) rel += 360;

          final x = size.width / 2 +
              (rel.clamp(-halfFov, halfFov) / halfFov) * (size.width / 2 - 20);
          final y = _projectY(dist, size);
          screenPoints.add(Offset(x, y));
        }

        if (screenPoints.length < 2) return const SizedBox.shrink();

        // Los waypoints reales pueden estar a decenas de metros entre sí,
        // así que unirlos con líneas rectas deja un quiebre brusco en cada
        // giro. Suavizarlos (Chaikin, 2 pasadas) da una curva natural sin
        // mover los extremos (tus pies y el punto más lejano).
        final smoothed = screenPoints.length >= 3
            ? _chaikinSmooth(_chaikinSmooth(screenPoints))
            : screenPoints;

        return CustomPaint(size: size, painter: _CarpetPainter(smoothed, danger: danger));
      },
    );
  }

  List<Offset> _chaikinSmooth(List<Offset> points) {
    if (points.length < 3) return points;
    final result = <Offset>[points.first];
    for (int i = 0; i < points.length - 1; i++) {
      result.add(Offset.lerp(points[i], points[i + 1], 0.25)!);
      result.add(Offset.lerp(points[i], points[i + 1], 0.75)!);
    }
    result.add(points.last);
    return result;
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
