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
| Flutter TTS | ^4.2.5 | Text-to-Speech (instrucciones de voz) |
| Permission Handler | ^12.0.3 | Permisos del sistema |
| Flutter Compass | ^0.8.1 | Rumbo del dispositivo (brújula) para el AR por sensores |
| Sensors Plus | ^7.0.0 | Sensores de movimiento |

---

## ⚙️ Instalación

```bash
# 1. Clonar el repositorio
git clone <repo-url>
cd 2026-ra-fe

# 2. Instalar dependencias
flutter pub get

# 3. Configurar variables de entorno
# Crear archivo .env en la raíz del proyecto:
echo "API_URL=http://TU_IP_LOCAL:8000" > .env

# 4. Colocar google-services.json
# Descargar de Firebase Console y colocar en:
# android/app/google-services.json

# 5. Correr la app
flutter run
```

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
│   ├── constants/          # Constantes globales
│   ├── routes/
│   │   └── app_routes.dart # Definición de rutas
│   ├── services/
│   │   └── auth_service.dart # Llamadas a la API
│   └── theme/
│       └── app_theme.dart  # Tema global
│
├── features/
│   ├── auth/
│   │   └── screens/
│   │       ├── auth_tabs_screen.dart   # Contenedor con tabs
│   │       ├── login_screen.dart       # Pantalla de login
│   │       └── register_screen.dart    # Pantalla de registro
│   │
│   ├── search/
│   │   └── screens/
│   │       └── search_screen.dart      # Mapa + búsqueda de lugares
│   │
│   └── profile/
│       └── screens/
│           └── profile_screen.dart     # Perfil del usuario
│
├── shared/
│   └── widgets/            # Widgets reutilizables
│
├── app.dart                # MaterialApp + rutas
└── main.dart               # Punto de entrada + Firebase init
```

---

## 🗺️ Rutas de navegación

| Ruta | Widget | Descripción |
|---|---|---|
| `/register` | `AuthTabsScreen(initialIndex: 0)` | Pantalla inicial — Crear cuenta |
| `/login` | `AuthTabsScreen(initialIndex: 1)` | Iniciar sesión |
| `/home` | `ProfileScreen` | Perfil del usuario |
| `/search` | `SearchScreen` | Búsqueda de lugares con mapa |
| `/navigation` | `NavigationScreen` | Pantalla de cámara AR |

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
- Header con nombre, correo y badge del usuario (datos reales del backend)
- Stats: rutas realizadas, favoritos, km promedio
- Lista de **recientes** desde `GET /api/history/places`
- Lista de **favoritos** desde `GET /api/favorites`
- Bottom nav con 3 tabs: Buscar / Navegar / Perfil

Conecta con:
- `GET /api/auth/profile`
- `GET /api/history/places`
- `GET /api/favorites`

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
- Al seleccionar un lugar → guarda en historial + navega a `/navigation`

Conecta con:
- `POST /api/history/places` (al seleccionar destino)
- Nominatim API (OpenStreetMap) para búsqueda de lugares

---

### 📷 Navegación — `navigation_screen.dart`
- Vista de cámara en tiempo real como fondo de la navegación AR
- Ruta real pedida al backend (`/api/navigation/route`), no una línea recta al destino
- Flecha guía (`ArArrowOverlay`) que rota según el rumbo hacia el siguiente punto de la ruta, comparado contra la brújula del teléfono
- Línea/alfombra azul (`ArPathOverlay`) dibujada sobre el camino real, solo visible cuando estás lo bastante cerca de una acera conocida
- Suavizado de GPS y de brújula (evita saltos por ruido de sensores), con aviso visible cuando la precisión de alguno de los dos no es confiable (típico en interiores)
- Recalculo automático de ruta si te alejás del camino, o si el GPS estaba poco confiable y de golpe mejora
- Instrucciones por voz (`flutter_tts`) y avisos de giro con anticipación (FR-12/FR-13)
- Botón de calibración de brújula (patrón en 8), igual que Google Maps
- Integración YOLOv8 para detección de obstáculos *(pendiente)*
- Integración de segmentación de aceras (SegFormer u otro modelo liviano) *(pendiente)*

---

## 🔑 AuthService — Métodos disponibles

```dart
// Registro manual
await authService.register(name, email, password);

// Login manual
await authService.login(email, password);

// Login con Google (Firebase)
await authService.loginWithGoogle();

// Obtener perfil del usuario actual
await authService.getProfile();

// Obtener JWT guardado
await authService.getToken();

// Cerrar sesión
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
```

---

## 🧪 Pruebas

```bash
flutter test
```

Por ahora cubre los modelos de navegación (`RoutePoint`, `RouteStep`,
`NavRoute.fromJson`) en `test/models/`. Se corre automáticamente junto con
`flutter analyze` en GitHub Actions en cada push/PR — ver
`.github/workflows/frontend-tests.yml`.

---

## 🐛 Problemas conocidos

| Problema | Estado | Solución |
|---|---|---|
| `debugPrint` no visible en HyperOS | 🔍 Investigando | Usar `adb logcat` filtrando por tag |
| IP del backend cambia al cambiar WiFi | ✅ Mitigado | Usar variable `API_URL` en `.env` |

> **Google Sign-In (resuelto):** no era un problema de permisos de MIUI. Eran dos bugs reales: el botón en `auth_tabs_screen.dart` tenía la lógica de Google comentada (no llamaba a nada), y el backend verificaba el token con el endpoint equivocado (esperaba un token OAuth de Google, pero se manda un Firebase ID Token). Ver la sección de Firebase más abajo si a alguien más le pasa esto en otra máquina.

---

## 🚀 Desarrollo futuro

```
feature/yolo-integration  → Detección de obstáculos en tiempo real (on-device)
feature/sidewalk-segmentation → Detección visual de aceras para alinear mejor la línea AR
feature/offline-maps      → Caché de tiles para uso sin internet
feature/favorites-crud    → Agregar/editar/eliminar favoritos (hoy el backend los deja vacíos)
feature/push-notifications → Alertas y notificaciones
```

Ya no están en esta lista porque ya están implementados: AR por sensores con
flecha + línea de camino, instrucciones por voz, panel de administración
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