# Frontend

Aplicación Flutter compilada exclusivamente a web, servida en producción como build estático desde Vercel. Consume el backend de EcoBytes por HTTP y no mantiene lógica de agregación propia: el estado de cada comuna (verde/amarillo/rojo/gris) llega ya calculado desde el servidor.

## Stack

| Pieza | Tecnología | Uso |
| --- | --- | --- |
| Framework | Flutter (Dart) | Target de compilación único: web |
| Navegación | `go_router` | Rutas declarativas con parámetros de path |
| Estado | `provider` (`ChangeNotifier`) | Un provider por dominio de datos, sin un store global único |
| Cliente HTTP | `http` | Consumo del backend |
| Mapa | `flutter_map` + `latlong2` | Renderizado de los polígonos de comuna sobre un mapa interactivo |
| Gráficos | `fl_chart` | Serie de PM2.5 de las últimas 24 horas en el detalle de comuna |
| Tipografía | `google_fonts` | — |

## Estructura

```
Frontend/ecobytes/lib/
├── main.dart                        # único widget raíz (MyApp), MultiProvider + MaterialApp.router
├── core/
│   ├── router/app_router.dart       # AppRoutes + GoRouter
│   ├── data/api_client.dart         # cliente HTTP único hacia el backend
│   ├── config/api_config.dart       # URL base del backend (build-time)
│   ├── theme/, constants/, utils/   # tema, breakpoints, colores, helpers de geometría
├── features/
│   ├── landing/                     # página de aterrizaje (marketing, datos reales del backend)
│   ├── dashboard/                   # mapa por comunas + detalle de comuna
│   ├── learn/                       # contenido educativo
│   ├── risk/                        # modelo y provider del perfil histórico (consumido desde dashboard)
│   └── chatbot/                     # asistente ambiental
└── shared/widgets/                  # header, footer, tarjetas y badges reutilizados entre features
```

Cada feature con datos remotos sigue el mismo patrón: un modelo de dominio (`domain/models/`) que sabe deserializar la respuesta del backend, y un `ChangeNotifier` (`presentation/providers/`) que orquesta la carga, expone el estado a la UI y decide cuándo repetir la petición.

## Rutas y páginas

| Ruta | Página | Contenido |
| --- | --- | --- |
| `/` | Landing | Presentación del producto, con métricas reales derivadas de `SectorsProvider` (no texto fijo) |
| `/mapa` | Mapa | Las 22 comunas coloreadas por estado, panel lateral con la comuna seleccionada |
| `/mapa/:sectorId` | Detalle de comuna | Tres pestañas: Resumen (indicadores actuales + gráfico de 24h), Historia (perfil de riesgo anual), Sensores (lecturas individuales) |
| `/aprende` | Contenido educativo | Qué es cada contaminante, efectos en salud, umbrales, recomendaciones |
| `/chatbot` | Asistente ambiental | Conversación en lenguaje natural sobre los datos reales de las comunas |

`/mapa/:sectorId` no aparece en la navegación global: se alcanza únicamente tocando una comuna en el mapa.

## Flujos de usuario

**Mapa (`/mapa`).** `SectorsProvider` carga `GET /sectors` al montarse y arranca un sondeo (`polling`) cada 45 segundos mientras la pantalla está activa. `MapArea` pinta los 22 polígonos con `flutter_map`, coloreados según el `estado` que ya trae cada comuna. Tocar una comuna la selecciona (panel lateral con sus indicadores actuales) y habilita el botón hacia el detalle. Un refresco que falla no borra los datos ya mostrados: se conservan los últimos valores conocidos y solo se expone el mensaje de error, para que el mapa no parpadee ni quede en blanco por una falla transitoria de red.

**Detalle de comuna (`/mapa/:sectorId`).** Al entrar, se disparan tres cargas independientes: `SectorDetailProvider.cargarDetalle()` (`GET /sectors/{id}`, alimenta la pestaña Resumen y su gráfico de 24h con `fl_chart`), `RiskProvider.cargarRiesgo()` (`GET /risk/{sector}`, pestaña Historia) y `SectorDetailProvider.cargarSensores()` (`GET /sectors/{id}/sensores`, pestaña Sensores). Las tres tienen su propio estado de carga y su propio manejo de error — que falle una no bloquea a las otras, porque alimentan pestañas distintas de la misma pantalla. Cada resultado se cachea en memoria por `sectorId` dentro del provider, así que volver a una comuna ya visitada no repite la petición.

**Contenido educativo (`/aprende`).** `EducationProvider` pide `GET /education` bajo demanda (no hay sondeo: el contenido es estático). Si la petición de red falla, intenta un segundo camino: un asset local (`assets/educacion.json`), copia literal del mismo archivo que sirve el backend, para que la pantalla siga siendo útil sin conexión. Cuando se muestra ese respaldo, la interfaz lo declara explícitamente en vez de presentar contenido desactualizado como si fuera reciente.

**Chatbot (`/chatbot`).** `ChatbotProvider` no hace ninguna petición hasta que el usuario escribe: no hay sondeo ni precarga. El historial de la conversación vive enteramente en el cliente y se reenvía completo en cada mensaje a `POST /chatbot`, porque el servidor no guarda estado. El turno del usuario se pinta de inmediato, antes de recibir la respuesta, para que la conversación no se sienta congelada mientras el modelo responde; si la petición falla, el turno del usuario se conserva (no desaparece) y queda disponible un botón de reintento. La disponibilidad del asistente (badge en la interfaz) tiene tres estados — desconocida, disponible, no disponible — y arranca en "desconocida": hasta el primer mensaje no hay forma de saber si el servidor tiene el chatbot configurado, y afirmar "en línea" antes de eso sería inventar un dato.

## Consumo de la API

Toda la comunicación con el backend pasa por `core/data/api_client.dart`, que centraliza:

- La URL base (`ApiConfig.baseUrl`), resuelta en tiempo de compilación.
- Timeouts: 15 segundos para las peticiones normales, 45 segundos para `POST /chatbot` (más holgado porque el backend puede tardar hasta 40 segundos en resolver una respuesta con herramientas, y cortar antes que él dejaría al usuario sin una respuesta que el servidor sí llegó a producir).
- Una jerarquía de excepciones propia: `ApiException` (mensaje legible en español, listo para mostrar en la interfaz) y `ChatbotNoDisponibleException` (el caso particular de un `503`, que la interfaz distingue de un fallo transitorio porque reintentar no sirve de nada).

`ApiConfig.baseUrl` se define así:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
```

Es decir: la URL del backend **no es una variable de entorno leída en tiempo de ejecución** por el navegador, sino un valor incrustado en el bundle JavaScript durante la compilación (`--dart-define=API_BASE_URL=...`). Cambiar de backend implica reconstruir el frontend, no solo cambiar una variable en el servidor donde se sirve.

En producción, `API_BASE_URL` apunta a la URL pública que expone Tailscale Funnel sobre el backend autoalojado (ver `backend.md` §Exposición en producción). El backend, a su vez, debe tener ese mismo origen (el dominio donde Vercel sirve el frontend) declarado en `CORS_ORIGINS`, o el navegador bloqueará las peticiones.

## Estado y manejo de datos

Gestión de estado con `provider`/`ChangeNotifier`, sin un store global: cada dominio de datos tiene su propio provider, registrado en `main.dart` dentro de un único `MultiProvider`.

| Provider | Fuente | Se carga | Nota |
| --- | --- | --- | --- |
| `SectorsProvider` | `GET /sectors` | Al arrancar la app (`main.dart`), no solo al entrar a `/mapa` | Necesario porque la landing también muestra datos reales derivados de él |
| `SectorDetailProvider` | `GET /sectors/{id}`, `GET /sectors/{id}/sensores` | Al entrar a `/mapa/:sectorId` | Caché en memoria por `sectorId`, dos estados de carga independientes |
| `RiskProvider` | `GET /risk/{sector}` | Al entrar a `/mapa/:sectorId` | Caché en memoria por `sectorId` |
| `EducationProvider` | `GET /education` | Bajo demanda, al entrar a `/aprende` | Con respaldo local si falla la red |
| `ChatbotProvider` | `POST /chatbot` | Bajo demanda, al enviar un mensaje | Historial de conversación vive en memoria del cliente |

## Variables de entorno

`Frontend/ecobytes/.env` (a partir de `Frontend/ecobytes/.env.example`):

| Variable | Propósito | Obligatoria |
| --- | --- | --- |
| `API_BASE_URL` | URL donde el navegador del cliente puede alcanzar al backend. Se compila dentro del bundle en build time, no se lee en runtime | Sí — sin ella, el build usa `http://localhost:8000` por defecto |

Este archivo no vive en la raíz del repositorio (está dentro de `Frontend/ecobytes/`), así que Docker Compose no lo detecta automáticamente: hay que pasarlo de forma explícita con `--env-file`.

## Cómo correrlo localmente

### Sin Docker

```bash
cd Frontend/ecobytes
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8000
```

Requiere que el backend esté corriendo y que `Backend/.env` tenga `CORS_ORIGINS` incluyendo el origen que asigne Chrome en modo desarrollo (Flutter web imprime el puerto al arrancar).

Otros comandos útiles:

```bash
flutter analyze              # lint estático
flutter test                 # suite de tests
flutter build web --release --dart-define=API_BASE_URL=https://tu-backend
```

### Con Docker Compose

```bash
# Aplicación completa (api + web)
docker compose --env-file Frontend/ecobytes/.env up

# Solo frontend, contra un backend que ya corre en otro lugar
docker compose --env-file Frontend/ecobytes/.env -f docker-compose.frontend.yml up
```

El servicio `web` construye el build de Flutter dentro de la imagen (`Frontend/ecobytes/Dockerfile`, dos etapas: compila con el SDK de Flutter y sirve el resultado estático con `nginx`) y publica el puerto `8080:80`. `API_BASE_URL` se pasa como build arg (`args: API_BASE_URL: ${API_BASE_URL:-http://localhost:8000}`), tomado del `.env` que se le indique a `--env-file`.

## Despliegue en Vercel

El frontend se despliega en Vercel como un sitio estático, sin usar el `Dockerfile` del repositorio: Vercel ejecuta su propio pipeline de build.

`vercel.json`:

```json
{
  "buildCommand": "bash scripts/vercel-build.sh",
  "outputDirectory": "build/web",
  "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }]
}
```

`scripts/vercel-build.sh` clona el SDK de Flutter (rama `stable`) si no está presente en la imagen de build de Vercel, habilita el target web, y compila:

```bash
flutter build web --release --base-href "/" --dart-define=API_BASE_URL="${API_BASE_URL:-http://localhost:8000}"
```

El `rewrite` a `index.html` es necesario porque `go_router` maneja rutas en el cliente (`/mapa`, `/aprende`, etc.): sin él, recargar la página en cualquier ruta distinta de `/` devolvería un 404 de Vercel en vez de dejar que Flutter la resuelva.

Configuración necesaria en el panel de Vercel (Project Settings → Environment Variables):

| Variable | Valor |
| --- | --- |
| `API_BASE_URL` | La URL pública HTTPS que expone Tailscale Funnel sobre el backend autoalojado (ver `backend.md`) |

Sin esta variable configurada en Vercel, el build cae al valor por defecto (`http://localhost:8000`), que no es alcanzable desde el navegador de un visitante real. El dominio que Vercel asigna al despliegue (o el dominio personalizado que se configure) debe coincidir exactamente con lo declarado en `CORS_ORIGINS` del backend.
