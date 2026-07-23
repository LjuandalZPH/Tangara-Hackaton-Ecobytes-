# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es EcoBytes

Plataforma de monitoreo de calidad del aire para Cali, Colombia, construida por el equipo Bit&Volt Labs para la Tángara Hackathon. Reutiliza los datos ya recolectados por la red de sensores ciudadanos Tángara para mostrar un mapa de calidad del aire por sector, un perfil histórico de riesgo por dirección, y contenido educativo sobre PM2.5/CO2.

## Flujo de ramas (git)

`feature/*` → `develop` → `main`. **`develop` es la rama estable con el código más actualizado** — todo el trabajo (frontend, backend, documentación) se integra ahí primero. **`main` se actualiza únicamente en releases** y por diseño puede estar varios commits detrás de `develop` — a la fecha de este documento, `main` está parado en el commit inicial del backend, antes de que existiera cualquier feature de frontend o los docs de arquitectura actuales. Eso es intencional, no una discrepancia a corregir: nunca asumas que `main` refleja el estado actual del proyecto, y por defecto ramifica trabajo nuevo desde `develop`, no desde `main`.

## ⚠️ La documentación de arquitectura manda — el código todavía no está alineado con ella

Los archivos `01-Arquitectura.md`, `02-Backlog.md`, `03-Arquitectura-Backend.md` y `04-Arquitectura-Frontend.md` en la raíz del repo son la **fuente de verdad**: describen el diseño que el equipo decidió y documentó. El código heredado que no coincide con ellos no es una alternativa igual de válida — es deuda técnica pendiente de corregir. Por defecto, el trabajo es **acercar el código al objetivo documentado**, no adaptarse a como está el código ni tratar ambas cosas como opciones equivalentes. Antes de tocar algo, verifica en el código si ya está alineado o si es parte de la deuda pendiente. El detalle completo, fila por fila, vive en [`05-Discrepancias.md`](./05-Discrepancias.md) — consúltalo y mantenlo actualizado al cerrar cada brecha (cerrar = corregir el código, nunca reinterpretar el doc). La versión accionable de esas brechas, con tareas concretas y orden de dependencias, vive en [`06-Plan-de-Accion.md`](./06-Plan-de-Accion.md) — revísalo antes de planear trabajo nuevo, ya tiene varias decisiones tomadas (ej. migración a ClickHouse) y hallazgos técnicos verificados (esquema real de tablas, credenciales, GeoJSON de sectores) que no están en los docs de arquitectura originales. Resumen:

| Objetivo documentado (lo que debe existir) | Código actual (deuda pendiente de corregir) |
| --- | --- |
| Backend sin estado propio, ClickHouse (capa Plata) como única fuente de datos, GeoJSON + `shapely` para sectores | ✅ **Cerrado.** El backend ya no tiene BD propia: `services/clickhouse_client.py` consulta la capa Plata y `services/geo.py` resuelve sectores con `shapely` sobre `data/sectores.geojson` |
| Solo 4 endpoints: `/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education` | ✅ **Cerrado.** Son exactamente los routers que existen (`sectors`, `risk`, `education`); `sensors`, `auth`, `chatbot` y `game` fueron eliminados |
| Sin autenticación, acceso abierto | ✅ **Cerrado.** No hay modelo `User` ni JWT: se eliminaron junto con la capa Postgres |
| Frontend: `Provider`, sin carpetas nativas, sin landing ni chatbot, rutas solo `/map`, `/risk`, `/learn` | Frontend usa `flutter_bloc`, mantiene carpetas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`), y conserva `features/landing/` y `features/chatbot/`; rutas reales: `/` (landing), `/mapa`, `/aprende`, `/chatbot` |

El backlog (`02-Backlog.md`, épica EPI-01) ya define el trabajo de limpieza necesario para llegar del estado actual al objetivo (eliminar plataformas nativas, quitar landing/chatbot, migrar a Provider, etc.), y lo marca como **bloqueante**: EPI-02 (capa de datos) depende explícitamente de que EPI-01 esté cerrado primero. Si te piden avanzar en el proyecto sin más contexto, prioriza cerrar esas brechas en el orden del backlog (IDs `T-00.x` en adelante) antes de construir features nuevas sobre la base desalineada. Solo trabajes deliberadamente "con lo que hay" si el usuario lo pide explícitamente para una tarea puntual.

**Estado de la migración a ClickHouse: ya ejecutada.** El backend dejó de usar Postgres — se eliminaron `db/`, `models/`, los routers `sensors`/`auth`/`chatbot`/`game`, `scripts/ingest_csv.py` y `services/calibration.py`. La fuente de datos es la capa **Plata** (`tangara_plata.plata_tangara_sensores`), no Gold: `tangara_gold` está marcada como "planificada" en el pipeline y el equipo decidió no esperarla. Ver `06-Plan-de-Accion.md` §1-2 para el detalle técnico (librería `clickhouse-connect`, variables de entorno, esquema de columnas). Las brechas que siguen abiertas están en `05-Discrepancias.md` y son sobre todo de frontend.

## Estructura del repositorio

```
Backend/     — FastAPI (Python), sin BD propia: lee del ClickHouse público de Tángara
Frontend/ecobytes/ — Flutter (Dart), app multi-plataforma (target: solo web)
*.md (raíz) — documentación de arquitectura objetivo y backlog Scrum
```

## Backend (`Backend/`)

### Comandos

```bash
# Levantar la API con hot-reload (único servicio, no hay base de datos que levantar)
docker compose up

# Desarrollo local sin Docker
cd Backend
pip install -r requirements.txt
cp .env.example .env   # completar las credenciales CLICKHOUSE_* y CORS_ORIGINS
uvicorn main:app --reload

# Verificar que el servicio responde
curl http://localhost:8000/health

# Documentación interactiva de la API (Swagger / ReDoc)
# http://localhost:8000/docs
# http://localhost:8000/redoc
```

No hay suite de tests ni linter configurado en el backend todavía.

### Arquitectura actual

- **`main.py`** — instancia FastAPI, configura CORS, registra los tres routers y carga el `SectorIndex` en memoria en el evento `startup`. El mapeo sensor→sector se resuelve de forma perezosa (no en el arranque), para no depender de que ClickHouse esté disponible en ese instante.
- **`config.py`** — `Settings` (pydantic-settings, lee `.env`: credenciales `CLICKHOUSE_*`, `CORS_ORIGINS`) más las constantes de dominio: umbrales OMS de PM2.5 (verde <15, amarillo 15-35, rojo >35), TTLs de caché y el mínimo de meses de histórico para considerar confiable el perfil de riesgo.
- **`services/clickhouse_client.py`** — único punto de acceso a datos. Cliente async contra `tangara_plata`, con las queries parametrizadas y la agregación de lecturas. No hay ORM ni BD propia.
- **`services/geo.py`** — `SectorIndex`: carga `data/sectores.geojson` con `shapely` al arrancar y resuelve point-in-polygon (`resolver_sector(lat, lon)`). Normaliza el esquema del archivo (`comcodigo`/`comnombre`) al contrato público de la API (`comuna-2` / `Comuna 2`). También construye y cachea el mapeo `sensor_name → sector_id` a partir del geohash de cada sensor.
- **`services/cache.py`** — cachés en memoria con TTL corto (~30 s para `/sectors`, ~1 h para el mapeo sensor→sector), para absorber el polling del frontend sin golpear ClickHouse en cada refresco.
- **`routers/`** — `sectors.py` (`GET /sectors`, `GET /sectors/{id}`), `risk.py` (`GET /risk/{sector}`), `education.py` (`GET /education`, sirve `data/educacion.json`). No hay más endpoints que estos cuatro más `/health`.
- **`data/sectores.geojson`** — las 22 comunas de Cali (fuente oficial IDESC/Alcaldía, WGS84). Va versionado; ver `Backend/data/README.md` para la fuente y cómo redescargarlo.

## Frontend (`Frontend/ecobytes/`)

### Comandos

```bash
cd Frontend/ecobytes
flutter pub get
flutter run -d chrome        # desarrollo, target web
flutter analyze              # lint estático
flutter test                 # tests (solo test/widget_test.dart por ahora)
flutter build web --release  # build de producción
```

### Arquitectura actual

- **Gestión de estado:** `flutter_bloc` (no `Provider`, pese a lo que digan los docs de arquitectura objetivo). Ver `features/dashboard/presentation/bloc/` (`sensor_bloc.dart`, `sensor_event.dart`, `sensor_state.dart`) como referencia del patrón a seguir en nuevas features.
- **Navegación:** `go_router`, configurado en `lib/core/router/app_router.dart`. Las rutas están centralizadas como constantes en `lib/app.dart` (`AppRoutes`). Nota: hay dos archivos con lógica de app raíz — `lib/main.dart` (`MyApp`, usado como entrypoint real) y `lib/app.dart` (`EcoBytesApp`, que también define `appRouter` pero no se usa como widget raíz) — antes de tocar el arranque de la app, confirma cuál `MaterialApp.router` está realmente en uso.
- **Features (`lib/features/`)**, organizadas por dominio con subcarpetas `data/`, `domain/`, `presentation/` (bloc + pages + widgets) donde aplica:
  - `dashboard/` — el mapa de sensores (página principal del producto). Actualmente usa `mock_sensor_repository.dart` con datos hardcodeados, no conectado al backend real. ⚠️ **La página real de la ruta `/mapa` (`map_page.dart`) no usa mapa interactivo** — pinta un placeholder estático (`Container` + `GridPaper`). El componente de mapa real y funcional (`MapArea`, con `flutter_map` + tiles OSM) existe pero está huérfano: solo se usa como preview de marketing dentro de `features/landing/.../dashboard_preview_section.dart`. Ver detalle en [`05-Discrepancias.md`](./05-Discrepancias.md) §2.1.
  - `landing/` — página de aterrizaje con secciones de marketing (hero, features, stats, CTA). Marcada para eliminación en la arquitectura objetivo, pero `LandingHeader`/`LandingFooter`/`LandingMobileNav` son importados también por `dashboard`, `learn` y `chatbot` como cabecera/pie global — no se puede eliminar la carpeta sin antes mover esos tres widgets a `shared/`.
  - `chatbot/` — stub de página de chatbot, explícitamente etiquetado en su propia UI como "modo de demostración visual" (sin conexión real al stub del backend). También marcada para eliminación en la arquitectura objetivo (fuera del alcance actual del producto).
  - `learn/` — contenido educativo estático sobre PM2.5/CO2.
- **`core/`** — constantes (`app_colors.dart`, `app_spacing.dart`, `app_breakpoints.dart`), tema (`app_theme.dart`) y utilidades de responsive design (`responsive.dart`) compartidas por toda la app.
- **`shared/widgets/`** — widgets reutilizables entre features (`status_badge.dart`, `metric_card.dart`, `feature_card.dart`, `eco_bytes_logo.dart`).
- El proyecto todavía incluye carpetas de plataformas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) generadas por Flutter; la decisión de arquitectura (ver `04-Arquitectura-Frontend.md`) es eliminarlas y compilar exclusivamente a web, pero eso aún no se ha ejecutado.

## Contrato API backend↔frontend

El backend ya expone exactamente los endpoints documentados: `GET /sectors`, `GET /sectors/{id}`, `GET /risk/{sector}` y `GET /education` (más `/health`). El contrato vigente es el de `03-Arquitectura-Backend.md` §3. **La brecha que queda es del lado del frontend:** `dashboard` sigue usando `mock_sensor_repository.dart` y no consume ningún endpoint real todavía — conectarlo es el siguiente paso natural, y el `id` de sector a usar en las URLs es el normalizado (`comuna-2`, no `"02"`).
