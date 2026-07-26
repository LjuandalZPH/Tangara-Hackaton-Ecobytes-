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

**Queda abierto** (ver `07-Integracion-Backend-Frontend.md` §8): solo `GET /education` sigue sin conectar (la página Aprende es contenido estático propio). `GET /sectors/{id}` y `GET /risk/{sector}` ya tienen UI (paso 9), `_SidePanelSection` ya se conectó a datos reales (paso 10), y la landing completa (`StatsBar`, `hero_section.dart`, `dashboard_preview_section.dart`) ya no usa `MockSensorRepository` (paso 10, 2026-07-24) — ese archivo, junto con `sensor_data.dart`, `control_sidebar.dart` y `dashboard_layout.dart`, se eliminó del repo por completo.

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
