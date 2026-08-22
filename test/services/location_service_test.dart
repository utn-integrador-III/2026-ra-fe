import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:pathar_fe/core/services/location_service.dart';

import '../helpers/fake_geolocator.dart';

void main() {
  test('devuelve la posicion apenas el stream da buena precision', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      currentPosition: fakePosition(accuracy: 3.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 200));

    expect(pos.accuracy, 3.0);
  });

  test('si el stream nunca da buena precision, usa la mejor lectura al vencer el warmup', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      currentPosition: fakePosition(accuracy: 25.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 50));

    expect(pos.accuracy, 25.0);
  });

  test('si el stream no emite nada, recurre a getCurrentPosition al vencer el warmup', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      positionStream: const Stream.empty(),
      currentPosition: fakePosition(accuracy: 4.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 50));

    expect(pos.accuracy, 4.0);
  });

  test('si tambien falla getCurrentPosition, lanza un error legible', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      positionStream: const Stream.empty(),
      currentPositionError: Exception('sin GPS'),
    );

    expect(
      () => LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 50)),
      throwsA('No se pudo obtener tu ubicación'),
    );
  });

  test('sin permiso concedido lanza un error', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(permission: LocationPermission.denied);

    expect(
      () => LocationService.getPrecisePosition(),
      throwsA('Se necesita permiso de ubicación'),
    );
  });

  test('se queda con la mejor lectura entre varias imprecisas', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      positionStream: Stream.fromIterable([
        fakePosition(accuracy: 20.0),
        fakePosition(accuracy: 30.0),
        fakePosition(accuracy: 15.0),
      ]),
      currentPosition: fakePosition(accuracy: 15.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 100));

    expect(pos.accuracy, 15.0);
  });

  test('un error puntual del stream no interrumpe la espera de una buena lectura', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      positionStream: Stream<Position>.error(Exception('lectura corrupta')),
      currentPosition: fakePosition(accuracy: 5.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 100));

    expect(pos.accuracy, 5.0);
  });

  test('con permiso "always" tambien funciona', () async {
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      permission: LocationPermission.always,
      currentPosition: fakePosition(accuracy: 2.0),
    );

    final pos = await LocationService.getPrecisePosition(warmup: const Duration(milliseconds: 200));

    expect(pos.accuracy, 2.0);
  });
}
