import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/core/services/navigation_service.dart';
import 'package:pathar_fe/core/services/perception_service.dart';
import 'package:pathar_fe/features/navigation/models/obstacle.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';
import 'package:pathar_fe/pages/navigation_screen.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

import '../helpers/fake_geolocator.dart';
import '../helpers/fake_plugins.dart';

class MockNavigationService extends Mock implements NavigationService {}

class MockAuthService extends Mock implements AuthService {}

class MockTts extends Mock implements FlutterTts {}

class MockPerceptionService extends Mock implements PerceptionService {}

class FakeInputImage extends Fake implements InputImage {}

class FakeCameraImage extends Fake implements CameraImage {}

const _originLat = 9.9300;
const _originLng = -84.0800;
const _destLat = 9.9310;
const _destLng = -84.0800;
const _testCamera = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

NavRoute _buildRoute() {
  return NavRoute.fromJson({
    'id': 'route-1',
    'destination_name': 'Biblioteca',
    'distance_m': 111.0,
    'distance_text': '111 m',
    'duration_s': 85.0,
    'status': 'calculated',
    'points': [
      {'lat': _originLat, 'lng': _originLng},
      {'lat': _destLat, 'lng': _destLng},
    ],
    'steps': [
      {'instruction': 'Iniciá la ruta', 'turn': 'start', 'lat': _originLat, 'lng': _originLng, 'distance_to_next_m': 111.0},
      {'instruction': 'Llegaste a tu destino', 'turn': 'arrive', 'lat': _destLat, 'lng': _destLng, 'distance_to_next_m': 0.0},
    ],
  });
}

CameraImageData _fakeCameraImageData() {
  return CameraImageData(
    format: const CameraImageFormat(ImageFormatGroup.nv21, raw: 17),
    height: 480,
    width: 640,
    planes: [CameraImagePlane(bytes: Uint8List.fromList(List.filled(100, 0)), bytesPerRow: 640)],
  );
}

void main() {
  late MockNavigationService navService;
  late MockAuthService authService;
  late MockTts tts;
  late MockPerceptionService perception;
  late StreamController<CameraImageData> frameController;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(FakeInputImage());
    registerFallbackValue(FakeCameraImage());
    registerFallbackValue(_testCamera);
    PermissionHandlerPlatform.instance = FakePermissionHandlerPlatform();
    SensorsPlatform.instance = FakeSensorsPlatform();
  });

  setUp(() {
    navService = MockNavigationService();
    authService = MockAuthService();
    tts = MockTts();
    perception = MockPerceptionService();
    frameController = StreamController<CameraImageData>.broadcast();
    addTearDown(frameController.close);

    CameraPlatform.instance = FakeCameraPlatform(cameras: [_testCamera], frameStream: frameController.stream);
    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      currentPosition: fakePosition(latitude: _originLat, longitude: _originLng),
    );

    when(() => authService.getPreferences()).thenAnswer((_) async => {'voice_guidance_enabled': true});
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => tts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => tts.awaitSpeakCompletion(any())).thenAnswer((_) async => 1);
    when(() => tts.setStartHandler(any())).thenReturn(null);
    when(() => tts.setCompletionHandler(any())).thenReturn(null);
    when(() => tts.setCancelHandler(any())).thenReturn(null);
    when(() => tts.setErrorHandler(any())).thenReturn(null);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
    when(() => perception.inputImageFromCameraImage(any(), any())).thenReturn(FakeInputImage());
    when(() => perception.dispose()).thenAnswer((_) async {});
  });

  Widget wrap(Map<String, dynamic>? args) {
    return MaterialApp(
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(arguments: args),
          builder: (_) => NavigationScreen(
            navService: navService,
            authService: authService,
            tts: tts,
            perception: perception,
          ),
        ),
      ),
    );
  }

  Future<void> pumpWithRoute(WidgetTester tester) async {
    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();
  }

  testWidgets('un obstaculo centrado y cercano dispara el aviso critico', (tester) async {
    when(() => perception.detectObstacles(any())).thenAnswer((_) async => [
          const DetectedObstacle(boundingBox: Rect.fromLTWH(270, 0, 100, 250)),
        ]);
    when(() => perception.labelSurroundings(any())).thenAnswer((_) async => []);

    await pumpWithRoute(tester);
    frameController.add(_fakeCameraImageData());
    await tester.pumpAndSettle();

    expect(find.textContaining('Obstáculo detectado'), findsOneWidget);
    verify(() => tts.speak(any(that: contains('obstáculo')))).called(1);
  });

  testWidgets('sin obstaculos peligrosos no aparece el aviso', (tester) async {
    when(() => perception.detectObstacles(any())).thenAnswer((_) async => []);
    when(() => perception.labelSurroundings(any())).thenAnswer((_) async => []);

    await pumpWithRoute(tester);
    frameController.add(_fakeCameraImageData());
    await tester.pumpAndSettle();

    expect(find.textContaining('Obstáculo detectado'), findsNothing);
  });

  testWidgets('reconocer la vereda narra el entorno por voz', (tester) async {
    when(() => perception.detectObstacles(any())).thenAnswer((_) async => []);
    when(() => perception.labelSurroundings(any())).thenAnswer((_) async => ['sidewalk']);

    await pumpWithRoute(tester);
    frameController.add(_fakeCameraImageData());
    await tester.pumpAndSettle();

    verify(() => tts.speak(any(that: contains('Cerca de vos')))).called(1);
  });

  testWidgets('un obstaculo activo silencia la narracion del entorno', (tester) async {
    when(() => perception.detectObstacles(any())).thenAnswer((_) async => [
          const DetectedObstacle(boundingBox: Rect.fromLTWH(270, 0, 100, 250)),
        ]);
    when(() => perception.labelSurroundings(any())).thenAnswer((_) async => ['sidewalk']);

    await pumpWithRoute(tester);
    frameController.add(_fakeCameraImageData());
    await tester.pumpAndSettle();

    verifyNever(() => tts.speak(any(that: contains('Cerca de vos'))));
  });

  testWidgets('el boton Volver en la pantalla de error cierra la navegacion', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenThrow('No hay ruta posible');

    await pumpWithRoute(tester);

    expect(find.text('No hay ruta posible'), findsOneWidget);
    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('No hay ruta posible'), findsNothing);
  });
}
