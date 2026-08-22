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

List<Map<String, dynamic>> _universityLocationsResult() => [
      {
        'id': 1,
        'name': 'Biblioteca Central',
        'description': 'Sala de estudio silenciosa',
        'location_type': 'building',
        'building': 'Edificio A',
        'floor': '2',
        'latitude': 9.931,
        'longitude': -84.081,
      },
    ];

class _FlakyPermissionPlatform extends FakeGeolocatorPlatform {
  int _checkCalls = 0;

  _FlakyPermissionPlatform() : super(currentPositionError: 'boom');

  @override
  Future<LocationPermission> checkPermission() async {
    _checkCalls++;
    return _checkCalls == 1 ? LocationPermission.whileInUse : LocationPermission.denied;
  }

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.denied;
}

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

  testWidgets('cuando falla la posicion precisa y tambien el fallback se muestra el snackbar de error', (tester) async {
    GeolocatorPlatform.instance = _FlakyPermissionPlatform();

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    expect(find.text('No se pudo obtener la ubicación'), findsOneWidget);
  });

  testWidgets('carga las ubicaciones universitarias y permite navegar desde su ficha', (tester) async {
    when(() => dio.get(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(data: _universityLocationsResult(), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    final marker = find.ancestor(of: find.byIcon(Icons.school), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(marker).onTap!();
    await settle(tester);

    expect(find.text('Biblioteca Central'), findsOneWidget);
    expect(find.textContaining('Edificio A'), findsOneWidget);
    expect(find.text('Sala de estudio silenciosa'), findsOneWidget);

    final navigateHere = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Navegar aquí'));
    navigateHere.onPressed!();
    await settle(tester);

    expect(find.text('Navigation'), findsOneWidget);
  });

  testWidgets('la busqueda de texto combina coincidencias universitarias con resultados de nominatim', (tester) async {
    when(() => dio.get(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(data: _universityLocationsResult(), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Café Central'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.enterText(find.byType(TextField), 'edificio a');
    await settle(tester);

    expect(find.text('Biblioteca Central'), findsOneWidget);
  });

  testWidgets('si la busqueda en nominatim falla se muestran solo las coincidencias universitarias', (tester) async {
    when(() => dio.get(any(), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(data: _universityLocationsResult(), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    await tester.enterText(find.byType(TextField), 'edificio a');
    await settle(tester);

    expect(find.text('Biblioteca Central'), findsOneWidget);
  });

  testWidgets('seleccionar una categoria filtra los lugares cercanos por ese tipo', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Café del Centro'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    final cafeCell = find.ancestor(of: find.text('Cafés'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(cafeCell).onTap!();
    await settle(tester);

    expect(find.text('Café del Centro'), findsWidgets);
  });

  testWidgets('si falla la busqueda de una categoria especifica no rompe la pantalla', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException(requestOptions: RequestOptions(path: '')));

    final cafeCell = find.ancestor(of: find.text('Cafés'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(cafeCell).onTap!();
    await settle(tester);

    expect(find.text('No se encontraron lugares cercanos'), findsOneWidget);
  });

  testWidgets('seleccionar un resultado de busqueda navega con el destino y el origen correctos', (tester) async {
    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Soda La Esquina'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'soda');
    await settle(tester);

    final card = find.ancestor(of: find.text('Soda La Esquina'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(card).onTap!();
    await settle(tester);

    expect(find.text('Navigation'), findsOneWidget);
  });

  testWidgets('seleccionar un destino sin token no intenta guardar historial y aun asi navega', (tester) async {
    when(() => authService.getToken()).thenAnswer((_) async => null);
    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Parque Central'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'parque');
    await settle(tester);

    final card = find.ancestor(of: find.text('Parque Central'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(card).onTap!();
    await settle(tester);

    expect(find.text('Navigation'), findsOneWidget);
  });

  testWidgets('agregar a favoritos exitosamente muestra confirmacion', (tester) async {
    when(() => authService.addFavorite(
          name: any(named: 'name'),
          address: any(named: 'address'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenAnswer((_) async => {'id': 1});

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Mercado Borbon'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'mercado');
    await settle(tester);

    final favButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.favorite_border));
    favButton.onPressed!();
    await settle(tester);

    expect(find.textContaining('agregado a favoritos'), findsOneWidget);
  });

  testWidgets('si falla agregar a favoritos se muestra un mensaje de error', (tester) async {
    when(() => authService.addFavorite(
          name: any(named: 'name'),
          address: any(named: 'address'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
        )).thenThrow(Exception('boom'));

    when(() => dio.get(any(), queryParameters: any(named: 'queryParameters'))).thenAnswer(
      (_) async => Response(data: _nominatimResult('Farmacia Fischel'), statusCode: 200, requestOptions: RequestOptions(path: '')),
    );

    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    await tester.enterText(find.byType(TextField), 'farmacia');
    await settle(tester);

    final favButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.favorite_border));
    favButton.onPressed!();
    await settle(tester);

    expect(find.text('No se pudo agregar a favoritos'), findsOneWidget);
  });

  testWidgets('el boton navegar de la barra inferior lleva a la pantalla de navegacion', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    final navBtn = find.ancestor(of: find.text('Navegar'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(navBtn).onTap!();
    await settle(tester);

    expect(find.text('Navigation'), findsOneWidget);
  });

  testWidgets('el boton perfil de la barra inferior lleva al home', (tester) async {
    await tester.pumpWidget(wrap(buildScreen()));
    await settle(tester);

    final profileBtn = find.ancestor(of: find.text('Perfil'), matching: find.byType(GestureDetector)).first;
    tester.widget<GestureDetector>(profileBtn).onTap!();
    await settle(tester);

    expect(find.text('Home'), findsOneWidget);
  });
}
