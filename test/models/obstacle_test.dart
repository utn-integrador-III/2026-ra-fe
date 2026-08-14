import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/models/obstacle.dart';

void main() {
  const frameSize = Size(1280, 720);

  group('positionIn', () {
    test('objeto en el tercio izquierdo', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 100));
      expect(o.positionIn(frameSize), ObstaclePosition.left);
    });

    test('objeto en el tercio derecho', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(1100, 0, 100, 100));
      expect(o.positionIn(frameSize), ObstaclePosition.right);
    });

    test('objeto centrado', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 100));
      expect(o.positionIn(frameSize), ObstaclePosition.center);
    });
  });

  group('proximityIn', () {
    test('a mayor altura relativa del cuadro, mayor proximidad', () {
      final near = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 500));
      final far = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 50));
      expect(near.proximityIn(frameSize), greaterThan(far.proximityIn(frameSize)));
    });

    test('nunca supera 1.0', () {
      final huge = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 5000));
      expect(huge.proximityIn(frameSize), 1.0);
    });
  });

  group('isDangerIn', () {
    test('centrado y grande es peligro', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 400));
      expect(o.isDangerIn(frameSize), isTrue);
    });

    test('centrado pero lejos (chico) no es peligro', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 50));
      expect(o.isDangerIn(frameSize), isFalse);
    });

    test('grande pero a un costado no es peligro', () {
      final o = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 400));
      expect(o.isDangerIn(frameSize), isFalse);
    });
  });

  group('closestObstacle', () {
    test('devuelve el de mayor proximidad', () {
      final near = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 500), label: 'cerca');
      final far = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 50), label: 'lejos');
      final result = closestObstacle([far, near], frameSize);
      expect(result?.label, 'cerca');
    });

    test('lista vacía devuelve null', () {
      expect(closestObstacle([], frameSize), isNull);
    });
  });

  group('anyDanger', () {
    test('true si al menos uno está en peligro', () {
      final safe = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 50));
      final danger = DetectedObstacle(boundingBox: const Rect.fromLTWH(600, 0, 100, 400));
      expect(anyDanger([safe, danger], frameSize), isTrue);
    });

    test('false si ninguno está en peligro', () {
      final safe = DetectedObstacle(boundingBox: const Rect.fromLTWH(0, 0, 100, 50));
      expect(anyDanger([safe], frameSize), isFalse);
    });
  });

  group('positionLabel', () {
    test('mapea cada posición a su frase', () {
      expect(positionLabel(ObstaclePosition.left), 'a tu izquierda');
      expect(positionLabel(ObstaclePosition.right), 'a tu derecha');
      expect(positionLabel(ObstaclePosition.center), 'justo adelante');
    });
  });

  group('buildSurroundingsNarration', () {
    test('lista vacía da texto vacío', () {
      expect(buildSurroundingsNarration([]), '');
    });

    test('una sola etiqueta', () {
      expect(buildSurroundingsNarration(['persona']), 'Cerca de vos hay persona.');
    });

    test('varias etiquetas se unen con "y"', () {
      expect(buildSurroundingsNarration(['persona', 'bicicleta']), 'Cerca de vos hay persona y bicicleta.');
    });

    test('descarta duplicados y limita a 3', () {
      final result = buildSurroundingsNarration(['persona', 'persona', 'silla', 'planta', 'auto']);
      expect(result, isNot(contains('auto')));
    });
  });
}
