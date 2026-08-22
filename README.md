<<<<<<< HEAD
# 📱 PathAR — Frontend Mobile

Aplicación móvil Flutter para el sistema inteligente de navegación peatonal con AR e IA.

---

## 🛠️ Tecnologías

| Tecnología | Versión | Uso |
|---|---|---|
| Flutter | SDK ^3.11.5 | Framework móvil |
| Dart | ^3.11.5 | Lenguaje |
| Firebase Core | ^3.6.0 | Inicialización Firebase |
| Firebase Auth | ^5.3.1 | Autenticación |
| Google Sign-In | ^6.2.1 | OAuth con Google |
| Dio | ^5.9.2 | HTTP client |
| Flutter Map | ^7.0.2 | Mapas OpenStreetMap |
| Latlong2 | ^0.9.1 | Coordenadas GPS |
| Geolocator | ^14.0.2 | Ubicación del dispositivo |
| Flutter Secure Storage | ^9.0.0 | Almacenamiento seguro de tokens |
| Flutter Dotenv | ^6.0.1 | Variables de entorno |
| Provider | ^6.1.5 | Gestión de estado |
| Go Router | ^17.3.0 | Navegación |
| Camera | ^0.12.0 | Acceso a cámara para el overlay AR |
| Flutter TTS | ^4.2.5 | Text-to-Speech (instrucciones de voz, con cola de prioridades) |
| Permission Handler | ^12.0.3 | Permisos del sistema |
| Flutter Compass | ^0.8.1 | Rumbo del dispositivo (brújula) para el AR por sensores |
| Sensors Plus | ^7.0.0 | Acelerómetro — inclinación del teléfono para la proyección de perspectiva del AR |
| Google ML Kit Object Detection | ^0.15.0 | Detección de obstáculos en tiempo real, 100% on-device |
| Google ML Kit Image Labeling | ^0.14.2 | Reconocimiento de qué hay alrededor (piso/vereda, objetos) |
| Mocktail *(dev)* | ^1.0.4 | Mocks para las pruebas unitarias |

---

## ⚙️ Instalación

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd 2026-ra-fe

# 2. Instalar dependencias
flutter pub get

# 3. Configurar variables de entorno
# El .env ya viene commiteado — solo editá la IP para que apunte a tu backend:
# API_URL=http://TU_IP_LOCAL:8000

# 4. Correr la app
flutter run
```

> `google-services.json` y `firebase_options.dart` ya están en el repo, no
> hace falta descargar nada de Firebase para compilar. Pero el login con
> Google no te va a andar hasta que hagas un paso extra — ver la sección
> "Si sos nuevo en el proyecto" más abajo.

---

## 🔧 Variables de entorno (`.env`)

```env
API_URL=http://192.168.X.X:8000
```

> ⚠️ La IP cambia cada vez que cambiás de red WiFi. Actualizala con `ip a` en WSL.

---

## 📁 Estructura del proyecto

```
lib/
├── core/
│   ├── routes/
│   │   └── app_routes.dart       # Definición de rutas
│   ├── services/
│   │   ├── auth_service.dart       # Login, perfil, favoritos, preferencias
│   │   ├── navigation_service.dart # Cálculo/ciclo de vida de rutas
│   │   ├── location_service.dart   # GPS de alta precisión (varias lecturas)
│   │   └── perception_service.dart # IA: ML Kit (obstáculos + entorno)
│   └── theme/
│       └── app_theme.dart        # Tema global
│
├── features/
│   ├── auth/screens/
│   │   └── auth_tabs_screen.dart # Único punto de entrada: tabs Login/Registro
│   ├── search/screens/
│   │   └── search_screen.dart    # Mapa + búsqueda de lugares
│   ├── profile/screens/
│   │   └── profile_screen.dart   # Perfil, favoritos, historial
│   ├── history/screens/
│   │   └── navigation_history_screen.dart # Historial de rutas navegadas
│   └── navigation/
│       ├── models/
│       │   ├── route_models.dart # NavRoute, RoutePoint, RouteStep
│       │   └── obstacle.dart     # Clasificación de obstáculos detectados
│       └── widgets/
│           ├── ar_arrow_overlay.dart       # Flecha guía
│           ├── ar_path_overlay.dart        # Línea/alfombra azul con perspectiva real
│           └── obstacle_boxes_overlay.dart # Cajas de la IA sobre la cámara
│
├── pages/
│   ├── navigation_screen.dart    # Pantalla de cámara AR (la más grande)
│   └── settings_screen.dart      # Preferencias + cerrar sesión
│
├── app.dart                # MaterialApp + rutas
└── main.dart               # Punto de entrada + Firebase init
```

> Nota: `login_screen.dart`, `register_screen.dart` y la carpeta `shared/`
> (scaffold inicial de Flutter) se borraron — eran código muerto, nunca se
> importaban desde ningún lado. Toda la lógica de login/registro vive en
> `auth_tabs_screen.dart`.

---

## 🗺️ Rutas de navegación

| Ruta | Widget | Descripción |
|---|---|---|
| `/register` | `AuthTabsScreen(initialIndex: 0)` | Pantalla inicial — Crear cuenta |
| `/login` | `AuthTabsScreen(initialIndex: 1)` | Iniciar sesión |
| `/home` | `ProfileScreen` | Perfil del usuario |
| `/search` | `SearchScreen` | Búsqueda de lugares con mapa |
| `/navigation` | `NavigationScreen` | Pantalla de cámara AR |
| `/settings` | `SettingsScreen` | Preferencias (voz, velocidad al caminar) + cerrar sesión |
| `/navigation-history` | `NavigationHistoryScreen` | Historial de rutas navegadas |

---

## 📲 Pantallas implementadas

### 🔐 Auth — `auth_tabs_screen.dart`
Contenedor con `TabBar` segmentado que alterna entre:
- **Crear cuenta:** nombre + correo + contraseña + confirmar contraseña
- **Iniciar sesión:** correo + contraseña + Google Sign-In

Conecta con:
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/google` (vía Firebase)

---

### 👤 Perfil — `profile_screen.dart`
- Header con nombre, correo y badge del usuario (datos reales del backend), con edición del nombre
- Stats: rutas realizadas, favoritos, km promedio
- Lista de **recientes** desde `GET /api/history/places`
- Lista de **favoritos**, con agregar (desde Búsqueda) y borrar
- Sección de **historial de rutas** con acceso a la pantalla completa
- Ícono de ajustes → `/settings`
- Bottom nav con 3 tabs: Buscar / Navegar / Perfil

Conecta con:
- `GET/PUT /api/auth/profile`
- `GET /api/history/places`
- `GET/POST/DELETE /api/favorites`
- `GET /api/navigation/history`

---

### ⚙️ Preferencias — `settings_screen.dart`
- Activar/desactivar instrucciones por voz (afecta en vivo a la navegación)
- Velocidad al caminar (Lento/Normal/Rápido) — se usa para calcular la duración estimada de la ruta
- Botón de **cerrar sesión**, con confirmación

Conecta con:
- `GET/PUT /api/preferences`

---

### 🕓 Historial de navegación — `navigation_history_screen.dart`
Lista completa de rutas navegadas, con destino, distancia, fecha y estado
(Calculada / En curso / Finalizada / Cancelada).

Conecta con:
- `GET /api/navigation/history`

---

### 🗺️ Búsqueda — `search_screen.dart`
- Mapa OpenStreetMap a pantalla completa con marcador de ubicación actual
- Panel inferior **plegable con 3 estados fijos** (Instagram-style):
  - Colapsado: solo se ve el handle
  - Medio: barra de búsqueda + categorías
  - Expandido: resultados completos
- Búsqueda por texto vía **Nominatim API**
- Búsqueda por categorías (Cafés, Comida, Tiendas, Turismo, Transporte, Salud)
- Marcadores de lugares en el mapa
- Botón de ❤️ en cada resultado para agregarlo a favoritos
- Al seleccionar un lugar → guarda en historial + navega a `/navigation`

Conecta con:
- `POST /api/history/places` (al seleccionar destino)
- `POST /api/favorites` (al tocar ❤️)
- Nominatim API (OpenStreetMap) para búsqueda de lugares

---

### 📷 Navegación — `navigation_screen.dart`
- Vista de cámara en tiempo real como fondo de la navegación AR
- Ruta real pedida al backend (`/api/navigation/route`), no una línea recta al destino
- Flecha guía (`ArArrowOverlay`) que rota según el rumbo hacia el siguiente punto de la ruta, comparado contra la brújula del teléfono
- Línea/alfombra azul (`ArPathOverlay`), con **proyección de perspectiva real** (altura de cámara + inclinación del teléfono, leída del acelerómetro) en vez de una posición fija en pantalla — se pega al piso real y se curva suavemente en los giros. Botón de calibración propio ("nivelar horizonte") además del de brújula.
- Solo se dibuja cuando estás cerca de una acera conocida **y** la IA reconoció una superficie caminable en cámara en ese momento (no solo por GPS)
- **IA de percepción, 100% on-device (ML Kit, sin conexión a internet):**
  - Detección de obstáculos en tiempo real (`google_mlkit_object_detection`) — si algo aparece centrado y cerca en el camino, alerta por voz, tiñe la línea de rojo y dibuja las cajas detectadas sobre la cámara
  - Reconocimiento del entorno (`google_mlkit_image_labeling`) — narra por voz cada tanto qué hay alrededor
- **Cola de voz con prioridades** (`ambient` < `navigation` < `critical`): una alerta de obstáculo corta cualquier otra cosa; la narración del entorno nunca interrumpe ni tapa una instrucción de giro real
- Suavizado de GPS, brújula y del acelerómetro (evita saltos por ruido de sensores), con avisos visibles cuando la precisión de alguno no es confiable (típico en interiores)
- Recalculo automático de ruta si te alejás del camino, o si el GPS estaba poco confiable y de golpe mejora
- Avisos de giro con anticipación por voz (FR-12/FR-13)
- Botón de calibración de brújula (patrón en 8), igual que Google Maps

---

## 🔑 AuthService — Métodos disponibles

```dart
// Registro manual
await authService.register(name: name, email: email, password: password);

// Login manual
await authService.login(email: email, password: password);

// Login con Google (Firebase)
await authService.loginWithGoogle();

// Perfil
await authService.getProfile();
await authService.updateProfile(name: name);

// Preferencias
await authService.getPreferences();
await authService.updatePreferences(voiceGuidanceEnabled: true, walkingSpeedMps: 1.3);

// Favoritos
await authService.getFavorites();
await authService.addFavorite(name: name, latitude: lat, longitude: lng);
await authService.deleteFavorite(id);

// Obtener JWT guardado
await authService.getToken();

// Cerrar sesión (Google + Firebase + token local)
await authService.logout();
```

---

## 🔒 Seguridad

- JWT guardado con **Flutter Secure Storage** (KeyStore en Android)
- Google Sign-In via **Firebase Authentication**
- Firebase ID Token verificado en el backend
- Variables sensibles en `.env` (no en el código)

---

## 📍 Permisos Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

---

## 🧪 Pruebas

```bash
flutter test --coverage
```

**80%+ de cobertura real** (líneas de código ejecutadas ÷ líneas de código,
mismo criterio que `pytest-cov` en el backend — no cuenta comentarios ni
líneas en blanco). Modelos, servicios (con `mocktail`, sin pegarle a la red
real) y la mayoría de las pantallas, incluida la de navegación AR (cámara,
GPS, brújula, sensores y permisos mockeados vía la interfaz de cada
plugin). `main.dart` y `firebase_options.dart` (generado) quedan afuera del
cálculo, igual que se excluye boilerplate de entrada en proyectos Python.

Se corre automáticamente junto con `flutter analyze` en GitHub Actions en
cada push/PR, y **el job falla si la cobertura baja del 80%** — ver
`.github/workflows/frontend-tests.yml`.

---

## 🐛 Problemas conocidos

| Problema | Estado | Solución |
|---|---|---|
| `debugPrint` no visible en HyperOS | 🔍 Investigando | Usar `adb logcat` filtrando por tag |
| IP del backend cambia al cambiar WiFi | ✅ Mitigado | Usar variable `API_URL` en `.env` (hay que recompilar/reinstalar la app después de cambiarla, no alcanza con hot reload) |
| El celular no conecta al backend aunque esté en la misma WiFi | 🔍 Depende del router | Puede ser "aislamiento de clientes" (AP/client isolation) bloqueando que los dispositivos de la red se vean entre sí — revisar esa opción en el router, o probar con el hotspot del celular para confirmar el diagnóstico |

> **Google Sign-In (resuelto):** no era un problema de permisos de MIUI. Eran dos bugs reales: el botón en `auth_tabs_screen.dart` tenía la lógica de Google comentada (no llamaba a nada), y el backend verificaba el token con el endpoint equivocado (esperaba un token OAuth de Google, pero se manda un Firebase ID Token). Ver la sección de Firebase más abajo si a alguien más le pasa esto en otra máquina.

---

## 🚀 Desarrollo futuro

```
feature/offline-maps      → Caché de tiles para uso sin internet
feature/push-notifications → Alertas y notificaciones
feature/ar-coverage       → Subir la cobertura de tests de navigation_screen.dart
                            y search_screen.dart (hoy ~63%, son las pantallas
                            más grandes y las más atadas a plugins de hardware)
```

Ya no están en esta lista porque ya están implementados: AR por sensores con
flecha + línea de camino con perspectiva real, instrucciones por voz con cola
de prioridades, detección de obstáculos y reconocimiento del entorno con IA
on-device (ML Kit — se evaluó YOLOv8/SegFormer pero son demasiado pesados
para tiempo real en celular, ver commits de investigación), favoritos y
preferencias con CRUD real, historial de navegación, panel de administración
(web, ver `2026-ra-api`).

---

## 📡 APIs externas utilizadas

| API | URL | Uso |
|---|---|---|
| OpenStreetMap Tiles | `tile.openstreetmap.org` | Tiles del mapa |
| Nominatim | `nominatim.openstreetmap.org/search` | Búsqueda de lugares por texto/categoría |
| Overpass API | `overpass-api.de/api/interpreter` | Búsqueda avanzada OSM (no usada actualmente) |
| Firebase Auth | Google Cloud | Verificación Google Sign-In |

---

## 👥 Equipo

| Integrante | Rol |
|---|---|
| Douglas | Frontend (Flutter) |
| Ahian | Backend (FastAPI) |
| Otros | Backend / BD |

---

## 📦 Firebase

- **Proyecto:** `pathar-e3fc0`
- **Package name:** `com.example.u_2026_ra_fe`
- **SHA-1 debug registrado:** `9C:24:41:27:31:09:4A:8C:D3:57:44:BB:9A:66:5B:CE:C4:BA:2B:60`
<<<<<<< HEAD
- **Google services file:** `android/app/google-services.json`
=======
# 2026-ra-fe
>>>>>>> parent of 7fa0aec (Merge pull request #3 from utn-integrador-III/main)
=======
- **Google services file:** `android/app/google-services.json` (ya está en el repo)

### ⚠️ Si sos nuevo en el proyecto: Google Sign-In no te va a andar hasta que hagas esto

`google-services.json`, `firebase_options.dart` y `.env` ya están commiteados, así que con clonar + `flutter pub get` alcanza para **compilar** la app. Pero **el login con Google va a fallar** (error `ApiException: 10` / `DEVELOPER_ERROR`) porque el SHA-1 registrado arriba es el de la keystore de debug de otra máquina. Android genera una keystore de debug distinta y automática en cada PC, así que necesitás:

1. **Pedir acceso al proyecto de Firebase** (`pathar-e3fc0`) — hablá con Ahian para que te agregue desde la consola de Firebase (⚙️ Configuración del proyecto → Usuarios y permisos).
2. **Sacar el SHA-1 de tu propia keystore de debug:**
   ```bash
   # Windows
   keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android

   # Linux/Mac
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
3. En Firebase Console → ⚙️ Configuración del proyecto → tu app Android → **Agregar huella digital**, pegar el SHA-1 (y de paso el SHA-256) que te dio el comando anterior.
4. Recompilar con `flutter run`. No hace falta descargar `google-services.json` de nuevo — el archivo del repo ya sirve para todos, solo cambia el SHA-1 registrado en la consola.

> Nota: esto solo afecta al login con Google. El registro/login manual (correo + contraseña) funciona sin este paso.
>>>>>>> 6093346 (Merge pull request #7 from utn-integrador-III/Test-Google-Login-and-Overall-APP)
