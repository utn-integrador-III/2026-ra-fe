# 🔌 Cómo conectar el frontend al backend (Local WSL vs Ngrok)

Este proyecto se puede apuntar a dos tipos de backend distintos. Todo el cambio
es del lado del **frontend** — el backend (`app/main.py`) ya tiene CORS abierto
(`allow_origins=["*"]`), así que **no hace falta tocar código del backend** en
ninguno de los dos casos, solo cómo lo levantás/exponés.

---

## Modo 1 — Local por WiFi (WSL + IP de red)

Se usa cuando el backend corre en tu propia PC (dentro de WSL) y el celular
está en la **misma red WiFi**.

1. En WSL, levantá el servidor escuchando en todas las interfaces:
   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```
2. En Windows, corré `update_network.bat` **como Administrador**. Este script:
   - Crea un `netsh portproxy` de tu IP de Windows → IP interna de WSL, puerto 8000.
   - Abre el puerto 8000 en el Firewall de Windows.
   - Sobreescribe `.env` automáticamente con `API_URL=http://TU_IP_WIFI:8000`.
3. Listo — no hay que tocar código. El `.bat` ya deja el `.env` apuntando bien.

> Hay que volver a correr el `.bat` cada vez que cambiás de red WiFi o WSL
> asigna una IP interna distinta (pasa seguido al reiniciar la PC).

---

## Modo 2 — Remoto con ngrok (backend en otra PC, ej. la de Pablo)

Se usa cuando el backend corre en una máquina que no está en tu misma red
(otra casa, otra WiFi) y se expone por un túnel ngrok. Quien hostea el backend
sigue los pasos de `INSTRUCCIONES_PABLO.txt` (repo `2026-ra-api`) y te pasa una
URL tipo `https://algo-random-1234.ngrok-free.app`.

Cuando tengas esa URL, hay que hacer **2 cambios** en el frontend:

### 1. Actualizar `.env`

```env
API_URL=https://algo-random-1234.ngrok-free.app
```

(sin barra al final)

### 2. Agregar el header `ngrok-skip-browser-warning`

El plan gratuito de ngrok le mete una página de advertencia HTML a las
respuestas si no ves este header — y ahí la app recibe HTML en vez de JSON y
todo truena en silencio. Hay que agregar `'ngrok-skip-browser-warning': 'true'`
al `headers` de **cada** cliente Dio del proyecto. Son 6 lugares:

| Archivo | Dónde |
|---|---|
| `lib/core/services/api_service.dart` | `headers` del único `Dio()` |
| `lib/core/services/auth_service.dart` | `headers` del único `Dio()` |
| `lib/core/services/navigation_service.dart` | `headers` del único `Dio()` |
| `lib/features/search/screens/search_screen.dart` | `Options(headers: ...)` dentro de `_loadUniversityLocations()` |
| `lib/features/search/screens/search_screen.dart` | `Dio(BaseOptions(...))` dentro de `_selectDestination()` |
| `lib/features/profile/screens/profile_screen.dart` | `Dio(BaseOptions(...))` dentro de `_loadData()` |

Ejemplo de cómo queda un bloque (mismo patrón en los 6):

```dart
headers: {
  'Content-Type': 'application/json',
  'ngrok-skip-browser-warning': 'true',
},
```

> El `_dio` de `search_screen.dart` que pega a Nominatim (línea ~26, con
> `User-Agent: PathAR/1.0`) **no** necesita el header — nunca pasa por ngrok.

### 3. (Solo si vas a entrar al panel admin desde el navegador)

La primera vez que abrís `https://tu-url.ngrok-free.app/admin/` en un
navegador te va a salir la pantalla de advertencia de ngrok ("estás por
visitar..."). Hacé clic en **"Visit Site"** una vez — no vuelve a salir para
ese navegador. Esto es solo del navegador, no afecta a la app.

---

## Volver de ngrok a local

1. Reemplazá el `.env` con tu IP local (o simplemente corré `update_network.bat`
   de nuevo, que lo hace automático).
2. Sacá el header `'ngrok-skip-browser-warning': 'true'` de los 6 lugares de
   arriba (no rompe nada si lo dejás, pero no tiene sentido mandarlo a un
   servidor que no es ngrok).

---

## Nota sobre la URL de ngrok

La URL gratuita de ngrok **cambia cada vez que se reinicia el túnel** (a menos
que la cuenta tenga un dominio fijo configurado en el dashboard). Cuando eso
pase, solo hay que repetir el paso 1 (actualizar `.env`) — el header del paso 2
no hace falta tocarlo de nuevo.
