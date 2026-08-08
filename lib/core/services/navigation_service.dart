import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';
import '../../features/navigation/models/route_models.dart';

class NavigationService {
  static String get _baseUrl => dotenv.env['API_URL'] ?? 'http://localhost:8000';

  final _authService = AuthService();
  late final Dio _dio;

  NavigationService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Options> _authOptions() async {
    final token = await _authService.getToken();
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<NavRoute> requestRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    String? destinationName,
  }) async {
    try {
      final response = await _dio.post(
        '/api/navigation/route',
        data: {
          'origin_lat': originLat,
          'origin_lng': originLng,
          'destination_lat': destinationLat,
          'destination_lng': destinationLng,
          if (destinationName != null) 'destination_name': destinationName,
        },
        options: await _authOptions(),
      );
      return NavRoute.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<NavRoute> startRoute(String routeId) async {
    try {
      final response = await _dio.post(
        '/api/navigation/start',
        data: {'route_id': routeId},
        options: await _authOptions(),
      );
      return NavRoute.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<NavRoute> finishRoute(String routeId) async {
    try {
      final response = await _dio.post(
        '/api/navigation/finish',
        data: {'route_id': routeId},
        options: await _authOptions(),
      );
      return NavRoute.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  Future<NavRoute> recalculateRoute({
    required String routeId,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      final response = await _dio.post(
        '/api/navigation/recalculate',
        data: {
          'route_id': routeId,
          'current_lat': currentLat,
          'current_lng': currentLng,
        },
        options: await _authOptions(),
      );
      return NavRoute.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      final detail = (e.response!.data as Map)['detail'];
      if (detail != null) return detail.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'No se pudo conectar al servidor.';
    }
    return 'Error inesperado. Intentá de nuevo.';
  }
}
