import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Cambiá esta IP por la de tu servidor Ubuntu en la red local
  static const String _baseUrl = 'http://192.168.0.17:8000'; // 10.0.2.2 = localhost desde emulador Android

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  final _storage = const FlutterSecureStorage();

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

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await _dio.post('/api/auth/google', data: {
        'id_token': idToken,
      });
      await _saveToken(response.data['access_token']);
      return response.data;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'access_token');
  }

  Future<void> logout() async {
    await _storage.delete(key: 'access_token');
  }

  String _parseError(DioException e) {
    if (e.response?.data != null) {
      final detail = e.response!.data['detail'];
      if (detail != null) return detail.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'No se pudo conectar al servidor. Verificá tu conexión.';
    }
    return 'Error inesperado. Intentá de nuevo.';
  }
}