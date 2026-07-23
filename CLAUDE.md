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
| Backend sin estado propio, ClickHouse (capa Plata) como única fuente de datos, GeoJSON + `shapely` para sectores | **Ya sin base de datos propia** — ClickHouse (`tangara_plata.plata_tangara_sensores`) es la fuente de `/sensors/*` desde el 2026-07-22 (ver `services/clickhouse_client.py`). El GeoJSON de sectores ya está en el repo, pero `services/geo.py` (point-in-polygon con `shapely`) todavía no existe — sigue pendiente |
| Solo 4 endpoints: `/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education` | Solo existe el router `sensors` (`/latest`, `/{sensor_id}/history`, WebSocket `/ws/live`) — es deliberadamente el único router del backend; `auth`/`chatbot`/`game` (fuera de lo documentado) fueron eliminados el 2026-07-22, ver `05-Discrepancias.md` |
| Sin autenticación, acceso abierto | Ya cumplido — no hay modelo `User` ni router de auth en el código (eliminados el 2026-07-22) |
| Frontend: `Provider`, sin carpetas nativas, sin landing ni chatbot, rutas solo `/map`, `/risk`, `/learn` | Frontend usa `flutter_bloc`, mantiene carpetas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`), y conserva `features/landing/` y `features/chatbot/`; rutas reales: `/` (landing), `/mapa`, `/aprende`, `/chatbot` |

El backlog (`02-Backlog.md`, épica EPI-01) ya define el trabajo de limpieza necesario para llegar del estado actual al objetivo (eliminar plataformas nativas, quitar landing/chatbot, migrar a Provider, etc.), y lo marca como **bloqueante**: EPI-02 (capa de datos) depende explícitamente de que EPI-01 esté cerrado primero. Si te piden avanzar en el proyecto sin más contexto, prioriza cerrar esas brechas en el orden del backlog (IDs `T-00.x` en adelante) antes de construir features nuevas sobre la base desalineada. Solo trabajes deliberadamente "con lo que hay" si el usuario lo pide explícitamente para una tarea puntual.

**Estado de la migración a ClickHouse (ejecutada para `/sensors/*`, 2026-07-22):** el equipo confirmó acceso real a ClickHouse (pipeline Tángara) y ya se migró el backend de Postgres a ClickHouse — Postgres, SQLAlchemy, `db/database.py`, `models/sensor.py` y `scripts/ingest_csv.py` fueron eliminados del repo. La fuente definitiva es la capa **Plata** (`tangara_plata.plata_tangara_sensores`), no Gold — `tangara_gold` está marcada como "planificada" en el pipeline y el equipo decidió no esperarla. `services/clickhouse_client.py` (cliente async `clickhouse-connect[async]`) es el único punto de acceso a datos del backend; `routers/sensors.py` fue reescrito contra él. Ver `06-Plan-de-Accion.md` §1-2 para el detalle técnico completo, incluyendo qué falta validar (formato real de la columna `geo`, sin confirmar oficialmente por el pipeline). **Lo que esta migración NO incluyó** (alcance decidido explícitamente): el contrato final de 4 endpoints (`/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education`). El backend sigue exponiendo `/sensors/*` — construir la sectorización (`services/geo.py` con `shapely` sobre `Backend/data/sectores.geojson`, ya en el repo) y los endpoints documentados es la fase siguiente, pendiente en `06-Plan-de-Accion.md` §2.3-2.4.

## Estructura del repositorio

```
Backend/     — FastAPI (Python), sin base de datos propia, lee de ClickHouse (capa Plata del pipeline Tángara)
Frontend/ecobytes/ — Flutter (Dart), app multi-plataforma (target: solo web)
*.md (raíz) — documentación de arquitectura objetivo y backlog Scrum
```

## Backend (`Backend/`)

### Comandos

```bash
# Levantar la API con hot-reload (sin base de datos propia — lee de ClickHouse)
docker compose up

# Desarrollo local sin Docker (requiere credenciales de ClickHouse)
cd Backend
pip install -r requirements.txt
cp .env.example .env   # completar valores, especialmente CLICKHOUSE_HOST/USER/PASSWORD
uvicorn main:app --reload

# Verificar que el servicio responde
curl http://localhost:8000/health

# Documentación interactiva de la API (Swagger / ReDoc)
# http://localhost:8000/docs
# http://localhost:8000/redoc
```

No hay suite de tests ni linter configurado en el backend todavía.

### Arquitectura actual

- **`main.py`** — instancia FastAPI, configura CORS (`allow_origins=["*"]`, ajustar en producción), registra el router `sensors`, conecta/desconecta el cliente de ClickHouse en los eventos `startup`/`shutdown`.
- **`services/clickhouse_client.py`** — `Settings` (pydantic-settings, lee `CLICKHOUSE_HOST/PORT/USER/PASSWORD/DATABASE/SECURE` desde `.env`), cliente async compartido (`clickhouse_connect.get_async_client()`) creado una vez al arrancar y reutilizado en cada request vía `get_client()`. El backend no tiene base de datos propia — es de solo lectura contra `tangara_plata.plata_tangara_sensores`.
- **`routers/sensors.py`** — único router del backend (`auth`/`chatbot`/`game` fueron eliminados por estar fuera de alcance). `GET /latest` agrega por sensor con `argMax(...)` (necesario porque el motor `ReplacingMergeTree` de la tabla Plata deduplica de forma eventual, no en cada lectura); `GET /{sensor_id}/history` consulta con parámetros server-side de ClickHouse; ambos decodifican la columna `geo` a lat/lon con `pygeohash` (formato no confirmado oficialmente por el pipeline — envuelto en `try/except`, ver `05-Discrepancias.md`).
- **`services/calibration.py`** — corrección de PM2.5 por humedad (fórmula de Dillo et al., factor `K_FACTOR` empírico pendiente de validación por el equipo de electrónica) y clasificación de niveles de alerta según umbrales OMS. Es lógica de dominio pura, sin dependencias de FastAPI/ClickHouse — no se tocó en la migración.
- El endpoint `GET /sensors/latest` y el WebSocket `/sensors/ws/live` son los puntos de integración clave con el frontend para pintar el mapa; `GET /sensors/{id}/history` alimenta la vista de detalle.
- **`data/sectores.geojson`** — GeoJSON de las 22 comunas de Cali (fuente oficial IDESC/Alcaldía de Cali, WGS84), agregado al repo como insumo para la futura sectorización. Todavía no lo consume ningún código (`services/geo.py` no existe aún) — ver `06-Plan-de-Accion.md` §2.3-2.4.

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

El backend real expone `/sensors/*` (no los endpoints `/sectors`, `/risk`, `/education` de los docs objetivo). El frontend aún no consume estos endpoints — `dashboard` usa un repositorio mock. Al conectar frontend y backend, el contrato a implementar debe decidirse mirando ambos lados del código actual, no asumiendo el contrato de `03-Arquitectura-Backend.md` como ya vigente.
