import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

class FakeCameraPlatform extends CameraPlatform {
  @override
  Future<List<CameraDescription>> availableCameras() async => [];
}

class FakePermissionHandlerPlatform extends PermissionHandlerPlatform {
  PermissionStatus status;
  FakePermissionHandlerPlatform({this.status = PermissionStatus.granted});

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async => status;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(List<Permission> permissions) async {
    return {for (final p in permissions) p: status};
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale(Permission permission) async => false;
}

class FakeSensorsPlatform extends SensorsPlatform {
  Stream<AccelerometerEvent>? accelerometerStream;

  @override
  Stream<AccelerometerEvent> accelerometerEventStream({Duration samplingPeriod = SensorInterval.normalInterval}) {
    return accelerometerStream ?? Stream<AccelerometerEvent>.fromIterable([
      AccelerometerEvent(0, 9.8, 0, DateTime(2026, 1, 1)),
    ]);
  }
}
