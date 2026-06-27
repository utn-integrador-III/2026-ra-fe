import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String _baseUrl = 'http://192.168.0.17:8000';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  final _storage = const FlutterSecureStorage();
  final _firebaseAuth = FirebaseAuth.instance;
  final _googleSignIn = GoogleSignIn();

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
      // 1. Abrir selector de cuenta
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw 'Inicio cancelado';

      // 2. Obtener credenciales de Google
      final googleAuth = await googleUser.authentication;

      // 3. Autenticar con Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(credential);

      // 4. Obtener el Firebase ID Token para mandar al backend
      final firebaseToken = await userCredential.user!.getIdToken();

      // 5. Mandar al backend
      final response = await _dio.post('/api/auth/google', data: {
        'id_token': firebaseToken,
      });
      await _saveToken(response.data['access_token']);
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e);
    } catch (e) {
      throw e.toString();
    }
  }

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