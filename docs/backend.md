# Backend

Servicio FastAPI que expone el contrato de datos de EcoBytes. No tiene base de datos propia: lee en modo exclusivamente lectura de ClickHouse (capa Plata del pipeline Tángara) y sirve un archivo GeoJSON estático para la resolución geográfica de comunas.

## Stack

| Pieza | Tecnología | Uso |
| --- | --- | --- |
| Framework HTTP | FastAPI + Uvicorn | Enrutamiento, validación de payloads, documentación OpenAPI automática |
| Cliente de datos | `clickhouse-connect` (async) | Consulta a ClickHouse, capa Plata |
| Geometría | `shapely` | Point-in-polygon para resolver a qué comuna pertenece un sensor |
| LLM | `openai` (cliente async oficial) | Redacción de respuestas del chatbot ambiental |
| Caché | `cachetools.TTLCache` | Caché en memoria de respuestas agregadas |
| Configuración | `pydantic-settings` | Carga de variables de entorno y validación de tipos |

Runtime: Python 3.12 (`python:3.12-slim` en la imagen Docker).

## Estructura de capas

```
Backend/
├── main.py                    # instancia FastAPI, CORS, registro de routers, ciclo de vida
├── config.py                  # Settings (.env) + constantes de dominio (umbrales OMS, TTLs)
├── routers/                   # capa HTTP: valida entrada, delega a services, da forma a la salida
│   ├── sectors.py
│   ├── risk.py
│   ├── education.py
│   └── chatbot.py
├── services/                  # lógica de negocio y acceso a datos, sin conocer FastAPI
│   ├── clickhouse_client.py   # única puerta de entrada a ClickHouse; aplica calibración
│   ├── calibration.py         # corrección de PM2.5 por humedad (lógica de dominio pura)
│   ├── geo.py                 # SectorIndex: GeoJSON + shapely, mapeo sensor → comuna
│   ├── sectores.py            # construcción del snapshot de las 22 comunas
│   ├── cache.py                # TTLCache compartidas
│   ├── chatbot_context.py     # snapshot de datos que se inyecta al LLM
│   ├── chatbot_tools.py       # function calling: histórico, evolución 24h, sensores, detalle
│   └── llm_client.py          # único punto que habla con OpenAI
└── data/
    ├── sectores.geojson       # 22 comunas de Cali (IDESC), versionado en el repo
    └── educacion.json         # contenido educativo estático, fuente única de /education y del chatbot
```

Los routers no acceden a ClickHouse ni al GeoJSON directamente: siempre pasan por `services/`. `services/sectores.py` existe separado de `routers/sectors.py` porque dos clientes distintos lo consumen — el endpoint del mapa y el chatbot — y no depende de un `Request` de FastAPI para poder invocarse desde fuera de un router.

## Modelo de datos

EcoBytes no define un esquema propio de base de datos: consulta la tabla `tangara_plata.plata_tangara_sensores`, cuyas columnas relevantes son:

| Columna | Tipo | Contenido |
| --- | --- | --- |
| `name` | `String` | Identificador del sensor |
| `time` | `DateTime64` | Marca de tiempo de la lectura |
| `geo` | `String` | Geohash de la posición del sensor |
| `pm25` | `Nullable(Float32)` | Material particulado fino, crudo (sin calibrar) |
| `co2` | `Nullable(Float32)` | Dióxido de carbono, ppm |
| `hum` | `Nullable(Float32)` | Humedad relativa, % |
| `tmp` | `Nullable(Float32)` | Temperatura |

Sobre esos datos crudos, el backend construye dos entidades propias en memoria:

**Comuna (sector).** Una de las 22 comunas oficiales de Cali (`data/sectores.geojson`, fuente IDESC), identificada como `comuna-N` y con nombre `Comuna N`. No tiene identidad en ClickHouse: se resuelve dinámicamente agrupando los sensores cuyo geohash cae dentro del polígono de esa comuna.

**Mapeo sensor → comuna.** Resultado de decodificar el geohash de cada sensor (`geohashDecode()` en la propia query SQL) y resolver el punto contra el GeoJSON con `shapely`. Se cachea en memoria durante una hora porque la posición física de un sensor no cambia con frecuencia.

## Endpoints

Base URL: la raíz del servicio (sin prefijo de versión). Todas las respuestas son JSON.

### `GET /sectors`

Estado actual de las 22 comunas, para colorear el mapa. Cacheado 30 segundos.

```json
{
  "sectores": [
    {
      "id": "comuna-17",
      "nombre": "Comuna 17",
      "geometry": { "type": "MultiPolygon", "coordinates": [ ] },
      "pm25_promedio": 8.4,
      "estado": "verde",
      "ultima_lectura": "2026-07-25T14:00:00+00:00",
      "sin_datos_recientes": false
    }
  ]
}
```

`estado` es uno de `verde` (&lt;15 µg/m³), `amarillo` (15–35), `rojo` (&gt;35) o `gris` (sin lectura confiable en la última hora). `sin_datos_recientes: true` no implica `pm25_promedio` nulo: una comuna con sensores pero lectura antigua conserva el último valor conocido, marcado como no confiable.

### `GET /sectors/{id}`

Detalle de una comuna puntual, con historial horario de las últimas 24 horas.

```json
{
  "id": "comuna-17",
  "nombre": "Comuna 17",
  "pm25_promedio": 8.4,
  "co2_promedio": 421.0,
  "hum_promedio": 68.2,
  "ultima_lectura": "2026-07-25T14:00:00+00:00",
  "sin_datos_recientes": false,
  "estado": "verde",
  "historial_24h": [
    { "hora": "2026-07-25T00:00:00+00:00", "pm25_promedio": 7.1 }
  ]
}
```

`404` si el `id` no corresponde a ninguna de las 22 comunas.

### `GET /sectors/{id}/sensores`

Sensores individuales dentro de una comuna, sin agregar — nombre, ubicación (si tuvo lectura en la última hora) y su última medición.

```json
{
  "sensores": [
    {
      "nombre": "tangara-045",
      "lat": 3.3721,
      "lon": -76.5378,
      "pm25_promedio": 9.1,
      "co2_promedio": 410.0,
      "hum_promedio": 70.5,
      "ultima_lectura": "2026-07-25T14:00:00+00:00",
      "estado": "verde",
      "sin_datos_recientes": false
    }
  ]
}
```

`404` si el `id` no corresponde a ninguna comuna. Un sensor conocido (aparece en el mapeo sensor→comuna) pero sin lectura en la última hora se devuelve con `estado: "gris"` y coordenadas nulas.

### `GET /risk/{sector}`

Perfil histórico de riesgo del último año: promedio anual, peor mes, mejor mes y días sobre el límite diario de la OMS (15 µg/m³).

```json
{
  "sector": "comuna-17",
  "promedio_anual": 7.98,
  "peor_mes": { "mes": "2026-06", "promedio": 13.25 },
  "mejor_mes": { "mes": "2025-07", "promedio": 3.24 },
  "dias_sobre_limite_oms_ultimo_anio": 16,
  "historico_suficiente": true
}
```

`historico_suficiente` es `false` cuando la comuna tiene menos de tres meses de datos — el perfil se devuelve igual, pero la interfaz debe advertirlo. Si no hay ningún mes con datos, todos los campos numéricos llegan en `null`.

### `GET /education`

Contenido educativo estático (`data/educacion.json`): qué es cada contaminante medido (PM2.5, CO2, humedad), sus efectos en salud, los umbrales de referencia y recomendaciones. Sin lógica de negocio: se sirve el archivo tal cual. Es la misma fuente que consume el chatbot, para que ambos canales enseñen exactamente la misma escala.

### `POST /chatbot`

Asistente ambiental conversacional. El servidor no guarda estado de conversación: el cliente reenvía el historial completo en cada mensaje.

Payload:

```json
{
  "mensaje": "¿Cómo está el aire en la comuna 17?",
  "historial": [
    { "rol": "usuario", "texto": "hola" },
    { "rol": "asistente", "texto": "¡Hola! ¿En qué te ayudo?" }
  ]
}
```

Respuesta:

```json
{
  "respuesta": "La comuna 17 tiene un PM2.5 de 8.4 µg/m³, en estado verde (bueno).",
  "acciones": ["Ver mapa de Cali", "Comparar comunas"],
  "contexto_actualizado": "2026-07-25T14:00:00+00:00"
}
```

`acciones` es siempre un subconjunto de una lista cerrada de cuatro botones (`Ver mapa de Cali`, `Recomendación de hoy`, `Comparar comunas`, `Aprender sobre PM2.5`), validada también en el servidor. `503` si el servidor no tiene `OPENAI_API_KEY` configurada; `502` si el proveedor del modelo falla o se agota el presupuesto de tiempo de la respuesta (40 segundos, contando reintentos internos de function calling).

### `GET /health`

Verificación simple de que el servicio está arriba: `{"status": "ok", "service": "EcoBytes API", "version": "0.2.0"}`.

## Lógica de negocio relevante

**Calibración de PM2.5 por humedad.** Los sensores ópticos de bajo costo (PMS5003/PMS7003) sobrestiman PM2.5 en ambientes húmedos, porque confunden gotas de agua con partículas. `services/calibration.py` aplica la corrección de Dillo et al.:

```
PM2.5_calibrado = PM2.5_crudo / (1 + k × (HR / 100))
```

con `k = 0.24` (factor empírico, sujeto a validación contra un equipo de referencia por el equipo de electrónica). Se aplica una única vez, dentro de `clickhouse_client.py`; ningún router ve jamás el valor crudo. El conteo de "días sobre el límite OMS" no puede resolverse con `HAVING` en SQL porque la corrección no es lineal: se traen los promedios diarios (~365 filas como máximo) y se filtra en Python.

**Clasificación por estado.** `verde` si PM2.5 &lt; 15 µg/m³, `amarillo` si está entre 15 y 35, `rojo` si supera 35 (umbrales de las Guías mundiales de calidad del aire de la OMS, 2021, promedio de 24h). `gris` cuando no hay lectura calibrable en la última hora — se trata siempre como "dato no confiable", nunca como "aire limpio".

**Resolución de comuna.** `geohashDecode()` corre dentro de la propia consulta SQL (ClickHouse resuelve el geohash de cada sensor a latitud/longitud); el backend recibe coordenadas ya decodificadas y las resuelve contra el GeoJSON con `shapely.geometry.Point(...).contains(...)`.

**Chatbot con function calling acotado.** El modelo recibe en el prompt un snapshot con el estado actual de las 22 comunas (construido con la misma función que alimenta `/sectors`) y puede invocar hasta cuatro herramientas para detalles que no caben en ese snapshot: histórico anual, evolución de 24 horas, sensores individuales, o CO2/humedad de una comuna puntual. Cada herramienta reutiliza los mismos `services/` que los routers HTTP, así que nunca hay dos fuentes de verdad para el mismo dato. El bucle de herramientas está acotado a 4 vueltas y a un presupuesto total de 40 segundos; la respuesta final está forzada a un JSON Schema estricto (`respuesta` + `acciones`) para que el cliente no dependa de parsear texto libre.

## Manejo de errores

| Código | Cuándo | Ejemplo |
| --- | --- | --- |
| `404` | El `id`/`sector` no corresponde a ninguna de las 22 comunas | `GET /sectors/comuna-99` |
| `422` | Payload de `POST /chatbot` inválido (mensaje vacío, historial mal formado) | Validación automática de FastAPI/Pydantic |
| `503` | `POST /chatbot` sin `OPENAI_API_KEY` configurada en el servidor | El resto de la API sigue funcionando con normalidad |
| `502` | El proveedor del modelo falla, o el bucle de herramientas se agota sin responder | El detalle técnico del fallo queda en el log del servidor, nunca viaja al cliente |

Un fallo de ClickHouse al construir el contexto del chatbot no rompe el endpoint: el snapshot se marca con `datos_sensores_disponibles: false` y el modelo lo reporta explícitamente en vez de inventar cifras.

## Configuración

Variables de entorno (`Backend/.env`, a partir de `Backend/.env.example`):

| Variable | Propósito | Obligatoria |
| --- | --- | --- |
| `CLICKHOUSE_HOST` | Host del servidor ClickHouse | Sí |
| `CLICKHOUSE_PORT` | Puerto (443 por defecto, HTTPS) | Sí |
| `CLICKHOUSE_USER` | Usuario de solo lectura contra `tangara_plata` | Sí |
| `CLICKHOUSE_PASSWORD` | Contraseña de ese usuario | Sí |
| `CLICKHOUSE_DATABASE` | Base de datos a consultar (`tangara_plata`) | Sí |
| `CLICKHOUSE_SECURE` | Si la conexión usa TLS (`True`/`False`) | Sí |
| `CORS_ORIGINS` | Orígenes permitidos para el frontend web, separados por comas | Sí — vacío por defecto (fail-closed); sin esto el navegador bloquea todas las llamadas |
| `OPENAI_API_KEY` | Credencial del chatbot | No — sin ella, `POST /chatbot` responde `503` y el resto de la API funciona igual |
| `OPENAI_MODEL` | Modelo a usar (por defecto `gpt-4o-mini`) | No |
| `OPENAI_TIMEOUT_SEGUNDOS` | Timeout de la llamada al modelo | No |
| `ENVIRONMENT` | `development` o `production` | No |

Ningún valor real de estas variables debe copiarse fuera de `Backend/.env` (ya está en `.gitignore`); usa siempre `Backend/.env.example` como plantilla.

### Local, sin Docker

```bash
cd Backend
pip install -r requirements.txt
cp .env.example .env   # completar las credenciales
uvicorn main:app --reload
```

### Con Docker Compose

El repositorio define tres archivos `docker-compose`, todos en la raíz:

| Archivo | Qué levanta | Cuándo usarlo |
| --- | --- | --- |
| `docker-compose.yml` | `api` (backend) + `web` (frontend) | Levantar la aplicación completa en una sola máquina, ej. para pruebas locales de integración |
| `docker-compose.backend.yml` | Solo `api` | Desarrollar o desplegar el backend de forma independiente — es el compose relevante para el servidor autoalojado, que no necesita construir el frontend |
| `docker-compose.frontend.yml` | Solo `web` | Levantar únicamente el frontend contra un backend ya corriendo en otro lado (local, remoto, o vía Funnel) |

El servicio `api` (definido igual en `docker-compose.yml` y en `docker-compose.backend.yml`) usa `env_file: ./Backend/.env` — Docker Compose lo detecta automáticamente porque el archivo está declarado explícitamente, sin necesidad de pasar `--env-file`. Publica el puerto `8000:8000` y monta el código como volumen con `--reload`, así que los cambios se reflejan sin reconstruir la imagen.

```bash
# Aplicación completa (api + web)
docker compose --env-file Frontend/ecobytes/.env up

# Solo backend
docker compose -f docker-compose.backend.yml up

# Verificar
curl http://localhost:8000/health
```

La documentación interactiva queda disponible en `http://localhost:8000/docs` (Swagger) y `http://localhost:8000/redoc`.

## Exposición en producción: Tailscale Funnel

El backend autoalojado corre con `docker compose -f docker-compose.backend.yml up` en un servidor que forma parte de una tailnet de Tailscale, escuchando en el puerto 8000. Ese puerto se publica a internet como una URL HTTPS pública mediante Tailscale Funnel — sin abrir puertos en el router ni gestionar certificados manualmente.

Para replicar el acceso desde ese servidor:

1. Confirmar que Tailscale está activo: `tailscale status`.
2. Si es la primera vez que se usa Funnel en la tailnet, habilitar HTTPS para el tailnet completo desde el panel de administración de Tailscale (una sola vez, no por dispositivo).
3. Si la cuenta lo requiere, habilitar Funnel para el nodo específico desde el panel de administración.
4. Levantar Funnel apuntando al puerto del backend, en segundo plano:
   ```bash
   sudo tailscale funnel --bg 8000
   ```
5. Confirmar la URL pública asignada: `tailscale funnel status`.
6. Probar desde fuera de la tailnet: `curl https://<host-asignado>/health` debe responder `200`.

Esa URL pública es la que consumen tanto el frontend desplegado en Vercel (variable `API_BASE_URL`, ver `frontend.md`) como el firmware del kiosko ESP32 (`kBackendBaseUrl`, ver `firmware-esp32-kiosko.md`). `CORS_ORIGINS` en `Backend/.env` debe incluir exactamente el dominio donde se sirve el frontend (protocolo + host, sin puerto si es HTTPS estándar) para que el navegador no bloquee las peticiones.
