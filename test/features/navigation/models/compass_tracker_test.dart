import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/models/compass_tracker.dart';

void main() {
  test('la primera lectura fija el rumbo sin marcar inestabilidad', () {
    final tracker = CompassStabilityTracker();

    tracker.update(90);

    expect(tracker.headingDeg, closeTo(90, 0.01));
    expect(tracker.unstable, isFalse);
  });

  test('lecturas estables y cercanas no marcan inestabilidad', () {
    final tracker = CompassStabilityTracker();

    for (final heading in [10.0, 12.0, 9.0, 11.0, 10.0]) {
      tracker.update(heading, accuracyDeg: 15);
    }

    expect(tracker.unstable, isFalse);
  });

  test('saltos bruscos y repetidos acumulan inestabilidad hasta superar el umbral', () {
    final tracker = CompassStabilityTracker();

    tracker.update(0);
    expect(tracker.unstable, isFalse);

    for (final heading in [90.0, 180.0, 270.0, 0.0, 90.0]) {
      tracker.update(heading);
    }
    expect(tracker.unstable, isFalse, reason: 'con 5 saltos (score=5) todavía no debería marcar inestable');

    tracker.update(180);
    expect(tracker.unstable, isTrue, reason: 'el sexto salto lleva el score a 6, el umbral');
  });

  test('lecturas estables intercaladas bajan el puntaje de inestabilidad', () {
    final tracker = CompassStabilityTracker();
    tracker.update(0);
    for (final heading in [90.0, 180.0, 270.0, 0.0, 90.0, 180.0]) {
      tracker.update(heading);
    }
    expect(tracker.unstable, isTrue);

    // Lecturas estables (sin saltos >40°) van bajando el puntaje 0.5 cada
    // vez; hacen falta varias para volver a quedar por debajo del umbral.
    for (var i = 0; i < 3; i++) {
      tracker.update(180);
    }
    expect(tracker.unstable, isFalse);
  });

  test('una precision de sensor baja marca inestabilidad aunque no haya saltos', () {
    final tracker = CompassStabilityTracker();

    tracker.update(45, accuracyDeg: 45);

    expect(tracker.unstable, isTrue);
  });

  test('precision alta o desconocida no marca inestabilidad por si sola', () {
    final tracker = CompassStabilityTracker();

    tracker.update(45, accuracyDeg: 15);
    expect(tracker.unstable, isFalse);

    tracker.update(46);
    expect(tracker.unstable, isFalse);
  });

  test('el rumbo suavizado converge hacia lecturas repetidas', () {
    final tracker = CompassStabilityTracker();

    for (var i = 0; i < 20; i++) {
      tracker.update(200);
    }

    expect(tracker.headingDeg, closeTo(200, 0.5));
  });

  test('el suavizado cruza el limite 0/360 sin saltar a un valor intermedio erroneo', () {
    final tracker = CompassStabilityTracker();
    tracker.update(350);
    tracker.update(10);

    // El promedio circular correcto ronda 0/360 (por ej. 359.x o 0.x), no
    // el promedio aritmético ingenuo (180) que daría un promedio directo.
    final normalized = tracker.headingDeg > 180 ? tracker.headingDeg - 360 : tracker.headingDeg;
    expect(normalized.abs(), lessThan(30));
  });
}
