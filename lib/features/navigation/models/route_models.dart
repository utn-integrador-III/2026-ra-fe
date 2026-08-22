class RoutePoint {
  final double lat;
  final double lng;

  const RoutePoint({required this.lat, required this.lng});

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );
}

class RouteStep {
  final String instruction;
  final String turn; // 'start' | 'straight' | 'left' | 'right' | 'arrive'
  final double lat;
  final double lng;
  final double distanceToNextM;

  const RouteStep({
    required this.instruction,
    required this.turn,
    required this.lat,
    required this.lng,
    required this.distanceToNextM,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        instruction: json['instruction'] as String,
        turn: json['turn'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        distanceToNextM: (json['distance_to_next_m'] as num).toDouble(),
      );
}

class NavRoute {
  final String id;
  final String? destinationName;
  final double distanceM;
  final String distanceText;
  final double durationS;
  final String status;
  final List<RoutePoint> points;
  final List<RouteStep> steps;
  final DateTime? createdAt;

  const NavRoute({
    required this.id,
    required this.destinationName,
    required this.distanceM,
    required this.distanceText,
    required this.durationS,
    required this.status,
    required this.points,
    required this.steps,
    this.createdAt,
  });

  factory NavRoute.fromJson(Map<String, dynamic> json) => NavRoute(
        id: json['id'] as String,
        destinationName: json['destination_name'] as String?,
        distanceM: (json['distance_m'] as num).toDouble(),
        distanceText: json['distance_text'] as String,
        durationS: (json['duration_s'] as num).toDouble(),
        status: json['status'] as String,
        points: (json['points'] as List)
            .map((p) => RoutePoint.fromJson(p as Map<String, dynamic>))
            .toList(),
        steps: (json['steps'] as List)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );
}
