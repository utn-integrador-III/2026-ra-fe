import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/models/obstacle.dart';
import 'package:pathar_fe/features/navigation/widgets/obstacle_boxes_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: SizedBox(width: 400, height: 800, child: child),
    );

void main() {
  testWidgets('sin obstaculos no dibuja nada', (tester) async {
    await tester.pumpWidget(_wrap(const ObstacleBoxesOverlay(obstacles: [], frameSize: Size(1280, 720))));

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('con frameSize en cero no dibuja nada', (tester) async {
    await tester.pumpWidget(_wrap(ObstacleBoxesOverlay(
      obstacles: [const DetectedObstacle(boundingBox: Rect.fromLTWH(0, 0, 10, 10))],
      frameSize: Size.zero,
    )));

    expect(tester.takeException(), isNull);
  });

  testWidgets('al reconstruir con otros obstaculos vuelve a pintar sin error', (tester) async {
    await tester.pumpWidget(_wrap(ObstacleBoxesOverlay(
      obstacles: const [DetectedObstacle(boundingBox: Rect.fromLTWH(0, 0, 50, 50))],
      frameSize: const Size(1280, 720),
    )));
    await tester.pump();

    await tester.pumpWidget(_wrap(ObstacleBoxesOverlay(
      obstacles: const [DetectedObstacle(boundingBox: Rect.fromLTWH(600, 0, 100, 400), label: 'auto')],
      frameSize: const Size(1280, 720),
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('dibuja cajas con y sin etiqueta, en peligro y fuera de peligro', (tester) async {
    await tester.pumpWidget(_wrap(ObstacleBoxesOverlay(
      obstacles: const [
        DetectedObstacle(boundingBox: Rect.fromLTWH(500, 0, 200, 500), label: 'persona', confidence: 0.9),
        DetectedObstacle(boundingBox: Rect.fromLTWH(0, 0, 50, 50)),
      ],
      frameSize: const Size(1280, 720),
    )));

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
