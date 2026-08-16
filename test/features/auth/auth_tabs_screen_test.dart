import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pathar_fe/core/services/auth_service.dart';
import 'package:pathar_fe/features/auth/screens/auth_tabs_screen.dart';

class MockAuthService extends Mock implements AuthService {}

void _tapElevated(WidgetTester tester, String text) {
  tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, text)).onPressed!();
}

void _tapOutlined(WidgetTester tester, String text) {
  tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, text)).onPressed!();
}

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
        '/home': (_) => const Scaffold(body: Text('Home')),
      },
      home: child,
    );
  }

  testWidgets('empieza en Crear cuenta cuando initialIndex es 0', (tester) async {
    await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 0, authService: authService)));
    await tester.pumpAndSettle();

    expect(find.text('Nombre'), findsOneWidget);
  });

  testWidgets('empieza en Iniciar sesion cuando initialIndex es 1', (tester) async {
    await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 1, authService: authService)));
    await tester.pumpAndSettle();

    expect(find.text('Nombre'), findsNothing);
    expect(find.text('Iniciar sesión'), findsWidgets);
  });

  testWidgets('tocar la pestaña de login cambia el contenido', (tester) async {
    await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 0, authService: authService)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre'), findsNothing);
  });

  group('Registro', () {
    Future<void> pumpRegister(WidgetTester tester) async {
      await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 0, authService: authService)));
      await tester.pumpAndSettle();
    }

    testWidgets('campos vacios muestra snackbar', (tester) async {
      await pumpRegister(tester);

      _tapElevated(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('Por favor completa todos los campos'), findsOneWidget);
      verifyNever(() => authService.register(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          ));
    });

    testWidgets('contraseñas distintas muestra snackbar', (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      final passwordFields = find.byType(TextField);
      await tester.enterText(passwordFields.at(2), '123456');
      await tester.enterText(passwordFields.at(3), '654321');

      _tapElevated(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('contraseña corta muestra snackbar', (tester) async {
      await pumpRegister(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      final passwordFields = find.byType(TextField);
      await tester.enterText(passwordFields.at(2), '123');
      await tester.enterText(passwordFields.at(3), '123');

      _tapElevated(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);
    });

    testWidgets('registro exitoso llama a register y navega a home', (tester) async {
      when(() => authService.register(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => {'access_token': 'tok'});

      await pumpRegister(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      final passwordFields = find.byType(TextField);
      await tester.enterText(passwordFields.at(2), '123456');
      await tester.enterText(passwordFields.at(3), '123456');

      _tapElevated(tester, 'Crear cuenta');
      await tester.pumpAndSettle();

      verify(() => authService.register(name: 'Ana', email: 'ana@test.com', password: '123456')).called(1);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('error del backend se muestra en snackbar', (tester) async {
      when(() => authService.register(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow('Ese correo ya está registrado');

      await pumpRegister(tester);

      await tester.enterText(find.widgetWithText(TextField, 'Tu nombre'), 'Ana');
      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      final passwordFields = find.byType(TextField);
      await tester.enterText(passwordFields.at(2), '123456');
      await tester.enterText(passwordFields.at(3), '123456');

      _tapElevated(tester, 'Crear cuenta');
      await tester.pump();

      expect(find.text('Ese correo ya está registrado'), findsOneWidget);
    });
  });

  group('Login', () {
    Future<void> pumpLogin(WidgetTester tester) async {
      await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 1, authService: authService)));
      await tester.pumpAndSettle();
    }

    testWidgets('campos vacios muestra snackbar', (tester) async {
      await pumpLogin(tester);

      _tapElevated(tester, 'Iniciar sesión');
      await tester.pump();

      expect(find.text('Por favor completa todos los campos'), findsOneWidget);
    });

    testWidgets('login exitoso navega a home', (tester) async {
      when(() => authService.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => {'access_token': 'tok'});

      await pumpLogin(tester);

      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      await tester.enterText(find.byType(TextField).at(1), '123456');

      _tapElevated(tester, 'Iniciar sesión');
      await tester.pumpAndSettle();

      verify(() => authService.login(email: 'ana@test.com', password: '123456')).called(1);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('login fallido muestra el error del backend', (tester) async {
      when(() => authService.login(email: any(named: 'email'), password: any(named: 'password')))
          .thenThrow('Credenciales inválidas');

      await pumpLogin(tester);

      await tester.enterText(find.widgetWithText(TextField, 'correo@ejemplo.com'), 'ana@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'mala');

      _tapElevated(tester, 'Iniciar sesión');
      await tester.pump();

      expect(find.text('Credenciales inválidas'), findsOneWidget);
    });

    testWidgets('boton de Google llama a loginWithGoogle y navega a home', (tester) async {
      when(() => authService.loginWithGoogle()).thenAnswer((_) async => {'access_token': 'tok'});

      await pumpLogin(tester);

      _tapOutlined(tester, 'Continuar con Google');
      await tester.pumpAndSettle();

      verify(() => authService.loginWithGoogle()).called(1);
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('error de Google se muestra en snackbar', (tester) async {
      when(() => authService.loginWithGoogle()).thenThrow('Error Firebase: cancelado');

      await pumpLogin(tester);

      _tapOutlined(tester, 'Continuar con Google');
      await tester.pump();

      expect(find.text('Error Firebase: cancelado'), findsOneWidget);
    });

    testWidgets('tocar el icono de ojo alterna mostrar la contraseña', (tester) async {
      await pumpLogin(tester);

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('el link de olvidaste tu contraseña no tira error', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('Registro - contraseñas', () {
    testWidgets('los dos iconos de ojo alternan cada campo de forma independiente', (tester) async {
      await tester.pumpWidget(wrap(AuthTabsScreen(initialIndex: 0, authService: authService)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2));

      await tester.ensureVisible(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.ensureVisible(find.byIcon(Icons.visibility_off_outlined));
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });
  });
}
