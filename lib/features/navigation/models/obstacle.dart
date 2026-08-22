import 'package:flutter/material.dart';

enum ObstaclePosition { left, center, right }

class DetectedObstacle {
  final Rect boundingBox;
  final String? label;
  final double confidence;

  const DetectedObstacle({
    required this.boundingBox,
    this.label,
    this.confidence = 0,
  });

  ObstaclePosition positionIn(Size frameSize) {
    if (frameSize.width <= 0) return ObstaclePosition.center;
    final centerX = boundingBox.left + boundingBox.width / 2;
    final third = frameSize.width / 3;
    if (centerX < third) return ObstaclePosition.left;
    if (centerX > third * 2) return ObstaclePosition.right;
    return ObstaclePosition.center;
  }

  double proximityIn(Size frameSize) {
    if (frameSize.height <= 0) return 0;
    return (boundingBox.height / frameSize.height).clamp(0.0, 1.0);
  }

  bool isDangerIn(Size frameSize, {double proximityThreshold = 0.35}) {
    return positionIn(frameSize) == ObstaclePosition.center &&
        proximityIn(frameSize) >= proximityThreshold;
  }
}

String positionLabel(ObstaclePosition position) {
  switch (position) {
    case ObstaclePosition.left:
      return 'a tu izquierda';
    case ObstaclePosition.right:
      return 'a tu derecha';
    case ObstaclePosition.center:
      return 'justo adelante';
  }
}

DetectedObstacle? closestObstacle(List<DetectedObstacle> obstacles, Size frameSize) {
  DetectedObstacle? closest;
  double bestProximity = -1;
  for (final o in obstacles) {
    final p = o.proximityIn(frameSize);
    if (p > bestProximity) {
      bestProximity = p;
      closest = o;
    }
  }
  return closest;
}

bool anyDanger(List<DetectedObstacle> obstacles, Size frameSize, {double proximityThreshold = 0.35}) {
  return obstacles.any((o) => o.isDangerIn(frameSize, proximityThreshold: proximityThreshold));
}

String buildSurroundingsNarration(List<String> labels) {
  final unique = labels.toSet().take(3).toList();
  if (unique.isEmpty) return '';
  if (unique.length == 1) return 'Cerca de vos hay ${unique.first}.';
  return 'Cerca de vos hay ${unique.sublist(0, unique.length - 1).join(', ')} y ${unique.last}.';
}
