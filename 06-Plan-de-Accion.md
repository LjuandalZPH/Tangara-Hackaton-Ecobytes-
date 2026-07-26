# 🗺️ Plan de Acción — Cierre de Brechas EcoBytes

**Última actualización:** 2026-07-23

> Este documento es la versión accionable de [`05-Discrepancias.md`](./05-Discrepancias.md): convierte cada brecha ya documentada en una tarea concreta, ordenada por prioridad y dependencias. Se apoya en el backlog existente (`02-Backlog.md`, épicas EPI-01 a EPI-05) pero lo actualiza con los hallazgos encontrados durante la revisión (mapa falso, código muerto, bug de `.gitignore`, etc.) que el backlog original no conocía.
>
> Marcado `[ ]` = pendiente. Marcado `[x]` = ya resuelto. Los ítems marcados **DECISIÓN** requieren que el equipo elija entre opciones antes de ejecutar — no son trabajo mecánico.

---

## 0. Ya resuelto durante esta revisión

- [x] **Bug de seguridad en `Backend/.gitignore`**: la regla `backend/.env` no protegía realmente `Backend/.env` (verificado con `git check-ignore`). Corregida a `.env`. Confirmado que nunca se commiteó un `.env` real. Ver `05-Discrepancias.md` §0.
- [x] **Segunda vuelta del mismo `.gitignore`**: el arreglo inicial cambió también `backend/data/` a `data/`, lo que sin querer empezó a ignorar la carpeta `Backend/data/` completa — justo cuando se agregó `sectores.geojson` ahí, que **sí** debe versionarse según `03-Arquitectura-Backend.md` §8. Corregido a solo `*.csv`/`*.csv.gz` (los datos pesados que sí deben ignorarse), sin tocar la carpeta en sí.
- [x] **GeoJSON oficial de comunas de Cali agregado**: `Backend/data/sectores.geojson` (22 comunas, IDESC/Alcaldía de Cali, WGS84 verificado) — ver detalle y fuente en §2.3.

---

## 1. DECISIÓN — ¿Reescribir el backend desde cero o refactorizar el actual? ✅ Resuelta

**Confirmado por el equipo (2026-07-22): sí hay acceso real a ClickHouse.** Se revisó el repositorio del pipeline ([`sebaxtian/clickhouse-tangara`](https://github.com/sebaxtian/clickhouse-tangara)) para entender la conexión real — detalles en la sección 2. La decisión sigue siendo **no reescribir el backend desde cero**: lo que sirve y no depende de la base de datos se conserva.

**Lo que sí sirve del backend actual y se conserva:**
- `services/calibration.py` — la corrección de PM2.5 por humedad, lógica de dominio pura, independiente de qué base de datos quede debajo. **Importante:** hay que verificar si la fórmula ya se aplica en algún punto del pipeline Tángara antes de aplicarla otra vez (evitar doble calibración) — ver hallazgo de la sección 2.
- `routers/sensors.py` — su lógica de negocio (última lectura, historial, WebSocket) es reutilizable como referencia, aunque hay que reescribir el acceso a datos por debajo (de SQLAlchemy/Postgres a ClickHouse).

> **Nota (2026-07-25):** `chatbot.py` volvió al backend, pero no como el stub que se retiró aquí — es la implementación real del asistente (`POST /chatbot` con OpenAI, alimentado por `services/chatbot_context.py` con los datos de ClickHouse). `auth.py` y `game.py` siguen fuera del alcance y no vuelven. Ver `03-Arquitectura-Backend.md` §3.

**Lo que se retira sin ambigüedad, independiente de la base de datos:** los stubs `auth.py`, `chatbot.py`, `game.py` y los modelos `User`, `GameScore` — fuera del alcance documentado, sin consumidor en el frontend (cero referencias a gamificación en todo `lib/`). ✅ **Ejecutado (2026-07-22):** routers y modelos eliminados; `requirements.txt` sin `langchain`/`langchain-openai`/`langchain-anthropic`/`python-jose`/`passlib`; `main.py` sin sus imports/`include_router`; `.env.example` y `Settings` (`db/database.py`) sin las variables `JWT_*`/`LLM_PROVIDER`/`ANTHROPIC_API_KEY`/`OPENAI_API_KEY`.

**Lo que se retira porque ya no aplica al migrar a ClickHouse:** `db/database.py`, `models/sensor.py` (el modelo SQLAlchemy de `SensorReading`), y `scripts/ingest_csv.py` (la ingesta por CSV a Postgres deja de tener sentido si los datos ya están en ClickHouse vía el pipeline InfluxDB→ClickHouse existente). ✅ **Ejecutado (2026-07-22):** carpeta `db/` completa, `models/sensor.py` y `scripts/ingest_csv.py` eliminados; reemplazados por `services/clickhouse_client.py` (detalle técnico en §2.2).

---

## 2. Backend — plan concreto de conexión a ClickHouse

Basado en la revisión real de [`sebaxtian/clickhouse-tangara`](https://github.com/sebaxtian/clickhouse-tangara) (repo de validación/diagnóstico del pipeline, no el pipeline en sí). Esto reemplaza los esqueletos aproximados de `03-Arquitectura-Backend.md` §4 y §6 por los nombres y parámetros reales.

### 2.1 ✅ Decisión tomada: Plata como fuente definitiva, no se espera a Gold

El propio `ARCHITECTURE.md` del pipeline marca la capa Gold como **"planificada"**. Hoy solo existen:

- `tangara_bronce.bronce_tangara_sensores` — capa cruda, todo `String`, motor `MergeTree`.
- `tangara_plata.plata_tangara_sensores` — capa normalizada, motor `ReplacingMergeTree(_ingested_at)`, columnas: `time` (`DateTime64`), `name` (`String`, identificador del sensor), `geo` (`String`, probablemente geohash), `tmp`/`hum`/`pm25`/`co2` (`Nullable(Float32)`), `_ingested_at`. Alimentada automáticamente desde Bronce vía la vista materializada `mv_bronce_a_plata`.
- La tabla `tangara_gold.promedios_horarios` que usaba `03-Arquitectura-Backend.md` §4 como ejemplo era hipotética, no real.

**Decisión (2026-07-22):** con la hackathon cerca del cierre y sin certeza de que Gold vaya a existir a tiempo, **el equipo decidió no esperarla.** `01-Arquitectura.md` y `03-Arquitectura-Backend.md` ya se actualizaron para reflejar esto como la arquitectura definitiva, no como una solución temporal:

- EcoBytes consulta directamente `tangara_plata.plata_tangara_sensores` y hace la agregación (`GROUP BY`, `avg()`, `max(time)`) en las queries del propio backend, tal como ya hace hoy `routers/sensors.py` contra Postgres — ClickHouse resuelve este tipo de consulta analítica con rapidez incluso sobre 62M+ filas, y ya se planea una capa de caché (`services/cache.py`) para absorber el polling.
- Esto es autocontenido dentro del repo de EcoBytes — no depende del roadmap de otro equipo/repo, lo cual era el riesgo principal de esperar una Gold construida por el mantenedor del pipeline.
- Si en algún momento futuro (post-hackathon) el pipeline construye Gold de verdad, migrar estas queries sería una optimización de rendimiento opcional, no un requisito pendiente.

### 2.2 Cliente y variables de entorno reales

El repo de validación usa `clickhouse-connect` (cliente oficial Python), no un cliente genérico. Estos son los parámetros reales (ya reflejados en `03-Arquitectura-Backend.md` §6 tras esta revisión):

```bash
CLICKHOUSE_HOST=clickhouse.sebaxtian.dev   # o el host que te asignen para EcoBytes
CLICKHOUSE_PORT=443
CLICKHOUSE_USER=...
CLICKHOUSE_PASSWORD=...
CLICKHOUSE_DATABASE=tangara_plata          # no tangara_gold — ver 2.1
CLICKHOUSE_SECURE=True
```

- [x] **Conseguir credenciales propias para EcoBytes** — confirmado por el equipo (2026-07-22), ya disponibles.
- [x] **Añadir `clickhouse-connect` a `requirements.txt`, retirando `asyncpg`, `sqlalchemy[asyncio]`, `alembic`** — hecho (2026-07-22), instalado como `clickhouse-connect[async]==1.5.0`. También se retiraron `pandas` y `scikit-learn` (dead weight: solo los usaba `scripts/ingest_csv.py`, ya eliminado, o no se usaban en ningún lado).
- [x] **Verificado:** `clickhouse-connect` sí expone un cliente async nativo (`clickhouse_connect.get_async_client()`, extra `[async]`, backed por `aiohttp`) desde al menos la versión 1.5.0 — no hace falta envolver llamadas síncronas con `run_in_threadpool` como sugería el esqueleto original de `03-Arquitectura-Backend.md` §4. Verificado contra la documentación oficial de ClickHouse Connect (julio 2026).
- [x] **Implementado `services/clickhouse_client.py`** con nombres de tabla/columna reales (`tangara_plata.plata_tangara_sensores`, columnas `name`/`time`/`pm25`/`co2`/`hum`/`tmp`), confirmados además contra `ARCHITECTURE.md` del repo real del pipeline (`sebaxtian/clickhouse-tangara`, rama `master`) el mismo día. `routers/sensors.py` fue reescrito para consultarlo (`GET /latest` con `argMax(...)` agrupado por sensor — necesario porque `ReplacingMergeTree` deduplica de forma eventual, no en cada lectura; `GET /{sensor_id}/history` con parámetros server-side `{nombre:Tipo}`). Se agregó `pygeohash` para decodificar la columna `geo` a lat/lon — el formato de esa columna **sigue sin confirmación oficial** en el repo del pipeline (no hay ejemplo de valor real ni mención de "geohash" en su documentación), así que la decodificación está envuelta en `try/except` con fallback a `None` en vez de asumir que siempre funciona.
- [x] **Validado contra datos reales (2026-07-23):** corrido con Docker (`docker compose up`, credenciales reales) contra ClickHouse. `GET /sensors/latest` devuelve 62 sensores con coordenadas dentro del bounding box de Cali — confirma que `geo` sí es geohash estándar. `GET /sensors/{id}/history` y `WS /ws/live` (ping/pong) también verificados con datos reales.
- [x] **Hallazgo de la validación — desborde de `hours` en `/history` (2026-07-23):** pedir `hours=999999` devolvía 404 en vez de datos. Causa: ClickHouse guarda `DateTime` como `UInt32` (rango 1970–2106); `now() - INTERVAL {hours} HOUR` con un valor muy grande cruza por debajo de 1970-01-01 y da la vuelta (wraparound) a una fecha futura, así que la query no encuentra nada. Corregido acotando `hours` a `(0, 490_000]` (`Query(gt=0, le=MAX_HISTORY_HOURS)` en `routers/sensors.py`) — devuelve 422 en vez de fallar en silencio. Verificado el borde exacto (`hours=490000` → 200, `hours=999999` → 422, `hours=-5` → 422).

**Nota — alcance de aquella migración (superado el 2026-07-23):** el trabajo del 2026-07-22 fue deliberadamente un *swap* de la fuente de datos, dejando `routers/sensors.py` con su contrato anterior. La rama `feature/backend-clickhouse` completó después la fase que quedaba pendiente (sectorización + los 4 endpoints, §2.4) y **retiró `routers/sensors.py`, el WebSocket `/ws/live` y `pygeohash`**:

- `/sensors/*` y `/ws/live` no aparecen en ningún documento de arquitectura. `01-Arquitectura.md` y `04-Arquitectura-Frontend.md` especifican polling REST cada 30-60 s (`Timer.periodic`), no una conexión persistente.
- `pygeohash` sobra: la decodificación se resuelve con `geohashDecode()` dentro de la propia query de ClickHouse (server-side), sin dependencia extra ni `try/except` en Python.

**Lo que sí se conserva de esa validación**, porque sigue siendo cierto y útil:

- La columna `geo` **es geohash estándar** — confirmado empíricamente con 62 sensores dentro del bounding box de Cali. Esto es justamente lo que habilita usar `geohashDecode()` en SQL con confianza.
- **Cuidado con `DateTime` como `UInt32` en ClickHouse** (rango 1970–2106): `now() - INTERVAL {n} HOUR` con un `n` grande cruza por debajo de 1970 y da la vuelta, devolviendo vacío en vez de fallar. Hoy no aplica —`risk.py` usa `INTERVAL 1 YEAR` fijo, sin parámetro de usuario— pero si en el futuro algún endpoint acepta un rango de fechas por query param, hay que acotarlo (el valor usado entonces fue `490_000` horas).

- [x] **Verificado:** `clickhouse-connect` **sí** expone un cliente async nativo (`get_async_client()`, extra `[async]`, sobre `aiohttp`), así que **no** hace falta `run_in_threadpool`. El cliente es un singleton perezoso que se cierra en el `shutdown` de FastAPI.
- [x] **`services/clickhouse_client.py` en su forma final:** expone `ultimo_promedio_por_sensor()`, `posiciones_sensores()`, `promedio_mensual()` y `dias_sobre_limite()`. Es además el único punto donde se aplica la calibración de PM2.5 (ver §2.5).
- [x] **`.env` funcional verificado (2026-07-23):** el backend consulta ClickHouse y devuelve datos reales. Queda por confirmar si el usuario es propio de EcoBytes o el `usuario_analista` genérico.

### 2.5 ✅ Decisión tomada: se aplica calibración de PM2.5 por humedad

**Decisión (2026-07-23): se calibra, y no se expone PM2.5 crudo en ningún endpoint.**

- `services/calibration.py` se conserva (portado desde la línea de trabajo de `develop`, renombrado a `calibrar_pm25` por consistencia con el español del resto del backend). `K_FACTOR = 0.24`, fórmula de Dillo et al.
- Se descartan `calibrate_batch` (dependía de `numpy` para la ingesta CSV por lotes, que ya no existe) y `get_alert_level` (redundante: `sectors.py` ya clasifica verde/amarillo/rojo con los umbrales OMS de `03-Arquitectura-Backend.md` §3; no se reemplaza ese esquema por uno de 6 niveles). **No se reintroduce `numpy`** — la fórmula es escalar.
- **La calibración se aplica una sola vez, dentro de `services/clickhouse_client.py`**, no en los routers: así el crudo nunca llega a `sectors.py`/`risk.py`, que consumen `pm25_promedio` sin saber que la corrección existe.
- `dias_sobre_limite()` **ya no puede filtrar con `HAVING` en SQL**: la corrección no es lineal, así que filtrar sobre el `avg(pm25)` crudo daría un conjunto de días distinto. Se traen los promedios diarios (~365 filas) y se cuenta en Python.
- `hum_promedio` se conserva en la respuesta de `/sectors/{id}`: es una lectura ambiental legítima por sí misma, no un "crudo de PM2.5".

- [ ] ⚠️ **Riesgo abierto — doble calibración.** Nadie ha verificado si el pipeline de Tángara ya aplica esta misma corrección al construir la capa Plata. Si lo hiciera, estaríamos corrigiendo dos veces y los valores saldrían artificialmente bajos. Anotado también como aviso en el propio `services/calibration.py`.
- [ ] Validar `K_FACTOR` con el equipo de Electrónica (T-01.1) — hoy es un valor empírico sin confirmar.

### 2.3 Catálogo sensor→sector: confirmado que no existe listo, hay que construirlo

Se buscó activamente antes de escribir este plan: el repo del pipeline no lo tiene, y tampoco otros repos del mismo mantenedor. Hallazgos:

- **`sebaxtian/tangara-api-mvp`** tiene un esquema pensado para esto (tabla `tangara` con FKs `id_barrio`/`id_sector`/`id_comuna`), pero las FKs están **vacías** en los datos reales, y el snapshot es de **2023-05-21 con solo 25 sensores** (desactualizado frente a los ~47-50 sensores actuales) — no sirve como fuente de verdad.
- Ninguno de los catálogos administrativos encontrados (`comuna.json`, `sector.json`, `barrio.json`) tiene geometría/polígono — son solo nombre + código, inútiles para point-in-polygon sin conseguir además los polígonos reales de las comunas de Cali.
- El sitio público `tangara.chis.pa` no expone catálogo de ubicaciones, solo un dashboard Grafana y descarga de datos históricos genéricos.

**Conclusión: no hay atajo — EcoBytes tiene que construir este catálogo.** Pero la mitad del problema (el GeoJSON de comunas) ya se resolvió durante esta revisión:

- [x] **GeoJSON oficial de las 22 comunas de Cali, ya en el repo: `Backend/data/sectores.geojson`.** Fuente: **IDESC** (Infraestructura de Datos Espaciales de Cali, la entidad geoespacial oficial de la Alcaldía), vía el servicio WFS de GeoServer, catalogado también en `datos.cali.gov.co` (dataset "Comunas de Santiago de Cali"). Endpoint usado para descargarlo:
  ```
  https://ws-idesc.cali.gov.co/geoserver/dapm/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=dapm:pdt_dpa_comunas&outputFormat=application/json&srsName=EPSG:4326
  ```
  **Nota importante si hay que volver a descargarlo** (ej. si cambian los límites de las comunas): el servicio devuelve las coordenadas en EPSG:6249 (proyección local en metros) por defecto — hay que pedir explícitamente `srsName=EPSG:4326` (como en el comando de arriba) para obtener lat/lon estándar, o reproyectar manualmente si se descarga sin ese parámetro. Ya verificado: 22 features, tipo `MultiPolygon`, propiedades `comcodigo` ("01".."22") y `comnombre` ("Comuna 01".."Comuna 22"), coordenadas confirmadas dentro del rango real de Cali (-76.55, 3.45).
- [x] **`Backend/.gitignore` ajustado para permitir versionarlo** — la regla `data/` (arreglada en §0 para el bug de `.env`) ignoraba también `sectores.geojson`, contradiciendo `03-Arquitectura-Backend.md` §8 ("versionado en el repo"). Ya se ajustó a solo `*.csv`/`*.csv.gz` para que la carpeta `data/` en sí no se ignore.
- [x] **Decodificación de `geo` (geohash → lat/lon) implementada — checkbox desactualizado, el trabajo ya está hecho.** No usa `pygeohash` en Python como se planteaba aquí: se resuelve server-side con `geohashDecode()` dentro de la propia query de ClickHouse (ver la nota de §2.2 sobre por qué se prefirió eso a la dependencia Python). Este ítem quedó sin marcar por un descuido al actualizar el documento tras completar `feature/backend-clickhouse` — el trabajo real está descrito y cerrado en §2.4.
- [x] **Resolución de sector con `shapely` implementada — checkbox desactualizado.** `services/geo.py` (`SectorIndex`) hace exactamente esto: point-in-polygon sobre `Backend/data/sectores.geojson` con `shapely`, usando el lat/lon ya decodificado del punto anterior. Ver §2.4.
- [x] **Caché del mapeo sensor→sector implementada — checkbox desactualizado.** `services/cache.py` (`sensor_sector_cache`, `TTLCache` con `TTL_MAPEO_SENSOR_SECTOR_SEGUNDOS` ≈ 1h) hace justo esto. Ver §2.4.
- [ ] **Nota de granularidad:** si más adelante se necesita nivel de barrio (no solo comuna), la misma capa IDESC (`dapm` workspace en GeoServer) probablemente tiene una capa de barrios equivalente — no se buscó todavía porque el alcance actual de `03-Arquitectura-Backend.md` habla de "sectores" a nivel de comuna.

### 2.4 Resto del plan de backend

- [x] Implementar `services/geo.py` con `SectorIndex` (`Backend/data/sectores.geojson` + `shapely`). Normaliza el esquema de IDESC (`comcodigo`/`comnombre`) al contrato público (`comuna-2` / `Comuna 2`).
- [x] Reformar los endpoints para cumplir el contrato documentado: `GET /sectors`, `GET /sectors/{id}`, `GET /risk/{sector}`, `GET /education`. Son los únicos que existen, más `/health`.
- [x] Agregar caché en memoria con TTL corto para `/sectors` (`services/cache.py`, `cachetools.TTLCache`): 30 s para `/sectors` y ~1 h para el mapeo sensor→sector.
- [x] Actualizar `03-Arquitectura-Backend.md` §4 y §6 con los nombres reales. §6 ya tenía las variables correctas; §4 y §5 se reemplazaron por la implementación real (cliente async nativo, `geohashDecode()` en la query, normalización de `comcodigo`).

**Verificación end-to-end (2026-07-23).** El backend se levantó contra el ClickHouse real y respondió:

- `GET /sectors` → 22 comunas; **7 con datos recientes** (comunas 2, 4, 8, 10, 17, 18, 22, todas en `verde`, PM2.5 entre 3.2 y 12.6 µg/m³) y 15 en `gris` por no tener ningún sensor dentro del polígono.
- `GET /sectors/comuna-17` → `pm25 4.35`, `co2 162.07`, `hum 81.33`, `estado verde`.
- `GET /risk/comuna-17` → `promedio_anual 7.98`, peor mes `2026-06` (13.25), mejor mes `2025-07` (3.24), `16` días sobre el límite OMS, `historico_suficiente: true`.
- `GET /education` → 200. `GET /sectors/comuna-99` → 404. Swagger en `/docs` → 200 (DoD §8).

Esto confirma que la cadena completa funciona: geohash de `tangara_plata` → `geohashDecode()` → point-in-polygon con `shapely` → agregación por comuna. **Nota:** que 15 de 22 comunas queden en `gris` no es un bug — la red Tángara simplemente no tiene sensores en todas las comunas; el frontend debe representar ese estado explícitamente.

---

## 3. Frontend — orden recomendado (actualiza EPI-01 del backlog con los hallazgos nuevos)

1. [x] **Duplicación de arranque resuelta** (2026-07-23). `AppRoutes` + el `GoRouter` real (`appRouter`) ahora viven juntos en `core/router/app_router.dart`; `lib/main.dart` (`MyApp`, con `MultiProvider`) es el único widget raíz. Se borró `EcoBytesApp` y `lib/app.dart` completo. De paso, `MyApp` empezó a aplicar `AppTheme.light` (antes no se aplicaba ningún tema en producción — `EcoBytesApp` sí lo hacía pero no era el widget que corría).
2. [x] **`LandingHeader`, `LandingFooter`, `LandingMobileNav` movidos a `shared/widgets/`** (2026-07-23) — son el header/footer global de toda la app (los usan `landing`, `dashboard`, `learn` y `chatbot`), no exclusivos de la landing. `map_page.dart`, `learn_page.dart`, `chatbot_page.dart` y `landing_page.dart` ya importan desde la nueva ubicación. Ya no desbloquea un borrado de `landing/` (que se conserva, ver DECISIÓN abajo) — se hizo de todas formas porque es la ubicación correcta para un widget global.
3. [x] **`test/widget_test.dart` corregido** (2026-07-23): monta `MyApp` (`lib/main.dart`) en vez de `EcoBytesApp`. Se desmonta el árbol al final del test (`tester.pumpWidget` con un widget vacío) para que `SectorsProvider` cancele su `Timer.periodic` de polling antes de que termine el test — si no, falla por "timer pendiente". De paso se encontraron y arreglaron dos bugs reales que el test traía ocultos:
   - **Overflow de layout en `landing_footer.dart`** (preexistente, ver `07-Integracion-Backend-Frontend.md` §8): el layout de 4 columnas usaba `context.isMobile` (breakpoint <600) para decidir entre apilado y fila ancha, pero el contenido necesita el ancho de *desktop* (≥1200) para no desbordar — a ancho *tablet* (600-1200, incluido el viewport de 800×600 por defecto de `flutter_test`) también desbordaba. Se cambió la condición a `!context.isDesktop`, así se apila en mobile y tablet por igual.
   - **`find.textContaining()` no matchea `RichText`** (solo `Text`/`EditableText`): el hero usa `RichText` para pintar "visible." en verde dentro de la misma oración. Se cambió esa aserción a `find.byWidgetPredicate` sobre `RichText`.
4. [x] **Reemplazar el placeholder de `MapaPage`** — ya hecho: `MapArea` (real, con `flutter_map`) conectado a `SectorsProvider`.
5. [x] **`SensorBloc` eliminado** — era andamiaje muerto, se borró junto con `presentation/bloc/` al migrar a `Provider`.
6. [ ] ~~Eliminar `features/landing/` y `features/chatbot/`~~ — **Obsoleta (2026-07-23):** el Figma del equipo confirma que ambas se conservan como parte del producto. Ver DECISIÓN abajo.
7. [ ] ~~Simplificar `app_router.dart`/`AppRoutes` a solo `/mapa`, `/aprende` y la nueva `/riesgo`~~ — **Obsoleta (2026-07-23):** las rutas reales (`/`, `/mapa`, `/aprende`, `/chatbot`) ya coinciden con el Figma, no hay nada que simplificar. No existe (ni debe existir) una ruta `/riesgo` — ver paso 9.
8. [x] **DECISIÓN — `flutter_bloc` vs `Provider`: resuelta a favor de `Provider`** (2026-07-23, commit `a44940b`). Se migró `SectorsProvider`/`RiskProvider` a `ChangeNotifier`, se eliminó `presentation/bloc/` (código muerto) y `flutter_bloc` salió de `pubspec.yaml`. `equatable` se conservó en ese momento porque `dashboard/domain/models/sensor_data.dart` la seguía usando — **ese archivo se eliminó el 2026-07-24** (ver paso 10) y `equatable` salió también de `pubspec.yaml` al quedar sin ningún consumidor.
9. [x] **`sector_detail_page.dart` construido y probado (2026-07-23).** Ruta `/mapa/:sectorId`, dos pestañas — Resumen (indicadores actuales + gráfico de PM2.5 de `historial_24h` con `fl_chart`, `GET /sectors/{id}` vía `SectorDetailProvider`, nuevo) e Historia (perfil histórico, `GET /risk/{sector}` vía `RiskProvider`, ya existente) — reachable desde "Ver detalle del sector" en `map_page.dart` (antes `onPressed: () {}`, ahora navega al sector que el usuario tocó en el mapa; deshabilitado si no hay ninguno seleccionado). "Preguntar al chatbot" navega a `/chatbot` en ambas pantallas. **Sensores queda fuera** (2026-07-23, decisión del equipo): ningún endpoint expone sensores individuales por sector; queda anotada como bloqueada por backend en `05-Discrepancias.md` §2.1. Corresponde a EPI-04 corregido en `02-Backlog.md`.
   - **Dos bugs reales encontrados y corregidos al probarlo** (no eran solo cascada de errores): (1) llamar a `cargarDetalle()`/`cargarRiesgo()` directo en `initState()` disparaba un `notifyListeners()` síncrono contra providers que ya tenían listeners activos (a diferencia de `SectorsProvider`, que arranca en el `create()` de su propio provider, antes de que exista cualquier listener) — reconstruía un ancestro a mitad del montaje del widget y Flutter lo rechazaba con "setState() called during build"; se corrigió difiriendo la carga con `WidgetsBinding.instance.addPostFrameCallback`. (2) `_IndicatorsRow` usaba `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` dentro de una `Column` de alto no acotado (por el scroll), lo que le pedía a las tarjetas una altura infinita; se envolvió en `IntrinsicHeight`.
   - **Test de regresión agregado:** `test/sector_detail_page_test.dart` monta la pantalla real (providers + carga + cambio de pestaña) y falla si se lanza cualquier excepción — hubiera atrapado ambos bugs.
10. [x] **Landing migrada completa a datos reales (2026-07-24).**
    - `StatsBar`: "47 sensores activos" y "2.4M ciudadanos informados" no tenían forma de derivarse de ningún endpoint (`/sectors` no expone conteo de sensores; alcance poblacional no es medible desde telemetría de aire) — se reemplazaron por "X/22 comunas con datos en tiempo real" y "PM2.5 promedio ciudad", ambas calculadas en vivo desde `SectorsProvider`. "22 comunas monitoreadas en Cali" se conservó (alcance geográfico real y fijo del GeoJSON) y "24/7 monitoreo continuo" también (característica real de la arquitectura, no una cifra inventada).
    - `hero_section.dart`: el badge "DATOS EN TIEMPO REAL" (lo primero que ve cualquier visitante) afirmaba tiempo real sobre datos 100% inventados de `MockSensorRepository.landingMetrics` — overlay "ARROYO HONDO/AQI 82" (barrio y unidad inventados) y 3 `MetricCard` fijas (PM2.5/CO2/Humedad). Reemplazado por la comuna real con mejor PM2.5 del momento (nombre + µg/m³ + `estado` real) y 3 métricas reales (PM2.5 promedio ciudad, cobertura X/22, última actualización).
    - `dashboard_preview_section.dart`: `MapArea` no recibía `sectores` (mapa en blanco); ahora sí. `ControlSidebar` (progreso y "sensores destacados" inventados) reemplazado por `_PreviewSidebar` con indicadores y comunas destacadas (mejor/peor) reales, mismo patrón que `_BottomMetricsBar` del mapa.
    - Se agregó `estadoDesdePm25()` en `sector.dart` (clasifica un PM2.5 crudo con los umbrales OMS de `config.py`) para no duplicar esa lógica entre los dos archivos de arriba.
    - **Eliminados por completo** (sin consumidores tras la migración): `mock_sensor_repository.dart`, `sensor_data.dart`, `control_sidebar.dart`, `dashboard_layout.dart`, y la dependencia `equatable` de `pubspec.yaml`.
    - **Bug de regresión encontrado al probar en un navegador real (no en `flutter test`):** `_IndicatorTile` desbordaba por unos pixeles en el layout de escritorio (`Row` sin `Expanded` para el label, etiquetas más largas que las de `ControlSidebar`) — invisible en `flutter test` porque su viewport por defecto (800×600) cae bajo el breakpoint `tablet` (900px) y toma el layout apilado sin ese ancho fijo. Mismo patrón de bug que ya había mordido a `landing_footer.dart` (paso 3). Corregido con `Expanded`+`TextOverflow.ellipsis`.
11. [x] **`features/learn/` conectado a `GET /education` (2026-07-25).** La decisión de `T-05.2` se tomó a favor de conectar: `EducationProvider` + `ContenidoEducativo` + `ApiClient.getContenidoEducativo()`. El JSON se amplió para cubrir lo que solo vivía en la UI (humedad, escala de estados, perfiles con emoji) y la pantalla ganó lo que solo vivía en el JSON (efectos en salud, límite anual, fuente con URL). Queda un asset de respaldo (`assets/educacion.json`), copia literal del archivo del backend, para que la pantalla siga viéndose sin conexión.
12. [x] **Pestaña "Sensores" del detalle de sector construida (2026-07-24).** Estaba bloqueada (paso 9) por falta de un endpoint que expusiera sensores individuales. Se agregó `GET /sectors/{id}/sensores` (`Backend/routers/sectors.py`, reusa `obtener_mapeo_sensor_sector()` y `ultimo_promedio_por_sensor()` ya existentes, sin queries nuevas a ClickHouse) y su consumo en frontend: modelo `SensorDeSector` (`sector.dart`), `ApiClient.getSensoresDeSector()`, `SectorDetailProvider` extendido con estado de carga propio para esta pestaña, y la pestaña "Sensores" en `sector_detail_page.dart` (tarjeta por sensor: nombre, última lectura relativa, PM2.5, estado). `test/sector_detail_page_test.dart` extendido para cubrir el cambio a esta pestaña. Ver `05-Discrepancias.md` §2.1 y `03-Arquitectura-Backend.md` §3.

**DECISIÓN (2026-07-23):** el equipo decidió **conservar** las carpetas de plataforma nativa (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) para poder compilar builds nativos (ej. APK de Android) a demanda, aunque web siga siendo el target de despliegue. `04-Arquitectura-Frontend.md` ya se actualizó para reflejar esto como objetivo — no es deuda pendiente, `T-00.1` del backlog queda obsoleta.

**DECISIÓN (2026-07-23):** al revisar el [Figma del equipo](https://www.figma.com/design/DdGdcWdvPtcSdZ7mRRzXW9/EcoBytes-%E2%80%94-Landing-Page) (Landing, Dashboard Mapa, Aprende, Chatbot, Detalle de Producto), quedó claro que la documentación original describía un alcance que no coincidía con el diseño real: **landing y chatbot se conservan** (nav real: `Inicio | Mapa | Aprende | Chatbot`), y **no existe una pantalla `/riesgo` separada con selector de barrio** — el perfil histórico es la pestaña "Historia" de la página de detalle de sector a la que se llega desde el mapa (Figma "Detalle de Producto"). `04-Arquitectura-Frontend.md` y `02-Backlog.md` (EPI-04) ya se actualizaron. `T-00.4` del backlog queda obsoleta; `T-00.5` se redefinió (ya no es "simplificar rutas", ahora es la duplicación de arranque del paso 1). El chatbot mantiene su lugar en el producto, pero su implementación real (backend/LLM) queda en pausa hasta que un miembro del equipo la retome — no se toca su código ni su alcance mientras tanto.

---

## 4. Integración backend↔frontend

✅ **Ejecutado (2026-07-23).** Detalle completo en [`07-Integracion-Backend-Frontend.md`](./07-Integracion-Backend-Frontend.md).

- [x] Cliente HTTP real contra el backend: `core/data/api_client.dart` + `SectorsProvider` / `RiskProvider`. Se migró a **Provider** como exige `04-Arquitectura-Frontend.md` y se eliminó `presentation/bloc/` (era código muerto, cero referencias externas); `flutter_bloc` salió de `pubspec.yaml`.
- [x] **CORS confirmado (`T-00.7`)**: verificado con origen permitido (devuelve la cabecera), preflight `OPTIONS` (200) y origen no permitido (no la devuelve). El default de `CORS_ORIGINS` es **vacío a propósito** (fail-closed, DoD §8), y `main.py` avisa al arrancar si queda vacío.
- [x] Polling real cada 45 s (dentro del rango 30-60 s). Los refrescos no muestran spinner para no parpadear, y si uno falla conservan los datos previos.
- [x] Estado `gris` / `sin_datos_recientes` modelado: `EstadoSector.gris` con la etiqueta "Sin datos" en la leyenda, más una línea de cobertura real calculada de los datos.
- [x] `MapaPage` deja de mostrar el placeholder: `MapArea` pinta los 22 polígonos con `PolygonLayer`. Se eliminaron los datos inventados que tenía (5 sectores ficticios, grilla decorativa, "AQI promedio: 32").

**Ya no queda nada abierto de integración (2026-07-25):** `GET /education` fue el último endpoint sin conectar y ya lo consume `EducationProvider` (paso 11). Los seis endpoints del contrato tienen consumidor real en el frontend. `GET /sectors/{id}` y `GET /risk/{sector}` ya tienen UI (paso 9), `_SidePanelSection` ya se conectó a datos reales (paso 10), y la landing completa (`StatsBar`, `hero_section.dart`, `dashboard_preview_section.dart`) ya no usa `MockSensorRepository` (paso 10, 2026-07-24) — ese archivo, junto con `sensor_data.dart`, `control_sidebar.dart` y `dashboard_layout.dart`, se eliminó del repo por completo.

---

## 5. Kiosko ESP32 (planificado, sin código todavía)

Nuevo módulo, independiente de todo lo anterior: un ESP32 con pantalla táctil
que consume el mismo backend (mismos 5 endpoints, sin cambios de contrato).
Diseño completo, presupuesto de memoria y advertencias técnicas en
[`08-Arquitectura-ESP32.md`](./08-Arquitectura-ESP32.md); tareas concretas en
`02-Backlog.md` (EPI-06). Primer paso bloqueante: un spike que mida heap libre
real parseando `GET /sectors` con el filtro de ArduinoJson (descarta el campo
`geometry`, que el ESP32 no necesita y pesa demasiado sin filtrar) — sin eso
validado, el resto de las pantallas no tiene sentido construirlas.

### 5.1 ✅ T-07.1 (spike de heap) corrido en hardware real — memoria viable, latencia como riesgo abierto

Corrido en un ESP32-2432S028 real contra el backend expuesto por Tailscale
Funnel (ver `Firmware/esp32-kiosko/README.md`), 2026-07-25.

**Hallazgo 1 — el timeout inicial de `LectorResiliente` (5000 ms) no
alcanzaba:** en la primera corrida, 3 de 5 fetches fallaron con
`Fallo al parsear JSON: IncompleteInput` porque el relay de Tailscale Funnel
dejó huecos de silencio de más de 5 s a mitad de transferencia de los ~774 KB
de `/sectors` (la conexión seguía viva, solo dejaba de haber bytes
disponibles momentáneamente). Corregido subiendo `kStallMaxMs` a 12000 ms en
`Firmware/esp32-kiosko/esp32-kiosko.ino` (clase `LectorResiliente`). Con ese
cambio, corrida siguiente: **5/5 fetches completaron sin ningún fallo de
parseo.**

**Hallazgo 2 — memoria y fragmentación: viable, sin ajustes adicionales.**
En la corrida limpia de 5/5, `bloque_max_contiguo` (`ESP.getMaxAllocHeap()`)
se mantuvo clavado en el mismo valor en los 5 fetches — cero fragmentación
detectada. `min_historico` cae en el primer fetch (esperable, WiFi/TLS
calentando) y luego se estabiliza en los fetches siguientes, exactamente el
patrón que `Firmware/esp32-kiosko/README.md` define como criterio de éxito.
**El diseño de filtrar `geometry` con `DeserializationOption::Filter` y
parsear en streaming alcanza para los 520 KB de SRAM del ESP32-2432S028.**

**Hallazgo 3 (riesgo abierto, no resuelto) — el fetch completo tarda
~45-50 s.** El filtro de ArduinoJson ahorra RAM pero no tráfico: el ESP32
igual tiene que **recibir** los ~774 KB completos (con `geometry` incluido)
antes de descartar ese campo al parsear — ver comentario en
`esp32-kiosko.ino` junto a `WiFiClient& stream = http.getStream();`. Con el
throughput real observado del relay de Funnel (~15 KB/s), cada poll de
`/sectors` tarda casi un minuto. Subir el timeout evitó el corte del JSON
pero no ataca la causa. **Antes de construir la pantalla Landing (T-07.4),
decidir si esto es aceptable** o si hace falta que el backend ofrezca una
variante de `/sectors` que excluya `geometry` en el servidor (reduciría el
tráfico real, no solo la RAM del cliente) — eso implicaría un 6º endpoint o
un query param, a evaluar contra el principio de "solo 5 endpoints" de
`03-Arquitectura-Backend.md` §3.

### 5.2 🟡 T-07.2 (smoke test) — primer intento de compilación falló por overflow de DRAM estática, corregido

Al compilar el smoke test (FQBN `esp32:esp32:esp32`, ESP32 Dev Module) con
LVGL v8 + LovyanGFX ya enlazadas, el link falló:

```
section `.dram0.bss' will not fit in region `dram0_0_seg'
region `dram0_0_seg' overflowed by 27152 bytes
```

**Causa:** dos reservas de memoria *estática* (`.bss`, no heap) que se
suman en tiempo de compilación, no de ejecución:

- `bufA`/`bufB` en `esp32-kiosko.ino` (buffers de dibujo de LVGL, arrays
  globales) — a 40 líneas de alto cada uno, ~50 KB entre los dos.
- El pool interno de LVGL (`lv_conf.h`, `LV_MEM_SIZE`) — con
  `LV_MEM_CUSTOM 0`, también es un array estático, no memoria pedida a
  `malloc()` en runtime. Estaba en 48 KB.

El presupuesto de `08-Arquitectura-ESP32.md` §9 contaba el buffer de LVGL
como si fuera heap ("~50 KB de buffer de LVGL... recomendado por LVGL para
boards sin PSRAM") sin distinguir que tanto ese buffer como el pool interno
de LVGL son estáticos — la distinción importa porque lo estático se valida
en el *link*, antes de que el firmware corra, mientras que el heap se
valida en runtime (`ESP.getFreeHeap()`, que es lo que sí midió T-07.1).

**Corregido** bajando ambos valores (con margen, no al mínimo):
`LV_MEM_SIZE` de 48 KB a 24 KB (`lv_conf.h`) y `kBufAlturaLineas` de 40 a
20 (`esp32-kiosko.ino`) — libera ~50 KB de `.bss`, contra un overflow de
27 KB. Suficiente para las pantallas placeholder actuales; si una pantalla
futura con más objetos/estilos simultáneos (ej. la Landing con lista de 22
filas, T-07.4) vuelve a desbordar, subir `LV_MEM_SIZE` de a poco y medir
con `LV_USE_MEM_MONITOR`, no volver a 48 KB de entrada.

**Segundo intento:** el overflow de DRAM se resolvió (variables globales
101 548 bytes / 30% de 327 680, dentro del máximo), pero apareció un error
distinto — de **flash**, no de RAM:

```
Sketch uses 1316919 bytes (100%) of program storage space. Maximum is 1310720 bytes.
```

`1310720` (`0x140000`) es el tamaño de `app0` en el esquema de particiones
por defecto del core ESP32 para un board de 4 MB, que reserva **dos**
particiones de app de 1.25 MB (para OTA con rollback) + spiffs — este
proyecto no usa OTA (flasheo por USB) ni spiffs/LittleFS (NVS vía
`Preferences.h` para config de red y calibración de touch, ver
`storage_prefs.h`), así que ese reparto le deja muy poco a `app0` para un
binario que ya de por sí es grande (LVGL con `lv_conf.h` trae habilitado
por defecto GIF/PNG/QR/FreeType/rlottie/fuentes CJK que este kiosko no
usa). **Corregido** agregando `Firmware/esp32-kiosko/partitions.csv`
(basado en el preset oficial `huge_app.csv` del core 3.3.10): una sola
partición de app de 3 MB sin slot OTA duplicado. Arduino IDE usa este
archivo por estar directo en la carpeta del sketch, sin tocar ningún menú
— mismo mecanismo que ya aprovecha `lv_conf.h` (`08-Arquitectura-ESP32.md`
§6).

**Pendiente de confirmar:** recompilar con `partitions.csv` presente y
verificar que ni el link (DRAM) ni el tamaño de flash desbordan, y correr
en hardware real (los criterios de éxito de T-07.2 siguen siendo los del
`README.md` del firmware).

### 5.3 🟡 T-07.2 (smoke test) — reinicios en loop durante el fetch en hardware real, causa probable: brownout

Con la compilación ya resuelta (§5.2), correr el smoke test en el
ESP32-2432S028 real mostró la pantalla con un patrón de ruido/franjas en
vez del placeholder limpio de la Landing. El Serial Monitor (115200) lo
explica: el dispositivo entra en un **ciclo de reinicios**, siempre a
mitad del flujo WiFi→fetch→cargar Landing, nunca estable en una pantalla:

- El fetch en sí es sólido cuando llega a completar: 3 corridas con
  `Sectores parseados: 22`, sin fragmentación (`bloque_max_contiguo`
  estable ~65-75 KB), heap se recupera bien después (~162 KB libres).
- El reinicio ocurre en un punto **distinto cada vez** (a veces recién al
  cargar la Landing después del fetch, otras veces a mitad del fetch,
  justo después de recibir los headers HTTP) — no es un lugar fijo del
  código, lo que apunta a una condición de carrera/umbral (voltaje), no a
  un bug determinístico.
- **Sin ningún mensaje de diagnóstico antes del reinicio** — ni
  `Guru Meditation Error` con backtrace (que sí aparecería con un crash de
  software real: stack overflow, memoria inválida) ni siquiera
  `Brownout detector was triggered` de forma consistente. Un reset
  completamente silencioso, sin backtrace, es la firma típica de un corte
  de energía real (que puede tumbar también al puente USB-serie a mitad
  de imprimir, perdiendo el mensaje) — no de una excepción atrapada por
  software.
- **Se descartó el cable USB** como causa (probado con uno distinto,
  mismo resultado) — el sospechoso que queda es el puerto/fuente (los
  puertos USB de PC suelen limitar más la corriente que un cargador de
  pared) o el regulador de voltaje a bordo del ESP32-2432S028, que es
  conocido en la comunidad maker por ir justo al límite bajo la carga
  combinada de WiFi + pantalla.

**Mitigación de firmware aplicada** (no ataca la causa de raíz si es el
regulador de la placa, pero reduce los picos de corriente que la gatillan):
en `esp32-kiosko.ino`, `WiFi.setTxPower(WIFI_POWER_8_5dBm)` después de
conectar (baja la potencia de transmisión, y con ella los picos de
corriente de las ráfagas de radio durante los ~35-40s que dura el fetch) y
`lcd.setBrightness(0)` durante el fetch (apaga el backlight mientras no
hay nada que mostrar, restaurado a `255` antes de cargar la Landing).

**Pendiente de confirmar:** recompilar y correr de nuevo en hardware real
con estas dos mitigaciones; si el reinicio persiste, el siguiente paso es
probar alimentación desde un cargador de pared en vez del puerto USB de la
PC, para terminar de aislar puerto/fuente vs. regulador de la placa.

**Cable, puerto y cargador de pared descartados** (mismo resultado con los
tres) — apunta al regulador/desacople de la placa misma, no a la fuente
externa. Se verificaron también los pines SPI de `LGFX_Config.h` contra la
fuente primaria de Random Nerd Tutorials para este board exacto: coinciden
uno por uno (pantalla en HSPI, touch en VSPI, sin contención de bus) — se
descarta un pin mal asignado como causa.

Decisión del equipo (2026-07-25): **no se va a soldar un capacitor** en
esta placa. Como último recorte de corriente por software antes de
aceptar la limitación de hardware, se bajó `WiFi.setTxPower()` de
`WIFI_POWER_8_5dBm` a **`WIFI_POWER_2dBm`** (el mínimo que expone el core)
en `esp32-kiosko.ino`. Si el reinicio persiste incluso con esto, la
conclusión queda asentada como: **limitación de hardware conocida de esta
unidad/placa, pendiente de una fuente de mejor calidad o un capacitor
externo antes del despliegue final del kiosko** — no bloquea seguir
escribiendo el resto del firmware (T-07.3 en adelante) en paralelo.

### 5.4 ✅ Encontrada la causa real del ruido en pantalla — panel ST7789, no ILI9341

El ruido en pantalla resultó ser un problema **separado y distinto** del
brownout de §5.3 — persistía incluso con WiFi/fetch completamente
deshabilitado (bandera `kSaltarWifiYFetch`), o sea que no era de
alimentación. Aislado con un test de `lcd.fillScreen()` directo con
LovyanGFX (sin pasar por LVGL): los colores sólidos salían bien en la
mayor parte de la pantalla, pero **una franja fija en la misma posición
(~15-20% inferior) nunca se actualizaba**, sea cual sea el color pedido —
mismo patrón visto antes con el placeholder de LVGL. Como el defecto
aparecía incluso en un `fillScreen()` sin LVGL de por medio, quedaba claro
que no era un bug de `lvglFlushCb`/buffer, sino algo más abajo, en la
configuración del panel mismo (`LGFX_Config.h`).

**Causa encontrada:** el ESP32-2432S028R tiene dos variantes de hardware
con controladores de panel distintos (ILI9341 o ST7789), indistinguibles
por firmware/ID de chip fácil — la señal conocida en la comunidad es la
cantidad de puertos USB físicos: un solo Micro-USB → ILI9341; Micro-USB +
USB-C → ST7789. Esta unidad tiene **ambos puertos** → es la variante
ST7789. `LGFX_Config.h` tenía configurado `Panel_ILI9341` desde el
principio (T-07.2) — nunca se verificó cuál controlador tenía la unidad
real. Los protocolos ILI9341/ST7789 se parecen lo suficiente como para
dibujar *algo* (de ahí que colores y hasta texto aparecieran, parcialmente
reconocibles) pero no lo bastante como para direccionar el panel completo
de forma consistente — de ahí la franja que nunca se actualizaba.

**Corregido** en `LGFX_Config.h`: `Panel_ILI9341` → `Panel_ST7789`,
`freq_write` 40MHz → 80MHz, `dummy_read_bits` 1 → 16, `offset_rotation`
del touch 0 → 2 (los cuatro valores típicos para la variante ST7789 de
este board, según la comunidad).

**✅ Confirmado en hardware real (2026-07-25):** con el panel corregido y
`kSaltarWifiYFetch` vuelto a `false`, el flujo completo (WiFi → fetch de
`/sectors` (~35-40s) → Landing) corrió de punta a punta **sin reinicios**.
Rotación y touch salieron bien con los valores puestos, sin necesidad de
ajuste adicional. Los reinicios intermitentes que se venían atribuyendo a
brownout (§5.3) no volvieron a aparecer — quedan como sospecha no
confirmada del todo (podrían haber sido, en parte, un síntoma más de mandar
comandos del panel equivocado, no solo alimentación); si reaparecen más
adelante bajo otras condiciones, retomar la mitigación de `WiFi.setTxPower`
y la opción del capacitor de §5.3.

Sources: [Embedded Kiddie — ESP32 2432S028R (CYD) LVGL: ILI9341 vs ST7789](https://embedded-kiddie.github.io/2025/03/09/)

### 5.5 🟡 T-07.3 (portal de configuración) — código escrito, pendiente de hardware

Con T-07.2 cerrado, se implementó el portal de configuración táctil real:

- **`ui_config.cpp`**: pasó de placeholder a un wizard de 3 pasos sobre la
  misma pantalla (mostrando/ocultando contenedores — 320×240 no alcanza
  para todo el formulario + teclado a la vez): 1) elegir red WiFi
  (`lv_dropdown` poblado con `WiFi.scanNetworks()`), 2) password
  (`lv_textarea` en modo password + `lv_keyboard` compartido), 3) URL del
  backend (otro `lv_textarea`, reutiliza el mismo teclado) + botón
  "Guardar y conectar", que prueba la conexión real antes de persistir en
  NVS (`storage_prefs.h`) y reiniciar hacia el flujo normal.
- **Calibración de touch de 4 puntos**: `lcd.calibrateTouch()` es una
  rutina de LovyanGFX (dibuja sus propias cruces, no es un widget LVGL),
  así que corre en `esp32-kiosko.ino` antes de cargar cualquier pantalla,
  no dentro de `ui_config.cpp`. Se corre una sola vez por dispositivo — el
  resultado se persiste en NVS y en arranques siguientes se restaura con
  `lcd.setTouchCalibrate()` sin pedir la calibración de nuevo.
- **Refactor de `net_client`**: `conectarWifi()` se movió desde el `.ino` a
  `net_client.cpp` (ahora `net::conectarWifi`) para que el wizard pueda
  probar la red elegida sin duplicar la lógica. `net::fetchSectores` ahora
  recibe la URL del backend como parámetro (`config.backendUrl`, la que
  guardó el wizard) en vez de leer `kBackendBaseUrl` de `secrets.h`.
- **`secrets.h` cambió de rol, no desapareció.** Ni `net_client.cpp` ni
  `esp32-kiosko.ino` lo referencian, pero `ui_config.cpp` sí lo usa
  (agregado después, a pedido explícito, para agilizar las pruebas
  repetidas) para precargar el campo de URL del backend con
  `kBackendBaseUrl` cuando no hay nada guardado en NVS todavía — ya no es
  un fallback que salta el wizard entero, solo ahorra tipeo. Sigue siendo
  necesario que el archivo exista para compilar (antes no lo era). Con
  esto, no queda pendiente ninguna decisión de retirarlo.

**Sin confirmar en hardware real todavía.** Dos puntos concretos a
verificar en la próxima sesión con la placa:
1. El layout de los 3 pasos (título + widget + botón, con el teclado
   ocupando los ~120px inferiores de los 240px totales) — no se pudo
   previsualizar sin simulador; si algo queda tapado por el teclado o no
   entra, es un ajuste de posiciones/tamaños en `ui_config.cpp`, no un
   problema de diseño de fondo.
2. La firma exacta de `lcd.calibrateTouch(parametros, color_fg, color_bg,
   size)` y `lcd.setTouchCalibrate(parametros)` contra la versión de
   LovyanGFX instalada — se escribió contra el patrón documentado de la
   librería, pero no se pudo compilar en este entorno para confirmarlo
   letra por letra.

### 5.6 ✅ Dos bugs reales encontrados al probar T-07.3 en hardware — corregidos

Primera corrida en hardware real de T-07.3: la interfaz cargó bien, pero
el touch funcionaba mal (a veces no respondía, a veces registraba en el
lugar equivocado, a veces hacía falta tocar varias veces), y nunca
aparecieron las cruces de calibración de 4 puntos en el primer arranque —
pasó directo al portal de configuración. Además, al reintentar conectar
WiFi después de un primer intento fallido, el ESP32 crasheó y reinició
(`E (...) wifi:sta is connecting, cannot set config`, seguido de texto
corrupto en el Serial y el banner de reinicio de siempre).

**Bug 1 — array de calibración de touch del tamaño equivocado.** El punto
2 pendiente de la corrida anterior (§5.5) resultó ser el problema real, no
un detalle menor. Se clonó el repo de LovyanGFX
(`lovyan03/LovyanGFX`, `src/lgfx/v1/LGFXBase.hpp` y `.cpp`) para verificar
la firma contra el código fuente en vez de seguir adivinando:

```cpp
/// This requires a uint16_t array with 8 elements. ( or nullptr )
void calibrateTouch(uint16_t *parameters, const T& color_fg, const T& color_bg, uint8_t size = 10)
...
void calibrate_touch(uint16_t *parameters, ...) {
  ...
  if (nullptr != parameters) {
    memcpy(parameters, orig, sizeof(uint16_t) * 8);
  }
}
```

`storage::CalibracionTouch` (diseñado en T-07.2, antes de poder verificar
esto) tenía 4 campos con nombre (`xMin`/`xMax`/`yMin`/`yMax`), asumiendo
una calibración simple de min/max por eje. Es la firma equivocada: al
pasarle un `uint16_t[4]` a una función que escribe 8 valores vía `memcpy`,
se desbordaba el stack en 8 bytes, corrompiendo memoria vecina — la causa
más probable del touch errático (y posiblemente un factor en el crash de
WiFi también, aunque el bug 2 de abajo alcanza para explicarlo por sí
solo). **Corregido:** `CalibracionTouch::parametros` ahora es
`uint16_t[8]`, guardado/restaurado como bloque opaco vía
`Preferences::putBytes()`/`getBytes()` en `storage_prefs.cpp`, sin
interpretar los valores individualmente.

**Bug 2 — reintentar `WiFi.begin()` sin limpiar el intento anterior
crashea el driver.** Al fallar la primera conexión (timeout de 15s) y
tocar "Guardar y conectar" de nuevo, el driver WiFi del ESP-IDF todavía
tenía el intento anterior en curso a nivel interno (nuestro propio
timeout se rinde, pero el driver sigue reintentando en segundo plano) —
llamar `WiFi.begin()` de nuevo en ese estado tira el error de log
`wifi:sta is connecting, cannot set config` y termina en un reinicio.
**Corregido** en `net::conectarWifi` (`net_client.cpp`): `WiFi.disconnect(true, true)`
+ una pausa corta antes de cada intento, para garantizar un estado limpio
incluso en reintentos.

**Pendiente de confirmar en hardware real:** recompilar con ambos fixes y
verificar que las cruces de calibración aparecen de verdad en el primer
arranque, que el touch responde con precisión después, y que reintentar
una conexión WiFi fallida ya no crashea.

**Segundo intento:** las cruces de calibración siguieron sin aparecer, y
los reinicios con texto corrupto en Serial siguieron pasando, incluso
durante el escaneo de redes (antes de cualquier intento de conexión).
Dos causas distintas, no una sola:

1. **NVS con datos viejos.** El bug 1 de arriba escribía basura en NVS con
   `touch_ok=true` *antes* del fix — como NVS persiste entre flasheos, el
   código ya corregido seguía leyendo esa calibración vieja como "válida"
   y nunca volvía a pedir las 4 cruces. Hace falta **borrar la flash**
   (Tools → Erase All Flash Before Sketch Upload, o `esptool.py
   erase_flash`) para arrancar de cero con el fix ya aplicado — no alcanza
   con solo resubir el sketch.
2. **Gap real en la mitigación de brownout.** `WiFi.setTxPower(WIFI_POWER_2dBm)`
   (§5.3) solo se aplicaba *después* de conectar con éxito, en
   `esp32-kiosko.ino` — pero el escaneo de redes de `ui_config.cpp` y los
   reintentos de conexión (que es justo donde más se vio inestabilidad)
   corrían a full power, sin ninguna mitigación. **Corregido:** el
   `setTxPower` se movió a `net::conectarWifi()` (cubre conexión y
   reintentos) y se agregó también antes de `WiFi.scanNetworks()` en
   `ui_config.cpp`.

**Pendiente de confirmar en hardware real (otra vez):** borrar la flash
antes de la próxima prueba para que la calibración corra de cero, y
verificar si con el TX power ya aplicado también durante el escaneo la
inestabilidad desaparece del todo.

**✅ Confirmado en hardware real (2026-07-25), tercer intento:** con la
flash borrada, las cruces de calibración corrieron bien, el touch quedó
preciso, y el wizard completo (red → password → URL → "Guardar y
conectar") funcionó de punta a punta sin reinicios ni corrupción de
Serial. **T-07.3 queda cerrado.**

Además, a pedido del equipo, se agregó una precarga de conveniencia: el
campo de URL del backend (paso 3) ahora se completa automáticamente con
`kBackendBaseUrl` de `secrets.h` cuando no hay nada guardado en NVS
todavía (sigue siendo editable) — esto le devuelve un uso real a
`secrets.h`, que había quedado sin ninguno tras el refactor de T-07.3.
Como ahora `ui_config.cpp` lo incluye, `secrets.h` volvió a ser
obligatorio para compilar (ver `README.md` del firmware, sección "Cómo
correrlo").

### 5.7 🟡 T-07.4 (Landing) — código escrito, pendiente de hardware

Con T-07.3 cerrado, se implementó la pantalla Landing real:

- **`ui_landing.cpp`**: al construir la pantalla, hace su propio fetch de
  `/sectors` (`net::fetchSectores`, mismo patrón que `ui_config.cpp` con
  `WiFi.scanNetworks()` — sincrónico/bloqueante). Muestra una pantalla de
  "Cargando datos de sectores..." de inmediato (cargada y pintada a la
  fuerza con `lv_timer_handler()` antes de bloquear en el fetch, y borrada
  después con `lv_obj_del()`) — agregada tras probar en hardware real que,
  sin esto, la pantalla anterior (Details, o la misma Landing si se volvió
  desde ahí) quedaba "congelada" ~35-40s sin ningún indicio de que estaba
  cargando. Es una excepción al resto del firmware (que no libera
  pantallas viejas al navegar): esta sí, porque se crea en cada entrada a
  la Landing (arranque + cada "Volver"), no una sola vez — dejarla sin
  liberar acumularía memoria indefinidamente en una sesión larga de
  kiosko. Calcula client-side el PM2.5 promedio de ciudad
  (solo sectores con `pm25_promedio` no nulo) y el conteo por `estado`, los
  muestra en un header, y lista los 22 sectores en un `lv_list` con el
  fondo de cada fila teñido según su color de estado. Tocar una fila
  navega a Details (`ui_details::construirPantalla(id)`, todavía
  placeholder de T-07.5/T-07.6).
- **Gesto pendiente de T-07.3 resuelto**: mantener presionado el header
  ~2s vuelve al portal de configuración. Implementado con
  `indevDrv.long_press_time = 2000` en `esp32-kiosko.ino` (es una config
  global del indev en LVGL v8, no por widget — no hay otro uso de
  long-press en el resto de las pantallas todavía, así que no genera
  conflicto).
- **Limpieza en `esp32-kiosko.ino`**: se sacó el fetch de "smoke test" que
  vivía ahí desde T-07.2 (quedaba duplicado con el de `ui_landing.cpp`) y
  la bandera `kSaltarWifiYFetch` (diagnóstico de la investigación del
  panel ST7789, ya resuelta — dejarla habría sido código muerto, además de
  quedar rota: `ui_landing.cpp` siempre hace su propio fetch ahora,
  saltarlo desde el `.ino` ya no tenía el efecto que tuvo en su momento).

**Simplificación aceptada, a mejorar más adelante si hace falta:** cada
fila del `lv_list` guarda el `id` del sector en un `String*` propio
(`new String(id)`, nunca liberado) porque el `JsonDocument` del fetch deja
de ser válido apenas `construirPantalla()` retorna, mucho antes de que el
usuario llegue a tocar una fila — mismo criterio informal que ya usa el
resto del firmware (pantallas no se liberan explícitamente al navegar
entre ellas).

**✅ Confirmado en hardware real (2026-07-25):** compiló y desplegó bien —
las 22 comunas y los agregados de ciudad se ven correctamente. **T-07.4
queda cerrado.**

### 5.8 🟡 T-07.5/T-07.6 (Details) — código escrito, pendiente de hardware

Implementadas juntas (mismo `lv_tabview`, no tenía sentido separarlas):

- **`net_client`**: dos fetches nuevos, `fetchDetalleSector()` (`GET
  /sectors/{id}`) y `fetchRiesgoSector()` (`GET /risk/{sector}`) —
  payloads chicos (~2-3KB y <1KB, `08-Arquitectura-ESP32.md` §9), así que
  usan un `HTTPClient::getString()` + `deserializeJson()` simple
  (`fetchJsonSimple`, factorizado), sin el streaming/filtro de
  `fetchSectores()` (pensado para las 774KB de `/sectors`). De paso se
  factorizó `normalizarBaseUrl()` (la lógica de sacar el `/` final), antes
  duplicada solo dentro de `fetchSectores`.
- **`ui_details.cpp`**: `lv_tabview` con pestañas "Resumen" (PM2.5 con
  badge de color + CO2 + humedad + `lv_chart` de `historial_24h`, con
  huecos explícitos vía `LV_CHART_POINT_NONE` en vez de inventar puntos) e
  "Historia" (promedio anual, peor/mejor mes, días sobre el límite OMS,
  banner si `historico_suficiente: false`). Sin pestaña Sensores, como
  documenta `08-Arquitectura-ESP32.md` §3.
- **Verificación de API evitó otro bug tipo "LovyanGFX"**: antes de asumir
  cómo se comportan los tipos `JsonVariant`/`JsonObject` de ArduinoJson en
  conversiones implícitas (rango-for sobre `JsonArray`, asignar
  `doc["campo"]` a `JsonVariantConst`), se revisó el código fuente real de
  la librería instalada (`D:\Documentos\Arduino\libraries\ArduinoJson\src`)
  en vez de repetir el mismo error de adivinar una firma sin confirmar —
  confirmado el operador de conversión genérico en
  `VariantRefBase.hpp:51-54` (`operator T() const { return as<T>(); }`),
  que cubre todos los casos usados.

**"Última lectura hace X"** (`08-Arquitectura-ESP32.md` §4.2) todavía
muestra el timestamp crudo del backend sin relativizar — es el fallback
que ese mismo párrafo documenta para cuando no hay NTP (T-07.8, no
implementado todavía), no un atajo nuestro.

**✅ Confirmado en hardware real (2026-07-25):** compiló y anduvo bien.
**T-07.5 y T-07.6 quedan cerrados.**

**Hallazgo del usuario, corregido en la misma sesión:** la primera versión
no tenía ninguna forma de volver de Details a la Landing (el gesto de
mantener presionado ~2s solo existe en el header de la Landing, para ir
al portal de configuración — no aplica desde Details). Se agregó un botón
"Volver" en `ui_details.cpp`, como hermano del `lv_tabview` (no dentro,
para que quede visible sin importar qué pestaña esté activa) usando el
mismo patrón de `pantalla` con `lv_flex_flow` columna + `flex_grow` en el
tabview que ya usa `ui_landing.cpp` — sin tocar el layout interno del
`lv_tabview` para no arriesgar romper algo no probado.

**Bug real encontrado al agregar la pantalla de carga de la Landing
("no hace ninguna acción o se demora mucho"):** `lv_timer_handler()`
llamado **recursivamente** — `ui_landing::construirPantalla()` lo llamaba
para forzar el pintado de "Cargando..." antes del fetch, pero esa función
se dispara desde un callback de touch (`alTocarSector`/`alVolver`/etc.)
que ya corre **dentro** del `lv_timer_handler()` de `loop()`. LVGL no
soporta llamarlo reentrante — causa cuelgues/demoras impredecibles, no un
crash limpio. **Mismo bug existía ya en `ui_config.cpp`** (`alGuardar`,
para pintar "Conectando..."/"Conectado. Reiniciando..." antes de bloquear
en `conectarWifi()`/`ESP.restart()`) desde T-07.3 — no se había notado
porque los síntomas (demora/comportamiento raro) se venían atribuyendo al
brownout/panel de esa época, no a esto.

**Corregido en ambos archivos:** verificado contra el código fuente real
de LVGL instalado (`D:\Documentos\Arduino\libraries\lvgl\src\core\lv_refr.h`)
que existe `lv_refr_now(lv_disp_t*)`, documentada explícitamente para este
caso ("e.g. progress bar... this function can be called when the screen
should be updated") — solo fuerza el redibujado, sin procesar indev/
timers, segura de llamar desde un callback. Reemplaza los tres
`lv_timer_handler()` sueltos (`ui_landing.cpp` y los dos de
`ui_config.cpp::alGuardar`). El único `lv_timer_handler()` que queda en
todo el firmware es el de `loop()` en `esp32-kiosko.ino`, que es correcto.

---

## 6. Orden sugerido de alto nivel

```
✅ Decisión ClickHouse tomada (sección 1) — acceso confirmado
        │
        ├── Backend: conseguir credenciales propias + confirmar catálogo sensor→sector (2.2, 2.3)
        ├── Backend: limpiar scope (auth/chatbot/game) — en paralelo, no depende de nada
        ├── Backend: cliente ClickHouse + sectorización + 4 endpoints (2.4)
        │
        ├── Frontend: arranque + extracción header/footer (pasos 1-3, sección 3)
        ├── Frontend: mapa real conectado a MockRepository primero, backend después (pasos 4-5)
        ├── Frontend: limpieza (pasos 6-8, sección 3) — en paralelo con lo anterior
        │
        └── Integración real backend↔frontend (sección 4)
                │
                └── Frontend: sector_detail_page.dart (pestañas Resumen/Historia/Sensores), ya contra backend real (paso 9, sección 3)
```

La limpieza del frontend (pasos 1-3 y 6-8) y la limpieza de scope del backend (auth/chatbot/game, ✅ ya ejecutada — ver sección 1) no dependen de nada más y se pueden empezar ya, en paralelo. Conseguir las credenciales reales de ClickHouse y confirmar el catálogo sensor→sector (2.2, 2.3) son los dos bloqueantes concretos antes de poder escribir `clickhouse_client.py` de verdad.
