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
| Backend sin estado propio, ClickHouse (capa Plata) como única fuente de datos, GeoJSON + `shapely` para sectores | PostgreSQL + PostGIS vía SQLAlchemy async, sin ClickHouse todavía (el GeoJSON de sectores ya está en el repo, ver nota abajo) |
| Solo 4 endpoints: `/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education` | Routers actuales: `sensors` (`/latest`, `/{sensor_id}/history`, WebSocket `/ws/live`), `auth`, `chatbot`, `game` — todos stubs salvo `sensors`; `chatbot` y `game` son scope fuera de lo documentado |
| Sin autenticación, acceso abierto | Modelo `User` + JWT planeado (`routers/auth.py` es stub, "Sprint 3") — también fuera de lo documentado |
| Frontend: `Provider`, sin carpetas nativas, sin landing ni chatbot, rutas solo `/map`, `/risk`, `/learn` | Frontend usa `flutter_bloc`, mantiene carpetas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`), y conserva `features/landing/` y `features/chatbot/`; rutas reales: `/` (landing), `/mapa`, `/aprende`, `/chatbot` |

El backlog (`02-Backlog.md`, épica EPI-01) ya define el trabajo de limpieza necesario para llegar del estado actual al objetivo (eliminar plataformas nativas, quitar landing/chatbot, migrar a Provider, etc.), y lo marca como **bloqueante**: EPI-02 (capa de datos) depende explícitamente de que EPI-01 esté cerrado primero. Si te piden avanzar en el proyecto sin más contexto, prioriza cerrar esas brechas en el orden del backlog (IDs `T-00.x` en adelante) antes de construir features nuevas sobre la base desalineada. Solo trabajes deliberadamente "con lo que hay" si el usuario lo pide explícitamente para una tarea puntual.

**Estado de la migración a ClickHouse (decidida, en curso):** el equipo confirmó acceso real a ClickHouse (pipeline Tángara) y decidió migrar el backend de Postgres a ClickHouse en vez de quedarse en Postgres. La fuente definitiva es la capa **Plata** (`tangara_plata.plata_tangara_sensores`), no Gold — `tangara_gold` está marcada como "planificada" en el pipeline y, con la hackathon cerca del cierre, el equipo decidió no esperarla: `01-Arquitectura.md` y `03-Arquitectura-Backend.md` ya se actualizaron para reflejar esto como la arquitectura vigente, no como una nota temporal. Ver `06-Plan-de-Accion.md` §1-2 para el plan técnico completo (librería `clickhouse-connect`, variables de entorno reales, esquema de columnas). `Backend/data/sectores.geojson` ya fue agregado al repo (22 comunas de Cali, fuente oficial IDESC) como parte de este trabajo, aunque el código que lo consume (`services/geo.py`) todavía no existe. Antes de asumir que el backend sigue en Postgres indefinidamente, revisa `06-Plan-de-Accion.md` por si ya avanzó la migración.

## Estructura del repositorio

```
Backend/     — FastAPI (Python), PostgreSQL/PostGIS vía SQLAlchemy async
Frontend/ecobytes/ — Flutter (Dart), app multi-plataforma (target: solo web)
*.md (raíz) — documentación de arquitectura objetivo y backlog Scrum
```

## Backend (`Backend/`)

### Comandos

```bash
# Levantar todo el stack (Postgres + API) con hot-reload
docker compose up

# Desarrollo local sin Docker (requiere Postgres accesible vía DATABASE_URL)
cd Backend
pip install -r requirements.txt
cp .env.example .env   # completar valores, especialmente DATABASE_URL y JWT_SECRET_KEY
uvicorn main:app --reload

# Verificar que el servicio responde
curl http://localhost:8000/health

# Documentación interactiva de la API (Swagger / ReDoc)
# http://localhost:8000/docs
# http://localhost:8000/redoc

# Ingestar un CSV histórico de Tángara (correr desde Backend/, con la API levantada)
python scripts/ingest_csv.py --file datos_tangara_2026_05.csv
```

No hay suite de tests ni linter configurado en el backend todavía.

### Arquitectura actual

- **`main.py`** — instancia FastAPI, configura CORS (`allow_origins=["*"]`, ajustar en producción), registra routers, crea tablas al arrancar vía `create_tables()`.
- **`db/database.py`** — engine async de SQLAlchemy, `Settings` (pydantic-settings, lee `.env`), `Base` declarativo, `get_db()` como dependencia de sesión por-request. Las tablas se crean automáticamente en `startup` (no hay migraciones Alembic activas todavía pese a estar en `requirements.txt`).
- **`models/`** — `SensorReading` (lecturas de sensores Tángara, con `pm25_raw`/`pm25_calibrated` separados), `User` (email + password hash), `GameScore` (puntajes de gamificación, FK a `User`).
- **`routers/`** — un router por dominio, registrado en `main.py` con su propio prefix. Solo `sensors.py` tiene lógica real; `auth.py`, `chatbot.py` y `game.py` son stubs (`GET /status`) pendientes de sprints futuros — no asumas que su lógica de negocio existe.
- **`services/calibration.py`** — corrección de PM2.5 por humedad (fórmula de Dillo et al., factor `K_FACTOR` empírico pendiente de validación por el equipo de electrónica) y clasificación de niveles de alerta según umbrales OMS. Es lógica de dominio pura, sin dependencias de FastAPI/DB — reutilizable tanto en el router de sensores como en el script de ingesta.
- **`scripts/ingest_csv.py`** — carga por lotes de CSVs históricos de Tángara a Postgres, aplicando la misma calibración. El `COLUMN_MAP` interno está pensado para ajustarse una vez se conozcan las columnas reales del CSV de producción.
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
