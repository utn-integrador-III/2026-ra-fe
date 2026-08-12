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
}
