import 'package:flutter_test/flutter_test.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';

void main() {
  group('RoutePoint.fromJson', () {
    test('parsea lat/lng numéricos (int o double) como double', () {
      final p = RoutePoint.fromJson({'lat': 9.93, 'lng': -84});
      expect(p.lat, 9.93);
      expect(p.lng, -84.0);
    });
  });

  group('RouteStep.fromJson', () {
    test('parsea todos los campos, incluida la conversión de snake_case', () {
      final s = RouteStep.fromJson({
        'instruction': 'Girá a la derecha',
        'turn': 'right',
        'lat': 9.93,
        'lng': -84.08,
        'distance_to_next_m': 15,
      });
      expect(s.instruction, 'Girá a la derecha');
      expect(s.turn, 'right');
      expect(s.distanceToNextM, 15.0);
    });
  });

  group('NavRoute.fromJson', () {
    final json = {
      'id': 'route-1',
      'destination_name': 'Biblioteca',
      'distance_m': 120.5,
      'distance_text': '120 m',
      'duration_s': 92,
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
          'distance_to_next_m': 120.5,
        },
      ],
    };

    test('arma la ruta completa con sus puntos y pasos', () {
      final route = NavRoute.fromJson(json);
      expect(route.id, 'route-1');
      expect(route.destinationName, 'Biblioteca');
      expect(route.points, hasLength(2));
      expect(route.steps, hasLength(1));
      expect(route.steps.first.turn, 'start');
    });

    test('destinationName es null si el backend no manda destino', () {
      final withoutName = Map<String, dynamic>.from(json)..['destination_name'] = null;
      final route = NavRoute.fromJson(withoutName);
      expect(route.destinationName, isNull);
    });
  });
}
