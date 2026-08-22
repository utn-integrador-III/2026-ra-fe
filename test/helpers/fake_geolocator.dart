import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

Position fakePosition({
  double latitude = 9.930,
  double longitude = -84.080,
  double accuracy = 5.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 1, 1),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  LocationPermission permission;
  Position? currentPosition;
  Stream<Position>? positionStream;
  Object? currentPositionError;

  FakeGeolocatorPlatform({
    this.permission = LocationPermission.whileInUse,
    Position? currentPosition,
    this.positionStream,
    this.currentPositionError,
  }) : currentPosition = currentPosition ?? fakePosition();

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (currentPositionError != null) throw currentPositionError!;
    return currentPosition!;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    return positionStream ?? Stream<Position>.fromIterable([currentPosition!]);
  }
}
