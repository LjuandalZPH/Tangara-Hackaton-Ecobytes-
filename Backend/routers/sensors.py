"""
Router: Sensores
Endpoints para consultar datos de calidad del aire.

Por ahora NO hay POST /sensors/data porque los datos llegan
por CSV de Tángara (ver script de ingesta: scripts/ingest_csv.py).
Los endpoints aquí son todos de consulta (GET).
"""

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from datetime import datetime, timedelta
import json

from db.database import get_db
from models.sensor import SensorReading
from services.calibration import get_alert_level

router = APIRouter()


# ─────────────────────────────────────────
# GET /sensors/latest
# Devuelve la lectura más reciente de cada sensor
# ─────────────────────────────────────────
@router.get("/latest")
async def get_latest_readings(db: AsyncSession = Depends(get_db)):
    """
    Devuelve la última lectura disponible de cada sensor.
    Flutter lo usa para pintar el estado inicial del mapa.
    """
    # Subconsulta: para cada sensor_id, obtener el timestamp más reciente
    subquery = (
        select(SensorReading.sensor_id, func.max(SensorReading.timestamp).label("max_ts"))
        .group_by(SensorReading.sensor_id)
        .subquery()
    )

    result = await db.execute(
        select(SensorReading).join(
            subquery,
            (SensorReading.sensor_id == subquery.c.sensor_id) &
            (SensorReading.timestamp == subquery.c.max_ts),
        )
    )
    readings = result.scalars().all()

    return [
        {
            "sensor_id": r.sensor_id,
            "timestamp": r.timestamp,
            "pm25_calibrated": r.pm25_calibrated,
            "co2": r.co2,
            "humidity": r.humidity,
            "temperature": r.temperature,
            "latitude": r.latitude,
            "longitude": r.longitude,
            "alert_level": get_alert_level(r.pm25_calibrated) if r.pm25_calibrated else None,
        }
        for r in readings
    ]


# ─────────────────────────────────────────
# GET /sensors/{sensor_id}/history
# Historial de un sensor específico
# ─────────────────────────────────────────
@router.get("/{sensor_id}/history")
async def get_sensor_history(
    sensor_id: str,
    hours: int = 24,          # por defecto: últimas 24 horas
    db: AsyncSession = Depends(get_db),
):
    """
    Devuelve el historial de lecturas de un sensor.
    Flutter lo usa cuando el usuario toca un sensor en el mapa.

    Parámetros:
        sensor_id: ID del sensor (ej. "TAN-042")
        hours:     Cuántas horas hacia atrás traer (default: 24)
    """
    since = datetime.utcnow() - timedelta(hours=hours)

    result = await db.execute(
        select(SensorReading)
        .where(SensorReading.sensor_id == sensor_id)
        .where(SensorReading.timestamp >= since)
        .order_by(SensorReading.timestamp.desc())
        .limit(500)  # máximo 500 puntos para no sobrecargar Flutter
    )
    readings = result.scalars().all()

    if not readings:
        raise HTTPException(
            status_code=404,
            detail=f"No se encontraron lecturas para el sensor '{sensor_id}' en las últimas {hours} horas.",
        )

    return {
        "sensor_id": sensor_id,
        "hours_requested": hours,
        "count": len(readings),
        "readings": [
            {
                "timestamp": r.timestamp,
                "pm25_raw": r.pm25_raw,
                "pm25_calibrated": r.pm25_calibrated,
                "co2": r.co2,
                "humidity": r.humidity,
                "temperature": r.temperature,
                "alert_level": get_alert_level(r.pm25_calibrated) if r.pm25_calibrated else None,
            }
            for r in readings
        ],
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
async def websocket_live(websocket: WebSocket, db: AsyncSession = Depends(get_db)):
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
