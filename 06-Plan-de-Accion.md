# 🗺️ Plan de Acción — Cierre de Brechas EcoBytes

**Última actualización:** 2026-07-22

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

**Lo que se retira sin ambigüedad, independiente de la base de datos:** los stubs `auth.py`, `chatbot.py`, `game.py` y los modelos `User`, `GameScore` — fuera del alcance documentado, sin consumidor en el frontend (cero referencias a gamificación en todo `lib/`). ✅ **Ejecutado (2026-07-22):** routers y modelos eliminados; `requirements.txt` sin `langchain`/`langchain-openai`/`langchain-anthropic`/`python-jose`/`passlib`; `main.py` sin sus imports/`include_router`; `.env.example` y `Settings` (`db/database.py`) sin las variables `JWT_*`/`LLM_PROVIDER`/`ANTHROPIC_API_KEY`/`OPENAI_API_KEY`.

**Lo que se retira porque ya no aplica al migrar a ClickHouse:** `db/database.py`, `models/sensor.py` (el modelo SQLAlchemy de `SensorReading`), y `scripts/ingest_csv.py` (la ingesta por CSV a Postgres deja de tener sentido si los datos ya están en ClickHouse vía el pipeline InfluxDB→ClickHouse existente).

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

- [ ] Conseguir credenciales propias para EcoBytes (el ejemplo del repo usa un "usuario_analista" genérico — confirmar si ya tienen uno asignado o hay que solicitarlo).
- [ ] Añadir `clickhouse-connect` a `requirements.txt`, retirando `asyncpg`, `sqlalchemy[asyncio]`, `alembic`.
- [ ] **Verificar antes de implementar:** el script de referencia usa `clickhouse_connect.get_client(...)` de forma síncrona. FastAPI es async — confirmar si la versión de `clickhouse-connect` a usar expone un cliente async nativo, o si hay que envolver las llamadas síncronas con `starlette.concurrency.run_in_threadpool` para no bloquear el event loop.
- [ ] Implementar `services/clickhouse_client.py` reemplazando los esqueletos de `03-Arquitectura-Backend.md` §4 con nombres de tabla/columna reales (`tangara_plata.plata_tangara_sensores`, columnas `name`/`time`/`pm25`/`co2`/`hum`/`tmp`, no `tangara_gold.promedios_horarios`).

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
- [ ] Decodificar la columna `geo` de `tangara_plata` (geohash → lat/lon, con una librería estándar tipo `pygeohash`) para obtener la ubicación real y viva de cada sensor — no depende de ningún catálogo externo desactualizado.
- [ ] Con lat/lon decodificado + el GeoJSON de comunas ya descargado, resolver sector con `shapely` (point-in-polygon) tal como ya plantea `03-Arquitectura-Backend.md` §5 — esto sí se puede seguir literal, solo cambia de dónde sale el lat/lon de cada sensor.
- [ ] Cachear el mapeo sensor→sector resultante (los sensores son fijos, no hace falta recalcularlo en cada request) — puede vivir en el mismo `services/cache.py` con TTL largo, o precalcularse una vez al startup igual que el GeoJSON.
- [ ] **Nota de granularidad:** si más adelante se necesita nivel de barrio (no solo comuna), la misma capa IDESC (`dapm` workspace en GeoServer) probablemente tiene una capa de barrios equivalente — no se buscó todavía porque el alcance actual de `03-Arquitectura-Backend.md` habla de "sectores" a nivel de comuna.

### 2.4 Resto del plan de backend

- [ ] Implementar `services/geo.py` con `SectorIndex` (cargando `Backend/data/sectores.geojson`, ya en el repo, + `shapely`) para resolver el `sector_id` de cada sensor, según el mapeo de 2.3.
- [ ] Reformar los endpoints para cumplir el contrato documentado: `GET /sectors`, `GET /sectors/{id}`, `GET /risk/{sector}`, `GET /education`.
- [ ] Agregar caché en memoria con TTL corto para `/sectors` (`services/cache.py`, según `03-Arquitectura-Backend.md` §1.4) — más importante todavía si cada request agrega sobre Plata en vez de leer de un Gold pre-agregado.
- [ ] Actualizar `03-Arquitectura-Backend.md` §4 y §6 con los nombres reales de tabla/columna y variables de entorno una vez implementado, para que el documento deje de tener el esqueleto hipotético.

---

## 3. Frontend — orden recomendado (actualiza EPI-01 del backlog con los hallazgos nuevos)

El orden importa: varios pasos del backlog original (`T-00.4`, eliminar landing) rompen la compilación si no se hace primero el paso de extracción del header/footer.

1. [ ] **Resolver la duplicación de arranque**: decidir entre `lib/main.dart` (`MyApp`, entrypoint real hoy) y `lib/app.dart` (`EcoBytesApp`, con su propio router, no usado) — quedarse con uno solo y borrar el otro.
2. [ ] **Extraer `LandingHeader`, `LandingFooter`, `LandingMobileNav`** de `features/landing/presentation/widgets/` hacia `shared/widgets/` — son el header/footer global de toda la app (los usan `dashboard`, `learn` y `chatbot`), no exclusivos de la landing. Esto es lo que desbloquea poder borrar `landing/` sin romper nada.
3. [ ] **Corregir `test/widget_test.dart`** para que monte el widget raíz real (el que quede tras el paso 1), no el que no se usa.
4. [ ] **Reemplazar el placeholder de `MapaPage`** (el `Container` con `GridPaper` y el texto `"[ Espacio reservado para mapa interactivo ]"`) por el componente `MapArea` ya existente (real, con `flutter_map`), conectándolo a datos reales en vez de a los sectores hardcodeados que trae hoy. No hay que construir un mapa desde cero — ya existe, solo está mal enrutado.
5. [ ] **Decidir sobre `SensorBloc`**: o se conecta de verdad (reemplazando el `TODO` por un repositorio HTTP contra el backend) y se usa en `MapaPage`/`MapArea`, o se elimina si se prefiere resolver el estado de otra forma. No dejarlo como andamiaje muerto.
6. [ ] **Eliminar carpetas de plataformas nativas** (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) — corresponde a `T-00.1`, ahora sin el bloqueo del paso 2.
7. [ ] **Eliminar `features/landing/` y `features/chatbot/`** — corresponde a `T-00.4`, ahora seguro tras el paso 2.
8. [ ] **Simplificar `app_router.dart`/`AppRoutes`** a solo `/mapa`, `/aprende` y la nueva `/riesgo` — corresponde a `T-00.5`.
9. **DECISIÓN** — [ ] `flutter_bloc` vs `Provider`: los docs piden `Provider` por simplicidad, pero el código ya tiene un patrón Bloc funcional (aunque desconectado). Migrar tiene costo y bajo beneficio real para 3-4 pantallas sin lógica compleja; la alternativa más barata es **aceptar `flutter_bloc` como la decisión final** y actualizar `04-Arquitectura-Frontend.md` en vez de migrar. Recomiendo esto último salvo que el equipo tenga una razón de peso para migrar.
10. [ ] **Construir `features/risk/`** desde cero (selector de barrio, `RiskProvider`/bloc equivalente, tarjeta de perfil histórico) — es la única pantalla que no existe en absoluto (EPI-04 del backlog), y depende de que el backend exponga `GET /risk/{sector}` (sección 2).
11. [ ] Si se conserva alguna sección de landing (fuera del alcance documentado, pero por si el equipo decide mantenerla como página de marketing separada): corregir el typo "BitAVIT Labs" → "Bit&Volt Labs" en `landing_footer.dart`, y marcar las cifras de `StatsBar` como ilustrativas o quitarlas.
12. [ ] Conectar `features/learn/` a datos reales o confirmar que se queda como contenido estático (`T-05.2` del backlog — decisión ya identificada como pendiente, de baja prioridad).

---

## 4. Integración backend↔frontend

Bloqueado hasta que la sección 2 entregue los endpoints `/sectors`, `/sectors/{id}`, `/risk/{sector}` reales:

- [ ] Reemplazar `MockSensorRepository` por un cliente HTTP real contra el backend (dentro de `SensorBloc` o el repositorio que se decida en el paso 5 de la sección 3).
- [ ] Confirmar CORS del backend contra el dominio de desarrollo del frontend (`T-00.7` del backlog).
- [ ] Verificar el polling de 30-60s contra el backend real (hoy no hay polling real porque no hay llamada real).

---

## 5. Orden sugerido de alto nivel

```
✅ Decisión ClickHouse tomada (sección 1) — acceso confirmado
        │
        ├── Backend: conseguir credenciales propias + confirmar catálogo sensor→sector (2.2, 2.3)
        ├── Backend: limpiar scope (auth/chatbot/game) — en paralelo, no depende de nada
        ├── Backend: cliente ClickHouse + sectorización + 4 endpoints (2.4)
        │
        ├── Frontend: arranque + extracción header/footer (pasos 1-3, sección 3)
        ├── Frontend: mapa real conectado a MockRepository primero, backend después (pasos 4-5)
        ├── Frontend: limpieza (pasos 6-9, sección 3) — en paralelo con lo anterior
        │
        └── Integración real backend↔frontend (sección 4)
                │
                └── Frontend: /riesgo nuevo, ya contra backend real (paso 10, sección 3)
```

La limpieza del frontend (pasos 1-3 y 6-9) y la limpieza de scope del backend (auth/chatbot/game, ✅ ya ejecutada — ver sección 1) no dependen de nada más y se pueden empezar ya, en paralelo. Conseguir las credenciales reales de ClickHouse y confirmar el catálogo sensor→sector (2.2, 2.3) son los dos bloqueantes concretos antes de poder escribir `clickhouse_client.py` de verdad.
