import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

class FakeCameraPlatform extends CameraPlatform {
  FakeCameraPlatform({this.cameras = const [], this.frameStream});

  final List<CameraDescription> cameras;
  Stream<CameraImageData>? frameStream;

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  bool supportsImageStreaming() => true;

  @override
  Future<int> createCameraWithSettings(CameraDescription cameraDescription, MediaSettings mediaSettings) async => 1;

  @override
  Future<void> initializeCamera(int cameraId, {ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown}) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) {
    return Stream.value(const CameraInitializedEvent(1, 640, 480, ExposureMode.auto, false, FocusMode.auto, false));
  }

  // OJO: no usar Stream.empty() acá — CameraController espera este stream con
  // `.first`, y un stream vacío que se cierra al toque hace que `.first`
  // tire "Bad state: No element" sin que nada lo atrape (va dentro de un
  // unawaited() en el propio paquete camera).
  final StreamController<CameraErrorEvent> _errorController = StreamController<CameraErrorEvent>.broadcast();

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => _errorController.stream;

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) => const Stream.empty();

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() => const Stream.empty();

  @override
  Future<void> setFocusMode(int cameraId, FocusMode mode) async {}

  @override
  Future<void> setExposureMode(int cameraId, ExposureMode mode) async {}

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(int cameraId, {CameraImageStreamOptions? options}) {
    return frameStream ?? const Stream.empty();
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox.shrink();

  @override
  Future<void> dispose(int cameraId) async {}
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
