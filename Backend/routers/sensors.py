"""
Router: Sensores
Endpoints para consultar datos de calidad del aire.

Los datos vienen de tangara_plata.plata_tangara_sensores (ClickHouse),
capa de solo lectura alimentada por el pipeline Tángara. El backend no
escribe ahí — no hay POST /sensors/data.
"""

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from clickhouse_connect.driver.asyncclient import AsyncClient
import pygeohash as pgh
import json

from services.clickhouse_client import get_client
from services.calibration import calibrate_pm25, get_alert_level

router = APIRouter()

TABLE = "tangara_plata.plata_tangara_sensores"


def _decode_geo(geo: str | None) -> tuple[float | None, float | None]:
    """
    Decodifica la columna `geo` (presumiblemente geohash) a lat/lon.
    No hay confirmación oficial del formato en el pipeline — si el valor
    no decodifica como geohash válido, se devuelven coordenadas nulas
    en vez de tumbar la request.
    """
    if not geo:
        return None, None
    try:
        lat, lon = pgh.decode(geo)
        return lat, lon
    except Exception:
        return None, None


# ─────────────────────────────────────────
# GET /sensors/latest
# Devuelve la lectura más reciente de cada sensor
# ─────────────────────────────────────────
@router.get("/latest")
async def get_latest_readings(client: AsyncClient = Depends(get_client)):
    """
    Devuelve la última lectura disponible de cada sensor.
    Flutter lo usa para pintar el estado inicial del mapa.
    """
    query = f"""
        SELECT
            name,
            argMax(geo, time) AS geo,
            argMax(tmp, time) AS tmp,
            argMax(hum, time) AS hum,
            argMax(pm25, time) AS pm25,
            argMax(co2, time) AS co2,
            max(time) AS timestamp
        FROM {TABLE}
        GROUP BY name
    """
    result = await client.query(query)

    readings = []
    for row in result.named_results():
        pm25_calibrated = calibrate_pm25(row["pm25"], row["hum"])
        latitude, longitude = _decode_geo(row["geo"])
        readings.append({
            "sensor_id": row["name"],
            "timestamp": row["timestamp"],
            "pm25_calibrated": pm25_calibrated,
            "co2": row["co2"],
            "humidity": row["hum"],
            "temperature": row["tmp"],
            "latitude": latitude,
            "longitude": longitude,
            "alert_level": get_alert_level(pm25_calibrated) if pm25_calibrated else None,
        })

    return readings


# ─────────────────────────────────────────
# GET /sensors/{sensor_id}/history
# Historial de un sensor específico
# ─────────────────────────────────────────
@router.get("/{sensor_id}/history")
async def get_sensor_history(
    sensor_id: str,
    hours: int = 24,          # por defecto: últimas 24 horas
    client: AsyncClient = Depends(get_client),
):
    """
    Devuelve el historial de lecturas de un sensor.
    Flutter lo usa cuando el usuario toca un sensor en el mapa.

    Parámetros:
        sensor_id: ID del sensor (ej. "TAN-042")
        hours:     Cuántas horas hacia atrás traer (default: 24)
    """
    query = f"""
        SELECT time, pm25, hum, co2, tmp
        FROM {TABLE}
        WHERE name = {{sensor_id:String}}
          AND time >= now() - INTERVAL {{hours:UInt32}} HOUR
        ORDER BY time DESC
        LIMIT 500
    """
    result = await client.query(query, parameters={"sensor_id": sensor_id, "hours": hours})
    rows = list(result.named_results())

    if not rows:
        raise HTTPException(
            status_code=404,
            detail=f"No se encontraron lecturas para el sensor '{sensor_id}' en las últimas {hours} horas.",
        )

    readings = []
    for row in rows:
        pm25_calibrated = calibrate_pm25(row["pm25"], row["hum"])
        readings.append({
            "timestamp": row["time"],
            "pm25_raw": row["pm25"],
            "pm25_calibrated": pm25_calibrated,
            "co2": row["co2"],
            "humidity": row["hum"],
            "temperature": row["tmp"],
            "alert_level": get_alert_level(pm25_calibrated) if pm25_calibrated else None,
        })

    return {
        "sensor_id": sensor_id,
        "hours_requested": hours,
        "count": len(readings),
        "readings": readings,
    }


# ─────────────────────────────────────────
# WebSocket /sensors/ws/live
# Emite lecturas en tiempo real a Flutter
# ─────────────────────────────────────────
class ConnectionManager:
    """Maneja múltiples conexiones WebSocket activas."""

    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, data: dict):
        """Envía datos a todos los clientes conectados."""
        message = json.dumps(data, default=str)
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception:
                pass  # cliente desconectado — se limpiará en el próximo disconnect


manager = ConnectionManager()


@router.websocket("/ws/live")
async def websocket_live(websocket: WebSocket):
    """
    Conexión WebSocket para datos en tiempo real.
    Flutter se conecta aquí y recibe actualizaciones cuando hay datos nuevos.

    URL de conexión desde Flutter:
        ws://localhost:8000/sensors/ws/live
    """
    await manager.connect(websocket)
    try:
        while True:
            # Esperar mensaje del cliente (heartbeat para mantener la conexión viva)
            data = await websocket.receive_text()

            if data == "ping":
                await websocket.send_text("pong")

    except WebSocketDisconnect:
        manager.disconnect(websocket)
