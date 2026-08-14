import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../../features/navigation/models/obstacle.dart';

class PerceptionService {
  ObjectDetector? _objectDetectorInstance;
  ObjectDetector get _objectDetector => _objectDetectorInstance ??= ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );

  ImageLabeler? _imageLabelerInstance;
  ImageLabeler get _imageLabeler =>
      _imageLabelerInstance ??= ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.6));

  Future<List<DetectedObstacle>> detectObstacles(InputImage image) async {
    final objects = await _objectDetector.processImage(image);
    return objects
        .map((o) => DetectedObstacle(
              boundingBox: o.boundingBox,
              label: o.labels.isNotEmpty ? o.labels.first.text : null,
              confidence: o.labels.isNotEmpty ? o.labels.first.confidence : 0,
            ))
        .toList();
  }

  Future<List<String>> labelSurroundings(InputImage image) async {
    final labels = await _imageLabeler.processImage(image);
    return labels.where((l) => l.confidence >= 0.6).map((l) => l.label).toList();
  }

  InputImage? inputImageFromCameraImage(CameraImage image, CameraDescription camera) {
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;
    if (image.planes.isEmpty) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> dispose() async {
    await _objectDetectorInstance?.close();
    await _imageLabelerInstance?.close();
  }
}
