import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/core/services/navigation_service.dart';
import 'package:pathar_fe/features/navigation/models/route_models.dart';
import 'package:pathar_fe/pages/navigation_screen.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

import '../helpers/fake_geolocator.dart';
import '../helpers/fake_plugins.dart';

class MockNavigationService extends Mock implements NavigationService {}

class MockAuthService extends Mock implements AuthService {}

class MockTts extends Mock implements FlutterTts {}

const _originLat = 9.9300;
const _originLng = -84.0800;
const _destLat = 9.9310; // ~111 m al norte
const _destLng = -84.0800;

NavRoute _buildRoute({String id = 'route-1', String? destinationName = 'Biblioteca'}) {
  return NavRoute.fromJson({
    'id': id,
    'destination_name': destinationName,
    'distance_m': 111.0,
    'distance_text': '111 m',
    'duration_s': 85.0,
    'status': 'calculated',
    'points': [
      {'lat': _originLat, 'lng': _originLng},
      {'lat': _destLat, 'lng': _destLng},
    ],
    'steps': [
      {
        'instruction': 'Iniciá la ruta',
        'turn': 'start',
        'lat': _originLat,
        'lng': _originLng,
        'distance_to_next_m': 111.0,
      },
      {
        'instruction': 'Llegaste a tu destino',
        'turn': 'arrive',
        'lat': _destLat,
        'lng': _destLng,
        'distance_to_next_m': 0.0,
      },
    ],
  });
}

// Ruta con un nodo intermedio (giro a la derecha) para poder probar el
// avance de nodo, el aviso proactivo de giro y la llegada final.
const _midLat = 9.930180; // ~20 m al norte del origen
const _midLng = -84.0800;
const _turnDestLat = 9.930180;
const _turnDestLng = -84.079820; // ~20 m al este del nodo intermedio

NavRoute _buildTurnRoute({String id = 'route-turn'}) {
  return NavRoute.fromJson({
    'id': id,
    'destination_name': 'Biblioteca',
    'distance_m': 40.0,
    'distance_text': '40 m',
    'duration_s': 30.0,
    'status': 'calculated',
    'points': [
      {'lat': _originLat, 'lng': _originLng},
      {'lat': _midLat, 'lng': _midLng},
      {'lat': _turnDestLat, 'lng': _turnDestLng},
    ],
    'steps': [
      {'instruction': 'Iniciá la ruta', 'turn': 'start', 'lat': _originLat, 'lng': _originLng, 'distance_to_next_m': 20.0},
      {'instruction': 'Girá a la derecha', 'turn': 'right', 'lat': _midLat, 'lng': _midLng, 'distance_to_next_m': 20.0},
      {'instruction': 'Llegaste a tu destino', 'turn': 'arrive', 'lat': _turnDestLat, 'lng': _turnDestLng, 'distance_to_next_m': 0.0},
    ],
  });
}

void main() {
  late MockNavigationService navService;
  late MockAuthService authService;
  late MockTts tts;

  setUpAll(() {
    registerFallbackValue(Options());
    CameraPlatform.instance = FakeCameraPlatform();
    PermissionHandlerPlatform.instance = FakePermissionHandlerPlatform();
    SensorsPlatform.instance = FakeSensorsPlatform();
  });

  setUp(() {
    navService = MockNavigationService();
    authService = MockAuthService();
    tts = MockTts();
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
  });

  Widget wrap(Map<String, dynamic>? args) {
    return MaterialApp(
      home: Navigator(
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: RouteSettings(arguments: args),
          builder: (_) => NavigationScreen(navService: navService, authService: authService, tts: tts),
        ),
      ),
    );
  }

  testWidgets('los manejadores de estado del TTS no rompen al invocarse', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    final completionHandler = verify(() => tts.setCompletionHandler(captureAny())).captured.single as VoidCallback;
    final cancelHandler = verify(() => tts.setCancelHandler(captureAny())).captured.single as VoidCallback;
    final errorHandler = verify(() => tts.setErrorHandler(captureAny())).captured.single as void Function(dynamic);

    completionHandler();
    cancelHandler();
    errorHandler('boom');

    expect(tester.takeException(), isNull);
  });

  testWidgets('sin destino muestra el error correspondiente', (tester) async {
    await tester.pumpWidget(wrap(null));
    await tester.pumpAndSettle();

    expect(find.text('No se seleccionó ningún destino. Volvé a buscar un lugar.'), findsOneWidget);
  });

  testWidgets('una ruta larga muestra la distancia en kilometros', (tester) async {
    // ~1500 m al norte del origen (0.01347° ≈ 1500 m).
    const farDestLat = 9.9300 + 0.01347;
    NavRoute farRoute() => NavRoute.fromJson({
          'id': 'route-far',
          'destination_name': 'Biblioteca',
          'distance_m': 1500.0,
          'distance_text': '1.5 km',
          'duration_s': 900.0,
          'status': 'calculated',
          'points': [
            {'lat': _originLat, 'lng': _originLng},
            {'lat': farDestLat, 'lng': _originLng},
          ],
          'steps': [
            {'instruction': 'Iniciá la ruta', 'turn': 'start', 'lat': _originLat, 'lng': _originLng, 'distance_to_next_m': 1500.0},
            {'instruction': 'Llegaste a tu destino', 'turn': 'arrive', 'lat': farDestLat, 'lng': _originLng, 'distance_to_next_m': 0.0},
          ],
        });

    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => farRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => farRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': farDestLat, 'lng': _originLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    expect(find.textContaining('km'), findsWidgets);
  });

  testWidgets('con destino y origen calcula la ruta y muestra la instruccion', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.textContaining('Quedan'), findsOneWidget);
    verify(() => navService.startRoute('route-1')).called(1);
  });

  testWidgets('si falla el calculo de ruta muestra el error del backend', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenThrow('No hay un camino caminable entre origen y destino');

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    expect(find.text('No hay un camino caminable entre origen y destino'), findsOneWidget);
  });

  testWidgets('al llegar al destino muestra el mensaje de llegada y cierra la ruta', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
    when(() => navService.finishRoute(any())).thenAnswer((_) async => _buildRoute());

    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      currentPosition: fakePosition(latitude: _destLat, longitude: _destLng, accuracy: 4.0),
    );

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    expect(find.text('¡Llegaste a tu destino!'), findsOneWidget);
    verify(() => navService.finishRoute('route-1')).called(1);
  });

  testWidgets('GPS poco preciso muestra el banner de advertencia', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());

    GeolocatorPlatform.instance = FakeGeolocatorPlatform(
      currentPosition: fakePosition(latitude: _originLat, longitude: _originLng, accuracy: 40.0),
    );

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    expect(find.textContaining('GPS poco preciso'), findsOneWidget);
  });

  testWidgets('el boton de cerrar termina la ruta y sale de la pantalla', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
    when(() => navService.finishRoute(any())).thenAnswer((_) async => _buildRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    verify(() => navService.finishRoute('route-1')).called(1);
  });

  testWidgets('el boton de brujula abre el dialogo de calibracion', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Calibrar brújula'), findsOneWidget);

    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  });

  testWidgets('el boton de nivelar horizonte muestra la confirmacion', (tester) async {
    when(() => navService.requestRoute(
          originLat: any(named: 'originLat'),
          originLng: any(named: 'originLng'),
          destinationLat: any(named: 'destinationLat'),
          destinationLng: any(named: 'destinationLng'),
          destinationName: any(named: 'destinationName'),
        )).thenAnswer((_) async => _buildRoute());
    when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());

    await tester.pumpWidget(wrap({
      'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
      'origin': {'lat': _originLat, 'lng': _originLng},
    }));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.center_focus_weak));
    await tester.pump();

    expect(find.text('Horizonte nivelado'), findsOneWidget);
  });

  group('avance por posicion', () {
    // Bajo carga (ej. corriendo junto a los demás archivos de test), un solo
    // pumpAndSettle a veces devuelve el control antes de que la cadena
    // async de _startNavigation() (requestRoute -> startRoute -> setState ->
    // _listenPosition) termine de asentarse; sin la suscripción activa
    // todavía, una posición emitida justo en ese momento se pierde en
    // silencio. Reintentar unas cuantas veces evita ese falso negativo sin
    // ocultar un fallo real (si el texto nunca aparece, el expect posterior
    // sigue fallando igual).
    Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxTries = 20}) async {
      for (var i = 0; i < maxTries && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('avanza de nodo, avisa el giro proactivo y llega al destino', (tester) async {
      final positionController = StreamController<Position>.broadcast();
      addTearDown(positionController.close);

      when(() => navService.requestRoute(
            originLat: any(named: 'originLat'),
            originLng: any(named: 'originLng'),
            destinationLat: any(named: 'destinationLat'),
            destinationLng: any(named: 'destinationLng'),
            destinationName: any(named: 'destinationName'),
          )).thenAnswer((_) async => _buildTurnRoute());
      when(() => navService.startRoute(any())).thenAnswer((_) async => _buildTurnRoute());
      when(() => navService.finishRoute(any())).thenAnswer((_) async => _buildTurnRoute());

      GeolocatorPlatform.instance = FakeGeolocatorPlatform(
        currentPosition: fakePosition(latitude: _originLat, longitude: _originLng),
        positionStream: positionController.stream,
      );

      await tester.pumpWidget(wrap({
        'destination': {'lat': _turnDestLat, 'lng': _turnDestLng, 'name': 'Biblioteca'},
        'origin': {'lat': _originLat, 'lng': _originLng},
      }));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Biblioteca'));
      expect(find.text('Biblioteca'), findsOneWidget, reason: 'la ruta debería haber terminado de cargar');

      // A 12 m del nodo de giro: entra en el radio de aviso (15 m) pero no
      // en el de avance (8 m) -> avisa el giro con anticipacion. El aviso
      // proactivo solo se habla por TTS (no hay texto en pantalla para
      // "en X metros, girá..."), así que se verifica contra el mock de voz.
      positionController.add(fakePosition(latitude: 9.930072, longitude: _midLng, accuracy: 4.0));
      await tester.pumpAndSettle();
      verify(() => tts.speak(any(that: contains('metros, girá a la derecha')))).called(1);

      // A 3 m del nodo de giro: entra en el radio de avance -> avanza de nodo.
      positionController.add(fakePosition(latitude: 9.930153, longitude: _midLng, accuracy: 4.0));
      await pumpUntilFound(tester, find.textContaining('destino'));
      expect(find.textContaining('destino'), findsWidgets);

      // Llega al destino final.
      positionController.add(fakePosition(latitude: _turnDestLat, longitude: _turnDestLng, accuracy: 4.0));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('¡Llegaste a tu destino!'), findsOneWidget);
      verify(() => navService.finishRoute('route-turn')).called(1);
    });

    testWidgets('recalcula si el usuario se aleja demasiado de la ruta', (tester) async {
      final positionController = StreamController<Position>.broadcast();
      addTearDown(positionController.close);

      when(() => navService.requestRoute(
            originLat: any(named: 'originLat'),
            originLng: any(named: 'originLng'),
            destinationLat: any(named: 'destinationLat'),
            destinationLng: any(named: 'destinationLng'),
            destinationName: any(named: 'destinationName'),
          )).thenAnswer((_) async => _buildRoute());
      when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
      when(() => navService.recalculateRoute(
            routeId: any(named: 'routeId'),
            currentLat: any(named: 'currentLat'),
            currentLng: any(named: 'currentLng'),
          )).thenAnswer((_) async => _buildRoute(id: 'route-2'));

      GeolocatorPlatform.instance = FakeGeolocatorPlatform(
        currentPosition: fakePosition(latitude: _originLat, longitude: _originLng),
        positionStream: positionController.stream,
      );

      await tester.pumpWidget(wrap({
        'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
        'origin': {'lat': _originLat, 'lng': _originLng},
      }));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Biblioteca'));

      // ~120 m al este del tramo origen-destino: lejos de ambos extremos.
      positionController.add(fakePosition(latitude: _originLat, longitude: -84.0790, accuracy: 4.0));
      await tester.pumpAndSettle();

      // Otra posición alejada, todavía dentro del cooldown de recálculo:
      // no debería disparar un segundo recalculateRoute.
      positionController.add(fakePosition(latitude: _originLat, longitude: -84.0791, accuracy: 4.0));
      await tester.pumpAndSettle();

      verify(() => navService.recalculateRoute(
            routeId: any(named: 'routeId'),
            currentLat: any(named: 'currentLat'),
            currentLng: any(named: 'currentLng'),
          )).called(1);
    });

    testWidgets('si falla el recalculo sigue guiando con la ruta anterior', (tester) async {
      final positionController = StreamController<Position>.broadcast();
      addTearDown(positionController.close);

      when(() => navService.requestRoute(
            originLat: any(named: 'originLat'),
            originLng: any(named: 'originLng'),
            destinationLat: any(named: 'destinationLat'),
            destinationLng: any(named: 'destinationLng'),
            destinationName: any(named: 'destinationName'),
          )).thenAnswer((_) async => _buildRoute());
      when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
      when(() => navService.recalculateRoute(
            routeId: any(named: 'routeId'),
            currentLat: any(named: 'currentLat'),
            currentLng: any(named: 'currentLng'),
          )).thenThrow('sin conexión');

      GeolocatorPlatform.instance = FakeGeolocatorPlatform(
        currentPosition: fakePosition(latitude: _originLat, longitude: _originLng),
        positionStream: positionController.stream,
      );

      await tester.pumpWidget(wrap({
        'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
        'origin': {'lat': _originLat, 'lng': _originLng},
      }));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Biblioteca'));

      positionController.add(fakePosition(latitude: _originLat, longitude: -84.0790, accuracy: 4.0));
      await tester.pumpAndSettle();

      expect(find.text('Biblioteca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('al recuperar buena precision de GPS recalcula de inmediato', (tester) async {
      final positionController = StreamController<Position>.broadcast();
      addTearDown(positionController.close);

      when(() => navService.requestRoute(
            originLat: any(named: 'originLat'),
            originLng: any(named: 'originLng'),
            destinationLat: any(named: 'destinationLat'),
            destinationLng: any(named: 'destinationLng'),
            destinationName: any(named: 'destinationName'),
          )).thenAnswer((_) async => _buildRoute());
      when(() => navService.startRoute(any())).thenAnswer((_) async => _buildRoute());
      when(() => navService.recalculateRoute(
            routeId: any(named: 'routeId'),
            currentLat: any(named: 'currentLat'),
            currentLng: any(named: 'currentLng'),
          )).thenAnswer((_) async => _buildRoute(id: 'route-2'));

      GeolocatorPlatform.instance = FakeGeolocatorPlatform(
        currentPosition: fakePosition(latitude: _originLat, longitude: _originLng),
        positionStream: positionController.stream,
      );

      await tester.pumpWidget(wrap({
        'destination': {'lat': _destLat, 'lng': _destLng, 'name': 'Biblioteca'},
        'origin': {'lat': _originLat, 'lng': _originLng},
      }));
      await tester.pumpAndSettle();
      await pumpUntilFound(tester, find.text('Biblioteca'));

      positionController.add(fakePosition(latitude: _originLat, longitude: _originLng, accuracy: 40.0));
      await tester.pumpAndSettle();
      positionController.add(fakePosition(latitude: _originLat, longitude: _originLng, accuracy: 5.0));
      await tester.pumpAndSettle();

      verify(() => navService.recalculateRoute(
            routeId: 'route-1',
            currentLat: any(named: 'currentLat'),
            currentLng: any(named: 'currentLng'),
          )).called(1);
    });
  });
}
