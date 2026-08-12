import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/core/services/navigation_service.dart';

class MockDio extends Mock implements Dio {}

class MockAuthService extends Mock implements AuthService {}

Map<String, dynamic> _routeJson(String id) => {
      'id': id,
      'destination_name': 'Biblioteca',
      'distance_m': 100.0,
      'distance_text': '100 m',
      'duration_s': 80.0,
      'status': 'calculated',
      'points': [
        {'lat': 9.930, 'lng': -84.080},
        {'lat': 9.931, 'lng': -84.081},
      ],
      'steps': [
        {
          'instruction': 'Iniciá la ruta',
          'turn': 'start',
          'lat': 9.930,
          'lng': -84.080,
          'distance_to_next_m': 100.0,
        },
      ],
    };

void main() {
  late MockDio dio;
  late MockAuthService authService;
  late NavigationService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    authService = MockAuthService();
    service = NavigationService(dio: dio, authService: authService);
    when(() => authService.getToken()).thenAnswer((_) async => 'tok123');
  });

  test('requestRoute manda el body correcto y parsea la respuesta', () async {
    when(() => dio.post('/api/navigation/route',
        data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: _routeJson('route-1'),
        statusCode: 201,
        requestOptions: RequestOptions(path: '/api/navigation/route'),
      ),
    );

    final route = await service.requestRoute(
      originLat: 9.930, originLng: -84.080, destinationLat: 9.931, destinationLng: -84.081,
    );

    expect(route.id, 'route-1');
    expect(route.points, hasLength(2));

    final captured = verify(() => dio.post('/api/navigation/route',
        data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
    expect(captured['origin_lat'], 9.930);
    expect(captured['destination_lng'], -84.081);
  });

  test('startRoute pide el endpoint correcto con el route_id', () async {
    when(() => dio.post('/api/navigation/start',
        data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: _routeJson('route-1'),
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/navigation/start'),
      ),
    );

    final route = await service.startRoute('route-1');
    expect(route.status, 'calculated');
  });

  test('finishRoute pide el endpoint correcto', () async {
    when(() => dio.post('/api/navigation/finish',
        data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: _routeJson('route-1'),
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/navigation/finish'),
      ),
    );

    final route = await service.finishRoute('route-1');
    expect(route.id, 'route-1');
  });

  test('recalculateRoute manda la posicion actual', () async {
    when(() => dio.post('/api/navigation/recalculate',
        data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: _routeJson('route-1'),
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/navigation/recalculate'),
      ),
    );

    final route = await service.recalculateRoute(routeId: 'route-1', currentLat: 9.930, currentLng: -84.080);
    expect(route.id, 'route-1');
  });

  test('requestRoute lanza el detail del backend si no hay ruta posible', () async {
    when(() => dio.post('/api/navigation/route',
        data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/navigation/route'),
        response: Response(
          statusCode: 422,
          data: {'detail': 'No hay un camino caminable entre origen y destino'},
          requestOptions: RequestOptions(path: '/api/navigation/route'),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      () => service.requestRoute(
        originLat: 1, originLng: 1, destinationLat: 2, destinationLng: 2,
      ),
      throwsA('No hay un camino caminable entre origen y destino'),
    );
  });
}
