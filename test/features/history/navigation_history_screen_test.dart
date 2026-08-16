import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/navigation_service.dart';
import 'package:pathar_fe/features/history/screens/navigation_history_screen.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';

class MockNavigationService extends Mock implements NavigationService {}

NavRoute _route({
  String id = 'r1',
  String? destinationName = 'Biblioteca',
  String status = 'calculated',
  DateTime? createdAt,
}) {
  return NavRoute.fromJson({
    'id': id,
    'destination_name': destinationName,
    'distance_m': 120.0,
    'distance_text': '120 m',
    'duration_s': 90.0,
    'status': status,
    'points': [
      {'lat': 9.930, 'lng': -84.080},
    ],
    'steps': [
      {'instruction': 'Iniciá la ruta', 'turn': 'start', 'lat': 9.930, 'lng': -84.080, 'distance_to_next_m': 120.0},
    ],
    if (createdAt != null) 'created_at': createdAt.toIso8601String(),
  });
}

void main() {
  late MockNavigationService navService;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    navService = MockNavigationService();
  });

  Widget wrap(Widget child) => MaterialApp(home: child);

  testWidgets('muestra el estado vacio si no hay historial', (tester) async {
    when(() => navService.getHistory()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(NavigationHistoryScreen(navService: navService)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Todavía no navegaste ninguna ruta'), findsOneWidget);
  });

  testWidgets('muestra un error si falla la carga', (tester) async {
    when(() => navService.getHistory()).thenThrow('sin conexión');

    await tester.pumpWidget(wrap(NavigationHistoryScreen(navService: navService)));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('sin conexión'), findsOneWidget);
  });

  testWidgets('lista las rutas con su nombre, distancia y estado', (tester) async {
    when(() => navService.getHistory()).thenAnswer((_) async => [
          _route(id: 'r1', destinationName: 'Biblioteca', status: 'finished', createdAt: DateTime(2026, 3, 5, 14, 30)),
          _route(id: 'r2', destinationName: null, status: 'cancelled'),
          _route(id: 'r3', destinationName: 'Cafetería', status: 'active'),
          _route(id: 'r4', destinationName: 'Gimnasio', status: 'raro-desconocido'),
        ]);

    await tester.pumpWidget(wrap(NavigationHistoryScreen(navService: navService)));
    await tester.pump();
    await tester.pump();

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Destino sin nombre'), findsOneWidget);
    expect(find.text('Finalizada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('Calculada'), findsOneWidget);
    expect(find.text('05/03/2026 14:30'), findsOneWidget);
    expect(find.text('120 m'), findsWidgets);
  });
}
