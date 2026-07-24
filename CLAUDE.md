# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es EcoBytes

Plataforma de monitoreo de calidad del aire para Cali, Colombia, construida por el equipo Bit&Volt Labs para la Tángara Hackathon. Reutiliza los datos ya recolectados por la red de sensores ciudadanos Tángara para mostrar un mapa de calidad del aire por sector, un perfil histórico de riesgo por dirección, y contenido educativo sobre PM2.5/CO2.

## Flujo de ramas (git)

`feature/*` → `develop` → `main`. **`develop` es la rama estable con el código más actualizado** — todo el trabajo (frontend, backend, documentación) se integra ahí primero. **`main` se actualiza únicamente en releases** y por diseño puede estar varios commits detrás de `develop` — a la fecha de este documento, `main` está parado en el commit inicial del backend, antes de que existiera cualquier feature de frontend o los docs de arquitectura actuales. Eso es intencional, no una discrepancia a corregir: nunca asumas que `main` refleja el estado actual del proyecto, y por defecto ramifica trabajo nuevo desde `develop`, no desde `main`.

## ⚠️ La documentación de arquitectura manda — el código todavía no está alineado con ella

Los archivos `01-Arquitectura.md`, `02-Backlog.md`, `03-Arquitectura-Backend.md` y `04-Arquitectura-Frontend.md` en la raíz del repo son la **fuente de verdad**: describen el diseño que el equipo decidió y documentó. El código heredado que no coincide con ellos no es una alternativa igual de válida — es deuda técnica pendiente de corregir. Por defecto, el trabajo es **acercar el código al objetivo documentado**, no adaptarse a como está el código ni tratar ambas cosas como opciones equivalentes. Antes de tocar algo, verifica en el código si ya está alineado o si es parte de la deuda pendiente. El detalle completo, fila por fila, vive en [`05-Discrepancias.md`](./05-Discrepancias.md) — consúltalo y mantenlo actualizado al cerrar cada brecha (cerrar = corregir el código, nunca reinterpretar el doc). La versión accionable de esas brechas, con tareas concretas y orden de dependencias, vive en [`06-Plan-de-Accion.md`](./06-Plan-de-Accion.md) — revísalo antes de planear trabajo nuevo, ya tiene varias decisiones tomadas (ej. migración a ClickHouse) y hallazgos técnicos verificados (esquema real de tablas, credenciales, GeoJSON de sectores) que no están en los docs de arquitectura originales.

**Para el frontend específicamente, el [Figma del equipo](https://www.figma.com/design/DdGdcWdvPtcSdZ7mRRzXW9/EcoBytes-%E2%80%94-Landing-Page) manda por encima de los docs de arquitectura cuando chocan** (actualización 2026-07-23) — varias secciones de `04-Arquitectura-Frontend.md` describían un alcance reducido (sin landing, sin chatbot, con una pantalla `/riesgo` separada) que no coincidía con el diseño real del equipo; ya se corrigieron para reflejar el Figma. Resumen:

| Objetivo documentado (lo que debe existir) | Código actual (deuda pendiente de corregir) |
| --- | --- |
| Backend sin estado propio, ClickHouse (capa Plata) como única fuente de datos, GeoJSON + `shapely` para sectores | ✅ **Cerrado.** El backend ya no tiene BD propia: `services/clickhouse_client.py` consulta la capa Plata y `services/geo.py` resuelve sectores con `shapely` sobre `data/sectores.geojson` |
| Solo 4 endpoints: `/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education` | ✅ **Cerrado.** Son exactamente los routers que existen (`sectors`, `risk`, `education`); `sensors`, `auth`, `chatbot` y `game` fueron eliminados |
| Sin autenticación, acceso abierto | ✅ **Cerrado.** No hay modelo `User` ni JWT: se eliminaron junto con la capa Postgres |
| Frontend: `Provider`, landing + mapa + aprende + chatbot, rutas `/`, `/mapa`, `/aprende`, `/chatbot` (actualizado 2026-07-23 según Figma) | **`Provider` ✅ cerrado**, **rutas ✅ cerradas**, **detalle de sector ✅ cerrado** (2026-07-23): `sector_detail_page.dart` en `/mapa/:sectorId` con pestañas Resumen/Historia (Sensores queda fuera por falta de endpoint, ver `05-Discrepancias.md` §2.1) |

**Nota (2026-07-23):** las carpetas de plataforma nativa (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) dejaron de ser deuda pendiente — el equipo decidió conservarlas para poder compilar builds nativos (ej. APK) a demanda, aunque web siga siendo el target de despliegue. `04-Arquitectura-Frontend.md` ya refleja esto como objetivo, no como desviación; `T-00.1` del backlog quedó obsoleta. Ver `06-Plan-de-Accion.md` §3.

**Nota (2026-07-23):** landing y chatbot dejaron de ser deuda pendiente — están respaldados por el Figma del equipo. El chatbot mantiene su lugar en el producto (nav + pantalla propia), pero su implementación real (backend/LLM) queda en pausa hasta que un miembro del equipo la retome; no se toca su código ni su alcance mientras tanto. `T-00.4` del backlog quedó obsoleta.

El backlog (`02-Backlog.md`, épica EPI-01) define el trabajo de limpieza técnica que sigue pendiente (resolver la duplicación de arranque `main.dart`/`app.dart`, corregir `test/widget_test.dart`, etc.), y lo marca como **bloqueante**: EPI-02 (capa de datos) depende explícitamente de que EPI-01 esté cerrado primero. Si te piden avanzar en el proyecto sin más contexto, prioriza cerrar esas brechas en el orden del backlog (IDs `T-00.x` en adelante) antes de construir features nuevas sobre la base desalineada. Solo trabajes deliberadamente "con lo que hay" si el usuario lo pide explícitamente para una tarea puntual.

**Estado de la migración a ClickHouse: ya ejecutada.** El backend dejó de usar Postgres — se eliminaron `db/`, `models/`, los routers `sensors`/`auth`/`chatbot`/`game` y `scripts/ingest_csv.py`. `services/calibration.py` **sí se conserva** (se porteó de vuelta durante la migración): aplica la corrección de PM2.5 por humedad dentro de `services/clickhouse_client.py`, para que el valor crudo nunca llegue a `sectors.py`/`risk.py`. La fuente de datos es la capa **Plata** (`tangara_plata.plata_tangara_sensores`), no Gold: `tangara_gold` está marcada como "planificada" en el pipeline y el equipo decidió no esperarla. Ver `06-Plan-de-Accion.md` §1-2 y §2.5 para el detalle técnico (librería `clickhouse-connect`, variables de entorno, esquema de columnas, calibración). Las brechas que siguen abiertas están en `05-Discrepancias.md` y son sobre todo de frontend.

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

- **Gestión de estado:** `Provider` / `ChangeNotifier`, como exige `04-Arquitectura-Frontend.md`. Ver `features/dashboard/presentation/providers/sectors_provider.dart` como referencia del patrón a seguir en nuevas features (polling sin parpadeo, conservar datos previos si un refresco falla). `flutter_bloc` fue eliminado junto con `presentation/bloc/`, que era código muerto.
- **Navegación:** `go_router`. `AppRoutes` y el `GoRouter` real (`appRouter`) viven juntos en `lib/core/router/app_router.dart` (2026-07-23: se resolvió la duplicación de arranque — `EcoBytesApp` y `lib/app.dart` se eliminaron por ser código muerto). `lib/main.dart` (`MyApp`, con `MultiProvider` y `AppTheme.light`) es el único widget raíz.
- **Features (`lib/features/`)**, organizadas por dominio con subcarpetas `data/`, `domain/`, `presentation/` (bloc + pages + widgets) donde aplica:
  - `dashboard/` — el mapa por sectores (página principal del producto), **ya conectado al backend real**. `map_page.dart` consume `SectorsProvider` y `MapArea` pinta los 22 polígonos de comuna con `PolygonLayer`, coloreados por estado. El placeholder de `GridPaper` y los datos inventados que tenía `MapArea` fueron eliminados. `sector_detail_page.dart` (ruta `/mapa/:sectorId`, pestañas Resumen/Historia) ya existe y está conectada — se llega desde el botón "Ver detalle del sector" de `_SidePanelSection`. Lo que sigue con datos falsos son las métricas de arriba de ese botón dentro de `_SidePanelSection`, y `control_sidebar.dart`/`dashboard_layout.dart` son código muerto (ninguna ruta los referencia). Ver [`07-Integracion-Backend-Frontend.md`](./07-Integracion-Backend-Frontend.md) §8.
  - `landing/` — página de aterrizaje con secciones de marketing (hero, features, stats, CTA). **Se conserva permanentemente** (2026-07-23, respaldada por el Figma del equipo). `LandingHeader`/`LandingFooter`/`LandingMobileNav` ya se movieron a `shared/widgets/` — son la cabecera/pie global de toda la app (`landing`, `dashboard`, `learn`, `chatbot`), no exclusivos de la landing.
  - `chatbot/` — stub de página de chatbot, explícitamente etiquetado en su propia UI como "modo de demostración visual" (sin conexión real a ningún backend — el router `chatbot.py` del backend ya no existe, se eliminó en la migración a ClickHouse). **Confirmado como parte del producto por el Figma del equipo** (2026-07-23), pero su implementación real (conexión a un backend/LLM) está en pausa hasta que un miembro del equipo la retome.
  - `learn/` — contenido educativo estático sobre PM2.5/CO2.
- **`core/`** — constantes (`app_colors.dart`, `app_spacing.dart`, `app_breakpoints.dart`), tema (`app_theme.dart`) y utilidades de responsive design (`responsive.dart`) compartidas por toda la app.
- **`shared/widgets/`** — widgets reutilizables entre features (`status_badge.dart`, `metric_card.dart`, `feature_card.dart`, `eco_bytes_logo.dart`).
- El proyecto incluye carpetas de plataformas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) generadas por Flutter; el equipo decidió conservarlas (ver nota arriba) para poder compilar builds nativos a demanda, aunque el despliegue en producción siga siendo `flutter build web`.

## Contrato API backend↔frontend

El backend expone exactamente los endpoints documentados: `GET /sectors`, `GET /sectors/{id}`, `GET /risk/{sector}` y `GET /education` (más `/health`). El contrato vigente es el de `03-Arquitectura-Backend.md` §3, y el `id` de sector en las URLs es el normalizado (`comuna-2`, no `"02"`).

**El mapa ya está conectado a datos reales** (2026-07-23): `SectorsProvider` hace polling de `GET /sectors` cada 45 s y `MapArea` pinta los 22 polígonos de comuna. **Antes de tocar la integración, lee [`07-Integracion-Backend-Frontend.md`](./07-Integracion-Backend-Frontend.md)** — documenta cómo levantar ambos procesos, el paso de CORS que siempre se olvida, el flujo del dato de punta a punta, qué se verificó y qué sigue sin conectar.

Tres cosas que causan bugs si no se saben: el `geometry` es siempre `MultiPolygon` con coordenadas `[lon, lat]` **invertidas** respecto al `LatLng` de Flutter; `sin_datos_recientes: true` **no** garantiza que `pm25_promedio` sea `null` (un sector con sensores pero lectura vieja trae el último valor conocido — hay que chequear el null aparte); y el estado `gris` significa *dato no confiable*, no "aire limpio" — hoy es el caso de 15 de las 22 comunas, todas por falta de sensores.
