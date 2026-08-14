import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';

class MockDio extends Mock implements Dio {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockDio dio;
  late MockFlutterSecureStorage storage;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = MockDio();
    storage = MockFlutterSecureStorage();
    service = AuthService(dio: dio, storage: storage);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'tok123');
  });

  test('register guarda el token y devuelve los datos del usuario', () async {
    when(() => dio.post('/api/auth/register', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        data: {
          'access_token': 'tok123',
          'user': {'id': '1', 'email': 'a@b.com'},
        },
        statusCode: 201,
        requestOptions: RequestOptions(path: '/api/auth/register'),
      ),
    );

    final result = await service.register(name: 'Ana', email: 'a@b.com', password: '123456');

    expect(result['access_token'], 'tok123');
    verify(() => storage.write(key: 'access_token', value: 'tok123')).called(1);
  });

  test('login lanza el detail que manda el backend', () async {
    when(() => dio.post('/api/auth/login', data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        response: Response(
          statusCode: 401,
          data: {'detail': 'Credenciales inválidas'},
          requestOptions: RequestOptions(path: '/api/auth/login'),
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      () => service.login(email: 'a@b.com', password: 'mala'),
      throwsA('Credenciales inválidas'),
    );
  });

  test('login lanza un mensaje generico ante timeout', () async {
    when(() => dio.post('/api/auth/login', data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(
      () => service.login(email: 'a@b.com', password: '123456'),
      throwsA('No se pudo conectar al servidor.'),
    );
  });

  test('getProfile lanza si no hay sesion activa', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    expect(() => service.getProfile(), throwsA('No hay sesión activa'));
  });

  test('getProfile manda el token guardado como Bearer', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'tok123');
    when(() => dio.get('/api/auth/profile', options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: {'email': 'a@b.com'},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/auth/profile'),
      ),
    );

    final result = await service.getProfile();
    expect(result['email'], 'a@b.com');
  });

  test('getToken lee del almacenamiento seguro', () async {
    when(() => storage.read(key: 'access_token')).thenAnswer((_) async => 'abc');
    expect(await service.getToken(), 'abc');
  });

  test('updateProfile manda el nombre nuevo', () async {
    when(() => dio.put('/api/auth/profile', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              data: {'name': 'Nombre Nuevo'},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/api/auth/profile'),
            ));

    final result = await service.updateProfile(name: 'Nombre Nuevo');
    expect(result['name'], 'Nombre Nuevo');
  });

  test('getPreferences devuelve las preferencias del backend', () async {
    when(() => dio.get('/api/preferences', options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: {'voice_guidance_enabled': false, 'walking_speed_mps': 1.6},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/preferences'),
      ),
    );

    final result = await service.getPreferences();
    expect(result['voice_guidance_enabled'], false);
  });

  test('updatePreferences manda solo los campos no nulos', () async {
    when(() => dio.put('/api/preferences', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              data: {'voice_guidance_enabled': false, 'walking_speed_mps': 1.3},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/api/preferences'),
            ));

    await service.updatePreferences(voiceGuidanceEnabled: false);

    final captured = verify(() => dio.put('/api/preferences',
        data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
    expect(captured.containsKey('voice_guidance_enabled'), true);
    expect(captured.containsKey('walking_speed_mps'), false);
  });

  test('getFavorites devuelve la lista de favoritos', () async {
    when(() => dio.get('/api/favorites', options: any(named: 'options'))).thenAnswer(
      (_) async => Response(
        data: {
          'favorites': [
            {'id': 'f1', 'name': 'Biblioteca'},
          ],
          'total': 1,
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/favorites'),
      ),
    );

    final result = await service.getFavorites();
    expect(result, hasLength(1));
    expect(result.first['name'], 'Biblioteca');
  });

  test('addFavorite manda los datos del lugar', () async {
    when(() => dio.post('/api/favorites', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              data: {'id': 'f1', 'name': 'Cafeteria'},
              statusCode: 201,
              requestOptions: RequestOptions(path: '/api/favorites'),
            ));

    final result = await service.addFavorite(name: 'Cafeteria', latitude: 9.93, longitude: -84.08);
    expect(result['id'], 'f1');
  });

  test('deleteFavorite pide el endpoint correcto', () async {
    when(() => dio.delete('/api/favorites/f1', options: any(named: 'options'))).thenAnswer(
      (_) async => Response(statusCode: 200, requestOptions: RequestOptions(path: '/api/favorites/f1')),
    );

    await service.deleteFavorite('f1');
    verify(() => dio.delete('/api/favorites/f1', options: any(named: 'options'))).called(1);
  });
}
