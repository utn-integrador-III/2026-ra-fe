import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/perception_service.dart';

class MockObjectDetector extends Mock implements ObjectDetector {}

class MockImageLabeler extends Mock implements ImageLabeler {}

class FakeInputImage extends Fake implements InputImage {}

DetectedObject _detectedObject({required List<Label> labels}) {
  return DetectedObject(
    boundingBox: const Rect.fromLTWH(10, 20, 30, 40),
    labels: labels,
    trackingId: 1,
  );
}

CameraImage _cameraImage({
  required int rawFormat,
  ImageFormatGroup group = ImageFormatGroup.nv21,
  List<CameraImagePlane> planes = const [],
}) {
  return CameraImage.fromPlatformInterface(
    CameraImageData(
      format: CameraImageFormat(group, raw: rawFormat),
      height: 480,
      width: 640,
      planes: planes,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeInputImage());
  });

  group('detectObstacles', () {
    late MockObjectDetector detector;
    late PerceptionService service;

    setUp(() {
      detector = MockObjectDetector();
      service = PerceptionService(objectDetector: detector);
    });

    test('mapea objetos detectados a DetectedObstacle usando la primera etiqueta', () async {
      when(() => detector.processImage(any())).thenAnswer((_) async => [
            _detectedObject(labels: [Label(confidence: 0.87, index: 1, text: 'person')]),
          ]);

      final result = await service.detectObstacles(FakeInputImage());

      expect(result, hasLength(1));
      expect(result.first.label, 'person');
      expect(result.first.confidence, 0.87);
      expect(result.first.boundingBox, const Rect.fromLTWH(10, 20, 30, 40));
    });

    test('un objeto sin etiquetas queda con label null y confianza 0', () async {
      when(() => detector.processImage(any())).thenAnswer((_) async => [
            _detectedObject(labels: []),
          ]);

      final result = await service.detectObstacles(FakeInputImage());

      expect(result.single.label, isNull);
      expect(result.single.confidence, 0);
    });

    test('sin objetos detectados devuelve una lista vacia', () async {
      when(() => detector.processImage(any())).thenAnswer((_) async => []);

      final result = await service.detectObstacles(FakeInputImage());

      expect(result, isEmpty);
    });
  });

  group('labelSurroundings', () {
    late MockImageLabeler labeler;
    late PerceptionService service;

    setUp(() {
      labeler = MockImageLabeler();
      service = PerceptionService(imageLabeler: labeler);
    });

    test('descarta etiquetas por debajo del umbral de confianza', () async {
      when(() => labeler.processImage(any())).thenAnswer((_) async => [
            ImageLabel(confidence: 0.9, label: 'sidewalk', index: 1),
            ImageLabel(confidence: 0.4, label: 'sky', index: 2),
          ]);

      final result = await service.labelSurroundings(FakeInputImage());

      expect(result, ['sidewalk']);
    });

    test('sin etiquetas por encima del umbral devuelve lista vacia', () async {
      when(() => labeler.processImage(any())).thenAnswer((_) async => []);

      final result = await service.labelSurroundings(FakeInputImage());

      expect(result, isEmpty);
    });
  });

  group('dispose', () {
    test('cierra unicamente los detectores que llegaron a instanciarse', () async {
      final detector = MockObjectDetector();
      when(() => detector.processImage(any())).thenAnswer((_) async => []);
      when(() => detector.close()).thenAnswer((_) async {});
      final service = PerceptionService(objectDetector: detector);

      await service.detectObstacles(FakeInputImage());
      await service.dispose();

      verify(() => detector.close()).called(1);
    });

    test('no explota si nunca se uso ningun detector', () async {
      final service = PerceptionService();
      await service.dispose();
    });
  });

  group('inputImageFromCameraImage', () {
    const androidCamera = CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    );

    test('formato desconocido devuelve null', () {
      final service = PerceptionService();
      final image = _cameraImage(rawFormat: -1);

      expect(service.inputImageFromCameraImage(image, androidCamera), isNull);
    });

    test('sin planos devuelve null', () {
      final service = PerceptionService();
      // nv21 (17) es un formato valido, pero sin planos no hay bytes que leer.
      final image = _cameraImage(rawFormat: 17, planes: const []);

      expect(service.inputImageFromCameraImage(image, androidCamera), isNull);
    });

    test('con formato y planos validos arma el InputImage con la metadata correcta', () {
      final service = PerceptionService();
      final bytes = Uint8List.fromList(List.filled(100, 0));
      final image = _cameraImage(
        rawFormat: 17,
        planes: [CameraImagePlane(bytes: bytes, bytesPerRow: 640)],
      );

      final result = service.inputImageFromCameraImage(image, androidCamera);

      expect(result, isNotNull);
      expect(result!.metadata!.bytesPerRow, 640);
      expect(result.metadata!.size.width, 640);
      expect(result.metadata!.size.height, 480);
      expect(result.bytes, bytes);
    });
  });
}
