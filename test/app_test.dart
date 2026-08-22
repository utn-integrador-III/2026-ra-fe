import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:pathar_fe/app.dart';
import 'package:pathar_fe/core/routes/app_routes.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:sensors_plus_platform_interface/sensors_plus_platform_interface.dart';

import 'helpers/fake_geolocator.dart';
import 'helpers/fake_plugins.dart';

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'API_URL=http://127.0.0.1:9');
    GeolocatorPlatform.instance = FakeGeolocatorPlatform();
    CameraPlatform.instance = FakeCameraPlatform();
    PermissionHandlerPlatform.instance = FakePermissionHandlerPlatform();
    SensorsPlatform.instance = FakeSensorsPlatform();
  });

  testWidgets('arranca en la pantalla de registro', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    expect(find.text('Crear cuenta'), findsWidgets);
  });

  testWidgets('todas las rutas nombradas estan registradas', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final routeNames = [
      AppRoutes.register,
      AppRoutes.login,
      AppRoutes.home,
      AppRoutes.navigation,
      AppRoutes.settings,
      AppRoutes.search,
      AppRoutes.navigationHistory,
    ];

    for (final name in routeNames) {
      expect(app.routes!.containsKey(name), isTrue, reason: 'falta la ruta $name');
    }
  });

  test('el titulo de la app es PathAR', () {
    expect(AppRoutes.appTitle, 'PathAR');
  });

  testWidgets('navega a cada ruta nombrada sin errores', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    for (final entry in <String, Object?>{
      AppRoutes.login: null,
      AppRoutes.home: null,
      AppRoutes.settings: null,
      AppRoutes.search: null,
      AppRoutes.navigationHistory: null,
      AppRoutes.navigation: {
        'destination': {'lat': 9.93, 'lng': -84.08, 'name': 'Test'},
        'origin': {'lat': 9.93, 'lng': -84.08},
      },
    }.entries) {
      navigator.pushNamed(entry.key, arguments: entry.value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull, reason: 'ruta ${entry.key} tiró un error');
      navigator.pop();
      await tester.pump(const Duration(seconds: 3));
    }
  });
}
