"""
Modelo: SensorReading
Representa una lectura individual de un sensor de Tángara.
"""

import uuid
from datetime import datetime
from sqlalchemy import String, Float, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from db.database import Base


class SensorReading(Base):
    """
    Tabla: sensor_readings
    Guarda cada lectura de cada sensor con su valor crudo y calibrado.
    """
    __tablename__ = "sensor_readings"

    # Clave primaria — UUID generado automáticamente
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # ID del sensor (ej. "TAN-042") — vendrá del CSV de Tángara
    sensor_id: Mapped[str] = mapped_column(String(50), nullable=False, index=True)

    # Fecha y hora de la lectura (con zona horaria)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    # PM2.5 — partículas finas (la métrica principal de Tángara)
    pm25_raw: Mapped[float] = mapped_column(Float, nullable=True)         # valor directo del sensor
    pm25_calibrated: Mapped[float] = mapped_column(Float, nullable=True)  # corregido por humedad

    # CO2 en partes por millón (ppm)
    co2: Mapped[float] = mapped_column(Float, nullable=True)

    # Humedad relativa en porcentaje (se usa para la calibración)
    humidity: Mapped[float] = mapped_column(Float, nullable=True)

    # Temperatura en grados Celsius
    temperature: Mapped[float] = mapped_column(Float, nullable=True)

    # Coordenadas geográficas del sensor
    # Nota: en Sprint 1 se migrarán a tipo GEOGRAPHY de PostGIS
    # Por ahora floats simples para no bloquear el arranque
    latitude: Mapped[float] = mapped_column(Float, nullable=True)
    longitude: Mapped[float] = mapped_column(Float, nullable=True)

    # Cuándo se insertó este registro en nuestra BD
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
    )

    def __repr__(self) -> str:
        return f"<SensorReading sensor={self.sensor_id} ts={self.timestamp} pm25={self.pm25_calibrated}>"
