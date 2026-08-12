import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:8000';

  late final Dio _dio;
  late final FlutterSecureStorage _storage;

  AuthService({Dio? dio, FlutterSecureStorage? storage}) {
    _dio = dio ?? Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _storage = storage ?? const FlutterSecureStorage();
  }

  FirebaseAuth? _firebaseAuthInstance;
  FirebaseAuth get _firebaseAuth => _firebaseAuthInstance ??= FirebaseAuth.instance;

  GoogleSignIn? _googleSignInInstance;
  GoogleSignIn get _googleSignIn => _googleSignInInstance ??= GoogleSignIn();

  // ── Registro manual ──────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
      await _saveToken(response.data['access_token']);
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // ── Login manual ─────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'email': email,
        'password': password,
      });
      await _saveToken(response.data['access_token']);
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // ── Google con Firebase ───────────────────────────────────────
  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      debugPrint('▶ PASO 1: Iniciando');
      await _googleSignIn.signOut();
      debugPrint('▶ PASO 2: signOut OK');

      final googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('✗ TIMEOUT en signIn');
          throw 'Timeout: Google Sign-In no respondió';
        },
      );
      debugPrint('▶ PASO 3: googleUser = $googleUser');

      if (googleUser == null) throw 'Usuario canceló';

      final googleAuth = await googleUser.authentication;
      debugPrint('▶ PASO 4: idToken = ${googleAuth.idToken != null}');
      debugPrint('▶ PASO 4: accessToken = ${googleAuth.accessToken != null}');

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      debugPrint('▶ PASO 5: Autenticando con Firebase...');
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      debugPrint('▶ PASO 6: Firebase OK - ${userCredential.user?.email}');

      final firebaseToken = await userCredential.user!.getIdToken();
      debugPrint('▶ PASO 7: Enviando al backend...');

      final response = await _dio.post('/api/auth/google', data: {
        'id_token': firebaseToken,
      });
      debugPrint('▶ PASO 8: Backend OK');

      await _saveToken(response.data['access_token']);
      return response.data;
    } on FirebaseAuthException catch (e) {
      debugPrint('✗ FirebaseAuthException: ${e.code} - ${e.message}');
      throw 'Error Firebase: ${e.code}';
    } on DioException catch (e) {
      debugPrint('✗ DioError: ${e.response?.statusCode} ${e.response?.data}');
      throw _parseError(e);
    } catch (e) {
      debugPrint('✗ Error: ${e.runtimeType} - $e');
      throw e.toString();
    }
  }

  // ── Perfil del usuario actual ─────────────────────────────────
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await getToken();
      if (token == null) throw 'No hay sesión activa';

      final response = await _dio.get(
        '/api/auth/profile',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // ── Token storage ─────────────────────────────────────────────
  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    await _storage.delete(key: 'access_token');
  }

  String _parseError(DioException e) {
    debugPrint('▶ STATUS: ${e.response?.statusCode}');
    debugPrint('▶ DATA: ${e.response?.data}');
    debugPrint('▶ TYPE: ${e.type}');

    if (e.response?.data != null) {
      final detail = e.response!.data['detail'];
      if (detail != null) return detail.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'No se pudo conectar al servidor.';
    }
    return 'Error inesperado. Intentá de nuevo.';
  }
}