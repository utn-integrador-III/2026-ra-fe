import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/features/search/screens/search_screen.dart';

import '../../helpers/fake_geolocator.dart';

class MockAuthService extends Mock implements AuthService {}

class MockDio extends Mock implements Dio {}

List<Map<String, dynamic>> _nominatimResult(String name) => [
      {
        'lat': '9.9300',
        'lon': '-84.0800',
        'display_name': '$name, San José, Costa Rica',
        'type': 'cafe',
        'class': 'amenity',
      },
    ];

void main() {
  late MockAuthService authService;
  late MockDio dio;

  setUpAll(() {
    registerFallbackValue(Options());
    dotenv.loadFromString(envString: 'API_URL=http://127.0.0.1:9');
  });

  setUp(() {
    authService = MockAuthService();
    dio = MockDio();
    GeolocatorPlatform.instance = FakeGeolocatorPlatform();
    when(() => authService.getToken()).thenAnswer((_) async => 'tok123');

    when(() => dio.get(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(data: <dynamic>[], statusCode: 200, requestOptions: RequestOptions(path: '')),
    );
    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: <dynamic>[], statusCode: 200, requestOptions: RequestOptions(path: '')),
    );
    when(() => dio.post(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response(data: {}, statusCode: 201, requestOptions: RequestOptions(path: '')),
    );
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      routes: {
        '/navigation': (_) => const Scaffold(body: Text('Navigation')),
        '/home': (_) => const Scaffold(body: Text('Home')),
      },
      home: child,
    );
  }

  Widget buildScreen() => SearchScreen(authService: authService, dio: dio);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
  }

  testWidgets('sin permiso de ubicacion muestra el snackbar correspondiente', (tester) async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(permission: LocationPermission.denied);

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    expect(find.text('Se necesita permiso de ubicación'), findsOneWidget);
  });

  testWidgets('permiso denegado para siempre avisa que hay que habilitarlo en ajustes', (tester) async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(permission: LocationPermission.deniedForever);

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    expect(find.text('Permiso denegado. Habilitalo en Ajustes.'), findsOneWidget);
  });

  testWidgets('con ubicacion resuelta muestra el mapa y las categorias', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    expect(find.text('Categorías'), findsOneWidget);
    expect(find.text('Cafés'), findsOneWidget);
    expect(find.text('Comida'), findsOneWidget);
  });

  testWidgets('buscar texto muestra la seccion de resultados', (tester) async {
    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Biblioteca Central'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'biblio');
    await settle(tester);

    expect(find.textContaining('resultados'), findsOneWidget);
    expect(find.text('Categorías'), findsNothing);
  });

  testWidgets('buscar con menos de 3 caracteres no dispara la busqueda', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'bi');
    await settle(tester);

    expect(find.text('Categorías'), findsOneWidget);
  });

  testWidgets('el boton de mi ubicacion vuelve a pedir la posicion', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    tester.widget<FloatingActionButton>(find.byType(FloatingActionButton)).onPressed!();
    await settle(tester);

    expect(find.text('Categorías'), findsOneWidget);
  });
}
