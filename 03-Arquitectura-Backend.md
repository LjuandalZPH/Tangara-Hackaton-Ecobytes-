# ⚙️ Arquitectura Backend — EcoBytes

**Stack:** FastAPI (Python) · Cliente ClickHouse async · `shapely` para geometría

> Un único servicio, sin estado propio, sin base de datos propia más allá de un archivo GeoJSON estático. Todo dato de sensores viene de la capa Gold de ClickHouse, ya calibrada y agregada por el pipeline de Tángara.

---

## 1. Principios de diseño

1. **El backend no almacena nada que no sea efímero.** Toda la persistencia real vive en ClickHouse; el servicio mismo no mantiene estado propio más allá del caché de corta duración.
2. **Solo lectura hacia ClickHouse.** El backend nunca escribe en `tangara_gold`, `tangara_plata` ni `tangara_bronce`. La ingesta y calibración son responsabilidad del pipeline existente, fuera de este repositorio.
3. **Geometría en memoria, no en base de datos.** El archivo `sectores.geojson` se carga una vez al iniciar el servicio y se mantiene en memoria. Resolver "¿a qué sector pertenece este punto?" es una operación de `shapely`, no una query SQL.
4. **Todo endpoint es idempotente y cacheable.** Cualquier respuesta puede cachearse por unos segundos sin efectos secundarios — útil para absorber el polling del frontend sin golpear ClickHouse en cada refresco.

---

## 2. Estructura del proyecto

```scheme
backend/
├── main.py                     # App FastAPI, CORS, carga de GeoJSON al startup
├── routers/
│   ├── sectors.py              # GET /sectors, GET /sectors/{id}
│   ├── risk.py                 # GET /risk/{sector}
│   └── education.py            # GET /education
├── services/
│   ├── clickhouse_client.py    # Cliente async, queries a tangara_gold
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
2. `services/clickhouse_client.py` consulta el último promedio de PM2.5 por sensor en `tangara_gold`, agrupado por sector (join en memoria contra el mapeo sensor→sector definido en el GeoJSON o un archivo de mapeo aparte).
3. Se calcula `estado` (verde/amarillo/rojo) según umbrales OMS fijos en configuración.
4. Si `ultima_lectura` tiene más de 1 hora, `sin_datos_recientes = true` y `estado = "gris"`.
5. Respuesta cacheada 30 segundos (`services/cache.py`) para absorber el polling de múltiples clientes sin repetir la query a ClickHouse en cada request.

### `GET /sectors/{id}`
Detalle de un sector: PM2.5, CO2, humedad y timestamp exactos, para la tarjeta que aparece al tocar un sector en el mapa.

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

Todas las queries del backend apuntan **exclusivamente a `tangara_gold`** (la capa ya agregada y calibrada), nunca a Bronce o Plata directamente. Esto mantiene las respuestas rápidas incluso sobre el histórico completo de varios años, porque `tangara_gold` ya contiene agregaciones precalculadas y no las decenas de millones de filas crudas.

```python
# services/clickhouse_client.py (esqueleto)

async def ultimo_promedio_por_sensor() -> list[dict]:
    query = """
        SELECT name, avg(pm25) AS pm25_promedio, max(time) AS ultima_lectura
        FROM tangara_gold.promedios_horarios
        WHERE time >= now() - INTERVAL 1 HOUR
        GROUP BY name
    """
    return await client.query(query)

async def perfil_historico(sector_sensores: list[str]) -> dict:
    query = """
        SELECT
            toStartOfMonth(time) AS mes,
            avg(pm25) AS promedio
        FROM tangara_gold.promedios_horarios
        WHERE name IN {sensores:Array(String)}
        GROUP BY mes
        ORDER BY promedio
    """
    return await client.query(query, parameters={"sensores": sector_sensores})
```

---

## 5. Resolución de geometría

```python
# services/geo.py (esqueleto)

from shapely.geometry import shape, Point
import json

class SectorIndex:
    def __init__(self, geojson_path: str):
        with open(geojson_path) as f:
            data = json.load(f)
        self.sectores = [
            {"id": f["properties"]["id"], "nombre": f["properties"]["nombre"],
             "geom": shape(f["geometry"])}
            for f in data["features"]
        ]

    def resolver_sector(self, lat: float, lon: float) -> str | None:
        punto = Point(lon, lat)
        for sector in self.sectores:
            if sector["geom"].contains(punto):
                return sector["id"]
        return None
```

Se carga **una sola vez** al iniciar FastAPI (`main.py`, evento `startup`) y vive en memoria durante toda la ejecución del servicio. Con el número de sectores de Cali (decenas, no miles), esto es instantáneo.

---

## 6. Variables de entorno

```scheme
CLICKHOUSE_URL=http://user:password@host:8123/tangara_gold
CLICKHOUSE_READONLY=true
```

---

## 7. Contrato de API con el frontend

Estos cuatro endpoints son el contrato completo entre backend y frontend. El equipo de Flutter puede construir su capa de datos (modelos, cliente HTTP) directamente contra estas respuestas sin esperar a que el backend esté 100% desplegado — basta con fijar el contrato temprano y, si hace falta, levantar un servidor de datos de prueba con estas mismas formas de respuesta.

---

## 8. Definition of Done (backend)

- Endpoints documentados automáticamente en Swagger (`/docs`).
- Ninguna query del backend toca `tangara_bronce` o `tangara_plata` directamente — solo `tangara_gold`.
- Todo endpoint responde en menos de 1s con caché tibia.
- `sectores.geojson` versionado en el repo; cualquier cambio a los polígonos pasa por PR.
- `requirements.txt` contiene únicamente las dependencias necesarias para el alcance actual del servicio.
- CORS configurado explícitamente para el dominio donde se despliega el frontend Flutter Web.
