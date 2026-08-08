import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Une varias lecturas de GPS durante una ventana corta y se queda con la
/// más precisa, en vez de confiar en la primera que llegue (que suele ser
/// una estimación gruesa por red/celda antes de que el chip GPS afine).
class LocationService {
  static const double _goodEnoughAccuracyM = 8.0;

  static Future<Position> getPrecisePosition({
    Duration warmup = const Duration(seconds: 7),
  }) async {
    final permission = await _ensurePermission();
    if (!permission) {
      throw 'Se necesita permiso de ubicación';
    }

    final completer = Completer<Position>();
    Position? best;
    StreamSubscription<Position>? sub;
    Timer? timeoutTimer;

    void finish(Position p) {
      if (completer.isCompleted) return;
      sub?.cancel();
      timeoutTimer?.cancel();
      completer.complete(p);
    }

    sub = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
        forceLocationManager: false,
      ),
    ).listen((pos) {
      if (best == null || pos.accuracy < best!.accuracy) {
        best = pos;
      }
      if (pos.accuracy <= _goodEnoughAccuracyM) {
        finish(pos);
      }
    }, onError: (_) {});

    timeoutTimer = Timer(warmup, () async {
      if (best != null) {
        finish(best!);
        return;
      }
      try {
        final fallback = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        finish(fallback);
      } catch (e) {
        if (!completer.isCompleted) {
          sub?.cancel();
          completer.completeError('No se pudo obtener tu ubicación');
        }
      }
    });

    return completer.future;
  }

  static Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
