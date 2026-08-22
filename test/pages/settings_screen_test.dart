import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/routes/app_routes.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/pages/settings_screen.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService authService;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    authService = MockAuthService();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      routes: {
        AppRoutes.login: (_) => const Scaffold(body: Text('Login')),
      },
      home: child,
    );
  }

  testWidgets('muestra las preferencias cargadas del backend', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': false, 'walking_speed_mps': 1.6},
    );

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isFalse);
    expect(find.text('Rápido'), findsOneWidget);
  });

  testWidgets('si falla la carga, deja de mostrar el spinner', (tester) async {
    when(() => authService.getPreferences()).thenThrow('error');

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('tocar el switch actualiza las preferencias', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': true, 'walking_speed_mps': 1.3},
    );
    when(() => authService.updatePreferences(voiceGuidanceEnabled: any(named: 'voiceGuidanceEnabled')))
        .thenAnswer((_) async => {});

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump();

    verify(() => authService.updatePreferences(voiceGuidanceEnabled: false)).called(1);
  });

  testWidgets('si falla actualizar el switch, revierte el valor', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': true, 'walking_speed_mps': 1.3},
    );
    when(() => authService.updatePreferences(voiceGuidanceEnabled: any(named: 'voiceGuidanceEnabled')))
        .thenThrow('error');

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    await tester.pump();

    final switchTile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(switchTile.value, isTrue);
  });

  testWidgets('elegir una velocidad manda updatePreferences con walkingSpeedMps', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': true, 'walking_speed_mps': 1.3},
    );
    when(() => authService.updatePreferences(walkingSpeedMps: any(named: 'walkingSpeedMps')))
        .thenAnswer((_) async => {});

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Rápido'));
    await tester.pump();
    await tester.pump();

    verify(() => authService.updatePreferences(walkingSpeedMps: 1.6)).called(1);
  });

  testWidgets('cerrar sesion: cancelar no llama a logout', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': true, 'walking_speed_mps': 1.3},
    );

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.logout());
  });

  testWidgets('cerrar sesion: confirmar llama a logout y navega a login', (tester) async {
    when(() => authService.getPreferences()).thenAnswer(
      (_) async => {'voice_guidance_enabled': true, 'walking_speed_mps': 1.3},
    );
    when(() => authService.logout()).thenAnswer((_) async {});

    await tester.pumpWidget(wrap(SettingsScreen(authService: authService)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    verify(() => authService.logout()).called(1);
    expect(find.text('Login'), findsOneWidget);
  });
}
