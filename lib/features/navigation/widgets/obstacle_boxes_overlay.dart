import 'package:flutter/material.dart';
import '../models/obstacle.dart';

/// Dibuja las cajas que detectó la IA de percepción sobre el preview de
/// cámara. El sensor trasero suele entregar el frame "acostado" (landscape)
/// aunque el teléfono esté en portrait, por eso se invierten ancho/alto de
/// [frameSize] al escalar contra el tamaño real en pantalla.
class ObstacleBoxesOverlay extends StatelessWidget {
  final List<DetectedObstacle> obstacles;
  final Size frameSize;

  const ObstacleBoxesOverlay({
    super.key,
    required this.obstacles,
    required this.frameSize,
  });

  @override
  Widget build(BuildContext context) {
    if (obstacles.isEmpty || frameSize.width == 0 || frameSize.height == 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _BoxesPainter(obstacles, frameSize),
      ),
    );
  }
}

class _BoxesPainter extends CustomPainter {
  final List<DetectedObstacle> obstacles;
  final Size frameSize;
  _BoxesPainter(this.obstacles, this.frameSize);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / frameSize.height;
    final scaleY = size.height / frameSize.width;

    for (final o in obstacles) {
      final danger = o.isDangerIn(frameSize);
      final color = danger ? Colors.redAccent : Colors.amberAccent;
      final rect = Rect.fromLTRB(
        o.boundingBox.left * scaleX,
        o.boundingBox.top * scaleY,
        o.boundingBox.right * scaleX,
        o.boundingBox.bottom * scaleY,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      final label = o.label ?? (danger ? 'Obstáculo' : 'Objeto');
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: Colors.white, fontSize: 11, backgroundColor: color.withOpacity(0.85)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(rect.left, (rect.top - tp.height).clamp(0, size.height)));
    }
  }

  @override
  bool shouldRepaint(covariant _BoxesPainter oldDelegate) => true;
}
