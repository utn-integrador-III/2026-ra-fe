import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';

class MockDio extends Mock implements Dio {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

DioException _dioError({required String path, int? statusCode, Map<String, dynamic>? data, DioExceptionType type = DioExceptionType.badResponse}) {
  return DioException(
    requestOptions: RequestOptions(path: path),
    response: statusCode == null
        ? null
        : Response(statusCode: statusCode, data: data, requestOptions: RequestOptions(path: path)),
    type: type,
  );
}

void main() {
  late MockDio dio;
  late MockFlutterSecureStorage storage;
  late MockGoogleSignIn googleSignIn;
  late MockFirebaseAuth firebaseAuth;
  late AuthService service;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(GoogleAuthProvider.credential(accessToken: 'fallback', idToken: 'fallback'));
    dotenv.loadFromString(envString: 'API_URL=http://127.0.0.1:9');
  });

  setUp(() {
    dio = MockDio();
    storage = MockFlutterSecureStorage();
    googleSignIn = MockGoogleSignIn();
    firebaseAuth = MockFirebaseAuth();
    service = AuthService(dio: dio, storage: storage, googleSignIn: googleSignIn, firebaseAuth: firebaseAuth);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => 'tok123');
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test('sin inyectar dependencias, usa un Dio real por defecto', () {
    expect(() => AuthService(), returnsNormally);
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

  test('updatePreferences manda walkingSpeedMps cuando se provee', () async {
    when(() => dio.put('/api/preferences', data: any(named: 'data'), options: any(named: 'options')))
        .thenAnswer((_) async => Response(
              data: {'voice_guidance_enabled': true, 'walking_speed_mps': 1.6},
              statusCode: 200,
              requestOptions: RequestOptions(path: '/api/preferences'),
            ));

    await service.updatePreferences(walkingSpeedMps: 1.6);

    final captured = verify(() => dio.put('/api/preferences',
        data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
    expect(captured['walking_speed_mps'], 1.6);
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

  test('register lanza el detail del backend ante error', () async {
    when(() => dio.post('/api/auth/register', data: any(named: 'data'))).thenThrow(
      _dioError(path: '/api/auth/register', statusCode: 409, data: {'detail': 'El correo ya está en uso'}),
    );

    expect(
      () => service.register(name: 'Ana', email: 'a@b.com', password: '123456'),
      throwsA('El correo ya está en uso'),
    );
  });

  test('login lanza un mensaje generico ante receiveTimeout', () async {
    when(() => dio.post('/api/auth/login', data: any(named: 'data'))).thenThrow(
      _dioError(path: '/api/auth/login', type: DioExceptionType.receiveTimeout),
    );

    expect(
      () => service.login(email: 'a@b.com', password: '123456'),
      throwsA('No se pudo conectar al servidor.'),
    );
  });

  test('getProfile lanza el detail del backend ante error', () async {
    when(() => dio.get('/api/auth/profile', options: any(named: 'options'))).thenThrow(
      _dioError(path: '/api/auth/profile', statusCode: 401, data: {'detail': 'Sesión expirada'}),
    );

    expect(() => service.getProfile(), throwsA('Sesión expirada'));
  });

  test('updateProfile lanza un error inesperado generico', () async {
    when(() => dio.put('/api/auth/profile', data: any(named: 'data'), options: any(named: 'options')))
        .thenThrow(_dioError(path: '/api/auth/profile', type: DioExceptionType.unknown));

    expect(() => service.updateProfile(name: 'Ana'), throwsA('Error inesperado. Intentá de nuevo.'));
  });

  test('getPreferences lanza el detail del backend ante error', () async {
    when(() => dio.get('/api/preferences', options: any(named: 'options'))).thenThrow(
      _dioError(path: '/api/preferences', statusCode: 500, data: {'detail': 'Error del servidor'}),
    );

    expect(() => service.getPreferences(), throwsA('Error del servidor'));
  });

  test('updatePreferences lanza el detail del backend ante error', () async {
    when(() => dio.put('/api/preferences', data: any(named: 'data'), options: any(named: 'options')))
        .thenThrow(_dioError(path: '/api/preferences', statusCode: 400, data: {'detail': 'Valor inválido'}));

    expect(() => service.updatePreferences(voiceGuidanceEnabled: true), throwsA('Valor inválido'));
  });

  test('getFavorites lanza el detail del backend ante error', () async {
    when(() => dio.get('/api/favorites', options: any(named: 'options'))).thenThrow(
      _dioError(path: '/api/favorites', statusCode: 401, data: {'detail': 'Sesión expirada'}),
    );

    expect(() => service.getFavorites(), throwsA('Sesión expirada'));
  });

  test('addFavorite lanza el detail del backend ante error', () async {
    when(() => dio.post('/api/favorites', data: any(named: 'data'), options: any(named: 'options')))
        .thenThrow(_dioError(path: '/api/favorites', statusCode: 400, data: {'detail': 'Datos inválidos'}));

    expect(
      () => service.addFavorite(name: 'Cafetería', latitude: 9.93, longitude: -84.08),
      throwsA('Datos inválidos'),
    );
  });

  test('deleteFavorite lanza el detail del backend ante error', () async {
    when(() => dio.delete('/api/favorites/f1', options: any(named: 'options'))).thenThrow(
      _dioError(path: '/api/favorites/f1', statusCode: 404, data: {'detail': 'Favorito no encontrado'}),
    );

    expect(() => service.deleteFavorite('f1'), throwsA('Favorito no encontrado'));
  });

  test('logout limpia sesion de Google, Firebase y el token guardado', () async {
    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
    when(() => firebaseAuth.signOut()).thenAnswer((_) async {});

    await service.logout();

    verify(() => googleSignIn.signOut()).called(1);
    verify(() => firebaseAuth.signOut()).called(1);
    verify(() => storage.delete(key: 'access_token')).called(1);
  });

  test('loginWithGoogle lanza "Usuario canceló" si no elige cuenta', () async {
    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
    when(() => googleSignIn.signIn()).thenAnswer((_) async => null);

    expect(() => service.loginWithGoogle(), throwsA('Usuario canceló'));
  });

  test('loginWithGoogle propaga un error inesperado del SDK de Google', () async {
    when(() => googleSignIn.signOut()).thenThrow(Exception('SDK no inicializado'));

    expect(() => service.loginWithGoogle(), throwsA(contains('SDK no inicializado')));
  });

  test('loginWithGoogle exitoso autentica con Firebase y guarda el token', () async {
    final account = MockGoogleSignInAccount();
    final googleAuth = MockGoogleSignInAuthentication();
    final userCredential = MockUserCredential();
    final user = MockUser();

    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
    when(() => googleSignIn.signIn()).thenAnswer((_) async => account);
    when(() => account.authentication).thenAnswer((_) async => googleAuth);
    when(() => googleAuth.idToken).thenReturn('id-token');
    when(() => googleAuth.accessToken).thenReturn('access-token');
    when(() => firebaseAuth.signInWithCredential(any())).thenAnswer((_) async => userCredential);
    when(() => userCredential.user).thenReturn(user);
    when(() => user.email).thenReturn('ana@test.com');
    when(() => user.getIdToken()).thenAnswer((_) async => 'firebase-token');
    when(() => dio.post('/api/auth/google', data: any(named: 'data'))).thenAnswer(
      (_) async => Response(
        data: {'access_token': 'tok123', 'user': {'email': 'ana@test.com'}},
        statusCode: 200,
        requestOptions: RequestOptions(path: '/api/auth/google'),
      ),
    );

    final result = await service.loginWithGoogle();

    expect(result['access_token'], 'tok123');
    verify(() => storage.write(key: 'access_token', value: 'tok123')).called(1);
  });

  test('loginWithGoogle lanza el error de Firebase si la credencial es rechazada', () async {
    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
    when(() => googleSignIn.signIn()).thenThrow(
      FirebaseAuthException(code: 'invalid-credential', message: 'Credencial inválida'),
    );

    expect(() => service.loginWithGoogle(), throwsA('Error Firebase: invalid-credential'));
  });

  test('loginWithGoogle lanza el detail del backend si falla el envio del token', () async {
    final account = MockGoogleSignInAccount();
    final googleAuth = MockGoogleSignInAuthentication();
    final userCredential = MockUserCredential();
    final user = MockUser();

    when(() => googleSignIn.signOut()).thenAnswer((_) async => null);
    when(() => googleSignIn.signIn()).thenAnswer((_) async => account);
    when(() => account.authentication).thenAnswer((_) async => googleAuth);
    when(() => googleAuth.idToken).thenReturn('id-token');
    when(() => googleAuth.accessToken).thenReturn('access-token');
    when(() => firebaseAuth.signInWithCredential(any())).thenAnswer((_) async => userCredential);
    when(() => userCredential.user).thenReturn(user);
    when(() => user.email).thenReturn('ana@test.com');
    when(() => user.getIdToken()).thenAnswer((_) async => 'firebase-token');
    when(() => dio.post('/api/auth/google', data: any(named: 'data'))).thenThrow(
      _dioError(path: '/api/auth/google', statusCode: 401, data: {'detail': 'Token de Google inválido'}),
    );

    expect(() => service.loginWithGoogle(), throwsA('Token de Google inválido'));
  });
}
