import 'dart:math' as math;

/// Suaviza las lecturas crudas de la brújula (vía seno/coseno, no promedio
/// directo de grados) para que la flecha AR no tiemble con cada lectura
/// ruidosa del magnetómetro, y detecta cuándo esas lecturas dejaron de ser
/// confiables.
///
/// Hay dos formas independientes de detectar una brújula poco confiable:
/// - Saltos bruscos y repetidos entre lecturas consecutivas (`_instabilityScore`):
///   agarra interferencia intermitente o un giro real muy errático.
/// - La precisión que reporta el propio sensor de rotación del OS
///   (SENSOR_STATUS_ACCURACY_*): agarra el caso de una lectura ESTABLE pero
///   con un sesgo grande y constante — típico de tener el celular cerca de
///   una laptop u otro objeto metálico/electrónico — que el chequeo de
///   saltos no puede ver porque, lectura a lectura, no "salta".
class CompassStabilityTracker {
  double _smSinH = 0;
  double _smCosH = 1;
  bool _headingInit = false;
  double? _lastRawHeading;
  double _instabilityScore = 0;
  double? _accuracyDeg;

  double get headingDeg => (math.atan2(_smSinH, _smCosH) * 180 / math.pi + 360) % 360;

  bool get unstable => _instabilityScore >= 6 || (_accuracyDeg ?? 0) >= 30;

  /// [newHeadingDeg]: 0-360, 0=norte. [accuracyDeg]: SENSOR_STATUS_ACCURACY_*
  /// (15=alta, 30=media, 45=baja) o null/negativo si el sensor no la reporta.
  void update(double newHeadingDeg, {double? accuracyDeg}) {
    _accuracyDeg = accuracyDeg;

    if (_lastRawHeading != null) {
      double jump = (newHeadingDeg - _lastRawHeading!) % 360;
      if (jump > 180) jump -= 360;
      if (jump < -180) jump += 360;
      // Un giro real de la persona también puede saltar así, pero si pasa
      // seguido (varias lecturas seguidas saltando fuerte) es más probable
      // que sea interferencia magnética que un giro genuino y sostenido.
      _instabilityScore += jump.abs() > 40 ? 1 : -0.5;
      _instabilityScore = _instabilityScore.clamp(0, 10);
    }
    _lastRawHeading = newHeadingDeg;

    final rad = newHeadingDeg * math.pi / 180;
    const alpha = 0.25;
    if (!_headingInit) {
      _smSinH = math.sin(rad);
      _smCosH = math.cos(rad);
      _headingInit = true;
    } else {
      _smSinH = _smSinH * (1 - alpha) + math.sin(rad) * alpha;
      _smCosH = _smCosH * (1 - alpha) + math.cos(rad) * alpha;
    }
  }
}
