import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';
import 'package:pathar_fe/features/navigation/widgets/ar_path_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: SizedBox(
        width: 400,
        height: 800,
        child: child,
      ),
    );

void main() {
  testWidgets('sin waypoints no dibuja nada', (tester) async {
    await tester.pumpWidget(_wrap(const ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 0,
      pathPoints: [],
    )));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('con un waypoint dibuja la alfombra sin suavizado', (tester) async {
    await tester.pumpWidget(_wrap(ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 0,
      pathPoints: const [RoutePoint(lat: 9.9305, lng: -84.080)],
    )));

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('con varios waypoints aplica el suavizado de curva', (tester) async {
    await tester.pumpWidget(_wrap(ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 45,
      devicePitchDeg: 10,
      pathPoints: const [
        RoutePoint(lat: 9.9302, lng: -84.0800),
        RoutePoint(lat: 9.9305, lng: -84.0795),
        RoutePoint(lat: 9.9308, lng: -84.0790),
      ],
    )));

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('al reconstruir con otros datos vuelve a pintar sin error', (tester) async {
    await tester.pumpWidget(_wrap(ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 0,
      pathPoints: const [RoutePoint(lat: 9.9302, lng: -84.0800)],
    )));
    await tester.pump();

    await tester.pumpWidget(_wrap(ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 20,
      danger: true,
      pathPoints: const [RoutePoint(lat: 9.9303, lng: -84.0801)],
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('en modo peligro se pinta de otro color sin tirar error', (tester) async {
    await tester.pumpWidget(_wrap(ArPathOverlay(
      currentLat: 9.930,
      currentLng: -84.080,
      deviceHeadingDeg: 180,
      danger: true,
      pathPoints: const [
        RoutePoint(lat: 9.9295, lng: -84.080),
        RoutePoint(lat: 9.9290, lng: -84.080),
      ],
    )));

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
