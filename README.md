# PathAR Frontend

Frontend móvil para el proyecto PathAR.

PathAR es un sistema inteligente de navegación peatonal que combina geolocalización, visión computacional, inteligencia artificial contextual y realidad aumentada para asistir a los usuarios dentro de entornos universitarios.

## Estructura del proyecto

El proyecto Flutter principal está en la carpeta `_2026_ra_fe/`.

- `_2026_ra_fe/main.dart`: punto de entrada de la aplicación.
- `_2026_ra_fe/app.dart`: configuración principal del `MaterialApp`.
- `_2026_ra_fe/lib/`: contiene la mayor parte de la lógica y la interfaz.

Estructura recomendada dentro de `lib/`:

```
lib/

├── core/
│   ├── constants/
│   ├── theme/
│   ├── routes/
│   └── services/
│
├── features/
│   │
│   ├── home/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   │
│   ├── navigation/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   │
│   └── settings/
│
├── shared/
│   ├── widgets/
│   └── models/
│
└── app.dart
```

## Tecnologías y dependencias

- Flutter
- Dart
- Provider
- Dio
- Flutter Dotenv
- Geolocator
- Permission Handler
- Camera
- Flutter TTS
- Sensors Plus
- Go Router

## Instalación

Desde la carpeta del proyecto Flutter:

```bash
cd _2026_ra_fe
flutter pub get
```

Si usas archivos de entorno, crea un archivo `.env` en `_2026_ra_fe/` y agrega las variables necesarias.

## Ejecución

Ejecuta la aplicación con:

```bash
cd _2026_ra_fe
flutter run
```

Para plataformas específicas:

```bash
flutter run -d windows
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

## Notas

- `app.dart` define la configuración básica de la aplicación y la ruta inicial.
- `main.dart` arranca la aplicación utilizando `PathARApp`.
- La carpeta `lib/` contiene el código modular por características y capas.
- El archivo `.env` se carga como recurso de la app si existe.

## Futuro

- Integración de navegación basada en `go_router`.
- Configuración de voz con `flutter_tts`.
- Desarrollo de la pantalla de navegación y ajustes.


# Endpoints
Registro  →  nombre + correo + contraseña  →  POST /api/auth/register
Login     →  correo + contraseña           →  POST /api/auth/login
