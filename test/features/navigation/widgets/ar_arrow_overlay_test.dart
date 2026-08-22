import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/widgets/ar_arrow_overlay.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: SizedBox(width: 400, height: 800, child: child),
    );

void main() {
  testWidgets('llegaste muestra la bandera en vez de la flecha', (tester) async {
    await tester.pumpWidget(_wrap(const ArArrowOverlay(relativeBearingDeg: 0, arrived: true)));

    expect(find.byIcon(Icons.flag_circle), findsOneWidget);
    expect(find.byIcon(Icons.navigation), findsNothing);
  });

  testWidgets('alineado muestra la flecha azul sin chevron', (tester) async {
    await tester.pumpWidget(_wrap(const ArArrowOverlay(relativeBearingDeg: 0)));

    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('fuera de rango a la derecha muestra el chevron derecho', (tester) async {
    await tester.pumpWidget(_wrap(const ArArrowOverlay(relativeBearingDeg: 90)));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('fuera de rango a la izquierda muestra el chevron izquierdo', (tester) async {
    await tester.pumpWidget(_wrap(const ArArrowOverlay(relativeBearingDeg: -90)));

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
  });
}
