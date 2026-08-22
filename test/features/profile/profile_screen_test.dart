import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/routes/app_routes.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/core/services/navigation_service.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';
import 'package:pathar_fe/features/profile/screens/profile_screen.dart';

class MockAuthService extends Mock implements AuthService {}

class MockNavigationService extends Mock implements NavigationService {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockAuthService authService;
  late MockNavigationService navService;
  late MockDio placesDio;

  setUpAll(() {
    registerFallbackValue(Options());
    dotenv.loadFromString(envString: 'API_URL=http://127.0.0.1:9');
  });

  setUp(() {
    authService = MockAuthService();
    navService = MockNavigationService();
    placesDio = MockDio();
    when(() => authService.getToken()).thenAnswer((_) async => 'tok123');
    when(() => navService.getHistory()).thenAnswer((_) async => []);
    when(() => placesDio.get('/api/history/places')).thenAnswer(
      (_) async => Response(data: {'places': []}, statusCode: 200, requestOptions: RequestOptions(path: '')),
    );
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      routes: {
        AppRoutes.settings: (_) => const Scaffold(body: Text('Settings')),
        AppRoutes.navigationHistory: (_) => const Scaffold(body: Text('History')),
        '/search': (_) => const Scaffold(body: Text('Search')),
      },
      home: child,
    );
  }

  Widget buildScreen() => ProfileScreen(authService: authService, navService: navService, placesDio: placesDio);

  testWidgets('sin inyectar placesDio, usa un Dio real por defecto', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(ProfileScreen(authService: authService, navService: navService)));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('"+ Añadir" de favoritos navega a busqueda', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    final gesture = find.ancestor(of: find.text('+ Añadir'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(gesture).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('muestra el perfil y las estadisticas', (tester) async {
    when(() => authService.getProfile()).thenAnswer(
      (_) async => {'name': 'Ana', 'email': 'ana@test.com'},
    );
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('ana@test.com'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('muestra un error si falla la carga del perfil', (tester) async {
    when(() => authService.getProfile()).thenThrow('sin conexión');
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('sin conexión'), findsOneWidget);
  });

  testWidgets('lista favoritos y permite borrarlos', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer(
      (_) async => [
        {'id': 'f1', 'name': 'Biblioteca', 'address': 'Campus'},
      ],
    );
    when(() => authService.deleteFavorite('f1')).thenAnswer((_) async {});

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca'), findsOneWidget);

    final deleteButton = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    deleteButton.onPressed!();
    await tester.pump();
    await tester.pump();

    verify(() => authService.deleteFavorite('f1')).called(1);
    expect(find.text('Biblioteca'), findsNothing);
  });

  testWidgets('sin favoritos muestra el estado vacio', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Aún no tenés favoritos'), findsOneWidget);
  });

  testWidgets('editar perfil: guardar manda el nombre nuevo', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);
    when(() => authService.updateProfile(name: any(named: 'name'))).thenAnswer((_) async => {});

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ana María');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    verify(() => authService.updateProfile(name: 'Ana María')).called(1);
    expect(find.text('Ana María'), findsOneWidget);
  });

  testWidgets('editar perfil: cancelar no llama a updateProfile', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.updateProfile(name: any(named: 'name')));
  });

  testWidgets('el boton de ajustes navega a settings', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('"Ver todo" de historial navega a navigation history', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Historial de rutas'),
      300,
      scrollable: find.byType(Scrollable),
    );

    final historyRow = find.ancestor(of: find.text('Historial de rutas'), matching: find.byType(Row)).first;
    final gesture = tester.widget<GestureDetector>(
      find.descendant(of: historyRow, matching: find.byType(GestureDetector)),
    );
    gesture.onTap!();
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('con recientes, favoritos e historial poblados muestra todo y permite navegar', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);
    when(() => placesDio.get('/api/history/places')).thenAnswer(
      (_) async => Response(
        data: {
          'places': [
            {'name': 'Cafetería Central', 'address': 'Campus norte', 'time_ago': 'hace 2h'},
          ],
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ),
    );
    when(() => navService.getHistory()).thenAnswer((_) async => [
          NavRoute.fromJson({
            'id': 'r1',
            'destination_name': 'Biblioteca',
            'distance_m': 100.0,
            'distance_text': '100 m',
            'duration_s': 80.0,
            'status': 'finished',
            'points': [
              {'lat': 9.930, 'lng': -84.080},
            ],
            'steps': [
              {'instruction': 'Iniciá', 'turn': 'start', 'lat': 9.930, 'lng': -84.080, 'distance_to_next_m': 100.0},
            ],
          }),
        ]);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cafetería Central'), findsOneWidget);

    final row = find.ancestor(of: find.text('Recientes'), matching: find.byType(Row)).first;
    tester.widget<GestureDetector>(find.descendant(of: row, matching: find.byType(GestureDetector))).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('con historial poblado muestra el conteo de rutas', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);
    when(() => navService.getHistory()).thenAnswer((_) async => [
          NavRoute.fromJson({
            'id': 'r1',
            'destination_name': 'Biblioteca',
            'distance_m': 100.0,
            'distance_text': '100 m',
            'duration_s': 80.0,
            'status': 'finished',
            'points': [
              {'lat': 9.930, 'lng': -84.080},
            ],
            'steps': [
              {'instruction': 'Iniciá', 'turn': 'start', 'lat': 9.930, 'lng': -84.080, 'distance_to_next_m': 100.0},
            ],
          }),
        ]);

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Historial de rutas'), 300, scrollable: find.byType(Scrollable));
    expect(find.textContaining('en tu historial'), findsOneWidget);
  });

  testWidgets('editar perfil: si falla, muestra el error en un snackbar', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer((_) async => []);
    when(() => authService.updateProfile(name: any(named: 'name'))).thenThrow('No se pudo guardar');

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ana María');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo guardar'), findsOneWidget);
  });

  testWidgets('borrar favorito: si falla, muestra el error en un snackbar', (tester) async {
    when(() => authService.getProfile()).thenAnswer((_) async => {'name': 'Ana', 'email': 'ana@test.com'});
    when(() => authService.getFavorites()).thenAnswer(
      (_) async => [
        {'id': 'f1', 'name': 'Biblioteca', 'address': 'Campus'},
      ],
    );
    when(() => authService.deleteFavorite('f1')).thenThrow('No se pudo borrar');

    await tester.pumpWidget(wrap(buildScreen()));
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete_outline));
    deleteButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('No se pudo borrar'), findsOneWidget);
  });
}
