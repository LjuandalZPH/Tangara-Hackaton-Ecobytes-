# ⚙️ Arquitectura Backend — EcoBytes

**Stack:** FastAPI (Python) · Cliente ClickHouse async (`clickhouse-connect`) · `shapely` para geometría

> Un único servicio, sin estado propio, sin base de datos propia más allá de un archivo GeoJSON estático. Todo dato de sensores viene de la capa **Plata** de ClickHouse (`tangara_plata.plata_tangara_sensores`), normalizada pero sin agregar — el propio backend calcula promedios, últimas lecturas y agrupación por sector.

> **Decisión de arquitectura (actualizada 2026-07-22):** este documento originalmente apuntaba a una capa Gold pre-agregada. Se verificó contra el repositorio real del pipeline (`sebaxtian/clickhouse-tangara`) que `tangara_gold` está marcada como "planificada" y no existe, y dado el cronograma de la hackathon, el equipo decidió **no esperarla**: la fuente de datos definitiva es `tangara_plata`, con la agregación resuelta en el backend de EcoBytes. Esta ya no es una nota temporal — es la arquitectura vigente. Si en el futuro el pipeline construye Gold, migrar estas queries sería una optimización de rendimiento, no un requisito. Detalle técnico verificado (librería de conexión, variables de entorno reales, esquema de columnas) en [`06-Plan-de-Accion.md`](./06-Plan-de-Accion.md) §2.

---

## 1. Principios de diseño

1. **El backend no almacena nada que no sea efímero.** Toda la persistencia real vive en ClickHouse; el servicio mismo no mantiene estado propio más allá del caché de corta duración.
2. **Solo lectura hacia ClickHouse.** El backend nunca escribe en `tangara_plata` ni `tangara_bronce`. La ingesta hacia esas capas es responsabilidad del pipeline existente, fuera de este repositorio — pero la **agregación** (promedios, última lectura, agrupación por sector) sí es responsabilidad de EcoBytes, porque `tangara_plata` no viene pre-agregada.
3. **Geometría en memoria, no en base de datos.** El archivo `sectores.geojson` se carga una vez al iniciar el servicio y se mantiene en memoria. Resolver "¿a qué sector pertenece este punto?" es una operación de `shapely`, no una query SQL.
4. **Todo endpoint es idempotente y cacheable.** Cualquier respuesta puede cachearse por unos segundos sin efectos secundarios — útil para absorber el polling del frontend sin golpear ClickHouse en cada refresco.

---

## 2. Estructura del proyecto

```scheme
backend/
├── main.py                     # App FastAPI, CORS, carga de GeoJSON al startup
├── config.py                   # Settings (.env) + constantes de dominio (umbrales OMS, TTLs)
├── routers/
│   ├── sectors.py              # GET /sectors, GET /sectors/{id}
│   ├── risk.py                 # GET /risk/{sector}
│   └── education.py            # GET /education
├── services/
│   ├── clickhouse_client.py    # Cliente async, queries + agregación sobre tangara_plata
│   ├── geo.py                  # Carga de GeoJSON + point-in-polygon (shapely)
│   └── cache.py                # Cache en memoria con TTL corto (ej. cachetools)
├── data/
│   ├── sectores.geojson        # Polígonos de comunas/barrios de Cali
│   └── educacion.json          # Contenido estático de la sección educativa
├── .env.example
└── requirements.txt
```

---

## 3. Endpoints

### `GET /sectors`
Devuelve todos los sectores con su color/estado actual, para pintar el mapa.

**Response:**
```json
{
  "sectores": [
    {
      "id": "comuna-2",
      "nombre": "Comuna 2",
      "geometry": { "type": "Polygon", "coordinates": [...] },
      "pm25_promedio": 34.2,
      "estado": "amarillo",
      "ultima_lectura": "2026-07-21T14:32:00Z",
      "sin_datos_recientes": false
    }
  ]
}
```

**Lógica interna:**
1. `services/geo.py` devuelve la lista de sectores con sus polígonos (desde memoria).
2. `services/clickhouse_client.py` consulta `tangara_plata` y calcula el último promedio de PM2.5 por sensor (agregación propia, ver sección 4), agrupado por sector (join en memoria contra el mapeo sensor→sector definido en el GeoJSON o un archivo de mapeo aparte).
3. Se calcula `estado` (verde/amarillo/rojo) según umbrales OMS fijos en configuración.
4. Si `ultima_lectura` tiene más de 1 hora, `sin_datos_recientes = true` y `estado = "gris"`.
5. Respuesta cacheada 30 segundos (`services/cache.py`) para absorber el polling de múltiples clientes sin repetir la query a ClickHouse en cada request.

### `GET /sectors/{id}`
Detalle de un sector: PM2.5, CO2, humedad y timestamp exactos (última hora), más un historial horario corto — para la pantalla de detalle de sector que se abre desde el mapa (ver `04-Arquitectura-Frontend.md` §6, pestaña "Resumen").

**Response:**
```json
{
  "id": "comuna-2",
  "nombre": "Comuna 2",
  "pm25_promedio": 11.27,
  "co2_promedio": 412.5,
  "hum_promedio": 68.2,
  "ultima_lectura": "2026-07-23T05:49:40",
  "sin_datos_recientes": false,
  "estado": "verde",
  "historial_24h": [
    { "hora": "2026-07-22T06:00:00", "pm25_promedio": 9.8 },
    { "hora": "2026-07-22T07:00:00", "pm25_promedio": 10.4 }
  ]
}
```

`historial_24h` (actualizado 2026-07-23, `services/clickhouse_client.py:promedio_horario`) es el promedio de PM2.5 por hora de los sensores del sector en las últimas `HORAS_HISTORIAL_SECTOR` horas (24 por defecto, `config.py`), ya calibrado por humedad igual que el resto de los valores de PM2.5 — nunca el crudo. Si el sector no tiene sensores mapeados, o ninguno tuvo lecturas en la ventana, llega como lista vacía `[]` (nunca se rellena con datos inventados). No es un endpoint nuevo: es el mismo `GET /sectors/{id}` con un campo adicional, así que el contrato sigue siendo exactamente estos 4 endpoints.

### `GET /risk/{sector}`
Perfil histórico: peor mes, mejor mes, promedio anual, días sobre límite OMS.

**Response:**
```json
{
  "sector": "comuna-2",
  "promedio_anual": 28.4,
  "peor_mes": { "mes": "2026-01", "promedio": 41.2 },
  "mejor_mes": { "mes": "2026-05", "promedio": 19.8 },
  "dias_sobre_limite_oms_ultimo_anio": 47,
  "historico_suficiente": true
}
```

Si el sector tiene menos de un umbral mínimo de datos históricos (ej. menos de 3 meses), `historico_suficiente: false` y el frontend debe mostrarlo explícitamente en vez de presentar un promedio poco confiable.

### `GET /education`
Devuelve el contenido estático de `data/educacion.json`. No requiere lógica adicional — es deliberadamente el endpoint más simple del sistema.

---

## 4. Consultas a ClickHouse — patrones clave

Todas las queries del backend apuntan **exclusivamente a `tangara_plata.plata_tangara_sensores`** (nunca a Bronce directamente). A diferencia del plan original, esta tabla **no** viene pre-agregada — cada fila es una lectura individual de un sensor (columnas: `time` `DateTime64`, `name` `String`, `geo` `String`, `tmp`/`hum`/`pm25`/`co2` `Nullable(Float32)`). El backend es responsable de agregar (`GROUP BY`, `avg()`, `max()`) en cada query, apoyándose en la capa de caché (`services/cache.py`) para no repetir el trabajo en cada refresco del polling — incluso sobre el histórico de 62M+ filas, ClickHouse resuelve este tipo de agregación analítica con rapidez.

**Cliente async nativo (verificado).** La duda que planteaba este documento —si había que envolver el cliente con `starlette.concurrency.run_in_threadpool`— quedó resuelta: `clickhouse-connect` expone `get_async_client()`, así que no hace falta el threadpool. El cliente se crea una sola vez (singleton perezoso) y se cierra en el `shutdown` de FastAPI.

```python
# services/clickhouse_client.py (implementación real)

_client = await clickhouse_connect.get_async_client(
    host=..., port=..., username=..., password=..., database="tangara_plata", secure=True
)

async def ultimo_promedio_por_sensor() -> list[dict]:
    # geohashDecode() resuelve la posición del sensor en la propia query:
    # la columna `geo` es un geohash, y así se evita una dependencia extra
    # de decodificación en Python. Devuelve Tuple(longitude, latitude).
    query = """
        SELECT
            name,
            avg(pm25) AS pm25_promedio,
            avg(co2)  AS co2_promedio,
            avg(hum)  AS hum_promedio,
            max(time) AS ultima_lectura,
            geohashDecode(argMax(geo, time)) AS coords
        FROM tangara_plata.plata_tangara_sensores
        WHERE time >= now() - INTERVAL 1 HOUR
        GROUP BY name
    """
    return _rows_to_dicts(await client.query(query))

async def promedio_mensual(sensores: list[str]) -> list[dict]:
    query = """
        SELECT toStartOfMonth(time) AS mes, avg(pm25) AS pm25_promedio
        FROM tangara_plata.plata_tangara_sensores
        WHERE name IN {sensores:Array(String)}
          AND time >= now() - INTERVAL 1 YEAR
        GROUP BY mes
        ORDER BY mes
    """
    return _rows_to_dicts(await client.query(query, parameters={"sensores": sensores}))
```

Además de estas dos, el módulo expone `posiciones_sensores()` (última posición de cada sensor, para construir el mapeo sensor→sector una sola vez), `dias_sobre_limite(sensores, umbral)` (días del último año cuyo promedio diario superó el umbral OMS, para `/risk/{sector}`) y `promedio_horario(sensores, horas)` (promedio de PM2.5 por hora en la ventana dada, para el `historial_24h` de `GET /sectors/{id}` — mismo patrón que `promedio_mensual` pero con `toStartOfHour(time)` en vez de `toStartOfMonth(time)`).

---

## 5. Resolución de geometría

```python
# services/geo.py (esqueleto)

from shapely.geometry import shape, Point
import json

class SectorIndex:
    def __init__(self, geojson_path: str):
        with open(geojson_path, encoding="utf-8") as f:
            data = json.load(f)
        self.sectores = [self._normalizar(f) for f in data["features"]]

    @staticmethod
    def _normalizar(feature: dict) -> dict:
        # El GeoJSON oficial de IDESC trae `comcodigo` ("01".."22") y
        # `comnombre` ("Comuna 01"), no `id`/`nombre`: se traduce aquí al
        # contrato público de la API definido en §3.
        codigo = int(feature["properties"]["comcodigo"])
        return {
            "id": f"comuna-{codigo}",
            "nombre": f"Comuna {codigo}",
            "geometry": feature["geometry"],
            "geom": shape(feature["geometry"]),
        }

    def resolver_sector(self, lat: float, lon: float) -> str | None:
        punto = Point(lon, lat)
        for sector in self.sectores:
            if sector["geom"].contains(punto):
                return sector["id"]
        return None
```

Se carga **una sola vez** al iniciar FastAPI (`main.py`, evento `startup`) y vive en memoria durante toda la ejecución del servicio. Con el número de sectores de Cali (22 comunas, no miles), esto es instantáneo.

---

## 6. Variables de entorno

Nombres reales, verificados contra el cliente `clickhouse-connect` usado por el pipeline (no un único `CLICKHOUSE_URL`; no existe un flag `CLICKHOUSE_READONLY` — el acceso de solo lectura se controla por permisos del usuario en el propio ClickHouse):

```bash
CLICKHOUSE_HOST=...
CLICKHOUSE_PORT=443
CLICKHOUSE_USER=...
CLICKHOUSE_PASSWORD=...
CLICKHOUSE_DATABASE=tangara_plata
CLICKHOUSE_SECURE=True
```

---

## 7. Contrato de API con el frontend

Estos cuatro endpoints son el contrato completo entre backend y frontend. El equipo de Flutter puede construir su capa de datos (modelos, cliente HTTP) directamente contra estas respuestas sin esperar a que el backend esté 100% desplegado — basta con fijar el contrato temprano y, si hace falta, levantar un servidor de datos de prueba con estas mismas formas de respuesta.

---

## 8. Definition of Done (backend)

- Endpoints documentados automáticamente en Swagger (`/docs`).
- Ninguna query del backend toca `tangara_bronce` directamente — solo `tangara_plata`, agregando en el propio backend.
- Todo endpoint responde en menos de 1s con caché tibia.
- `sectores.geojson` versionado en el repo; cualquier cambio a los polígonos pasa por PR.
- `requirements.txt` contiene únicamente las dependencias necesarias para el alcance actual del servicio.
- CORS configurado explícitamente para el dominio donde se despliega el frontend Flutter Web.
