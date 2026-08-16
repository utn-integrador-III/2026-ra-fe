import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
    dotenv.loadFromString(envString: 'API_URL=http://127.0.0.1:9');
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

  test('getHistory devuelve la lista de rutas parseadas', () async {
    when(() => dio.get('/api/navigation/history', options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: [_routeJson('route-1'), _routeJson('route-2')],
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/navigation/history'),
      ),
    );

    final routes = await service.getHistory();
    expect(routes, hasLength(2));
    expect(routes.map((r) => r.id), containsAll(['route-1', 'route-2']));
  });

  test('sin inyectar dependencias, usa un Dio real por defecto', () {
    expect(() => NavigationService(), returnsNormally);
  });

  test('requestRoute manda destination_name cuando se provee', () async {
    when(() => dio.post('/api/navigation/route',
        data: any(named: 'data'), options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: _routeJson('route-1'),
        statusCode: 201,
        requestOptions: RequestOptions(path: '/api/navigation/route'),
      ),
    );

    await service.requestRoute(
      originLat: 9.930, originLng: -84.080, destinationLat: 9.931, destinationLng: -84.081,
      destinationName: 'Biblioteca',
    );

    final captured = verify(() => dio.post('/api/navigation/route',
        data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
    expect(captured['destination_name'], 'Biblioteca');
  });

  test('startRoute lanza el detail del backend ante error', () async {
    when(() => dio.post('/api/navigation/start',
        data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/navigation/start'),
        response: Response(
          statusCode: 404,
          data: {'detail': 'Ruta no encontrada'},
          requestOptions: RequestOptions(path: '/api/navigation/start'),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(() => service.startRoute('route-1'), throwsA('Ruta no encontrada'));
  });

  test('finishRoute lanza un mensaje generico ante timeout', () async {
    when(() => dio.post('/api/navigation/finish',
        data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/navigation/finish'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(() => service.finishRoute('route-1'), throwsA('No se pudo conectar al servidor.'));
  });

  test('recalculateRoute lanza un error inesperado generico', () async {
    when(() => dio.post('/api/navigation/recalculate',
        data: any(named: 'data'), options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/navigation/recalculate'),
        type: DioExceptionType.unknown,
      ),
    );

    expect(
      () => service.recalculateRoute(routeId: 'route-1', currentLat: 9.930, currentLng: -84.080),
      throwsA('Error inesperado. Intentá de nuevo.'),
    );
  });

  test('getHistory lanza el detail del backend ante error', () async {
    when(() => dio.get('/api/navigation/history', options: any(named: 'options'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/navigation/history'),
        response: Response(
          statusCode: 401,
          data: {'detail': 'Sesión expirada'},
          requestOptions: RequestOptions(path: '/api/navigation/history'),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(() => service.getHistory(), throwsA('Sesión expirada'));
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
