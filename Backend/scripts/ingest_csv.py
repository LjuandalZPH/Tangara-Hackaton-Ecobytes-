"""
Script: Ingesta de datos históricos de Tángara
Carga los archivos CSV descargados de tangara.sebaxtian.dev a PostgreSQL.

Uso:
    # Primero descarga un CSV desde https://tangara.sebaxtian.dev/
    # Luego corre (con el backend levantado en Docker):
    python scripts/ingest_csv.py --file datos_tangara_2026_05.csv

    # Para cargar varios meses:
    python scripts/ingest_csv.py --file datos_2024_*.csv

IMPORTANTE:
    Corre este script desde la carpeta backend/, no desde la raíz del proyecto.
    Asegúrate de tener las variables de entorno en .env antes de correr.
"""

import asyncio
import argparse
import gzip
import pandas as pd
from pathlib import Path
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from pydantic_settings import BaseSettings

# Importar el servicio de calibración
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))
from services.calibration import calibrate_pm25
from models.sensor import SensorReading


class Settings(BaseSettings):
    DATABASE_URL: str

    class Config:
        env_file = ".env"


settings = Settings()


async def ingest_file(filepath: str, session: AsyncSession):
    """
    Carga un archivo CSV (o CSV comprimido .csv.gz) a la base de datos.

    Columnas esperadas del CSV de Tángara:
        Ajusta COLUMN_MAP según las columnas reales del CSV que te entreguen.
        Una vez que tengas el archivo, actualiza este mapeo.
    """
    path = Path(filepath)

    print(f"📂 Leyendo {path.name}...")

    # Soporta .csv y .csv.gz
    if path.suffix == ".gz":
        with gzip.open(path, "rt", encoding="utf-8") as f:
            df = pd.read_csv(f)
    else:
        df = pd.read_csv(path)

    print(f"   {len(df)} filas encontradas.")
    print(f"   Columnas: {list(df.columns)}")

    # ─────────────────────────────────────────────────────────
    # AJUSTA ESTE MAPEO según las columnas reales del CSV
    # Ejemplo (hipotético — actualizar cuando llegue el CSV real):
    # ─────────────────────────────────────────────────────────
    COLUMN_MAP = {
        "sensor_id":   "sensor_id",    # o el nombre real de la columna
        "timestamp":   "timestamp",
        "pm25":        "pm25_raw",
        "humidity":    "humidity",
        "co2":         "co2",
        "temperature": "temperature",
        "latitude":    "latitude",
        "longitude":   "longitude",
    }

    # Renombrar columnas al esquema interno
    df = df.rename(columns={v: k for k, v in COLUMN_MAP.items() if v in df.columns})

    # Parsear timestamps
    if "timestamp" in df.columns:
        df["timestamp"] = pd.to_datetime(df["timestamp"], utc=True, errors="coerce")

    # Aplicar calibración
    if "pm25_raw" in df.columns and "humidity" in df.columns:
        df["pm25_calibrated"] = df.apply(
            lambda row: calibrate_pm25(row.get("pm25_raw"), row.get("humidity")),
            axis=1,
        )
    else:
        df["pm25_calibrated"] = None
        print("   ⚠️  No se encontraron columnas pm25/humidity — calibración omitida.")

    # Insertar en lotes de 500 para no sobrecargar la BD
    batch_size = 500
    inserted = 0

    for i in range(0, len(df), batch_size):
        batch = df.iloc[i : i + batch_size]
        readings = []

        for _, row in batch.iterrows():
            reading = SensorReading(
                sensor_id=str(row.get("sensor_id", "UNKNOWN")),
                timestamp=row.get("timestamp"),
                pm25_raw=row.get("pm25_raw"),
                pm25_calibrated=row.get("pm25_calibrated"),
                co2=row.get("co2"),
                humidity=row.get("humidity"),
                temperature=row.get("temperature"),
                latitude=row.get("latitude"),
                longitude=row.get("longitude"),
            )
            readings.append(reading)

        session.add_all(readings)
        await session.commit()
        inserted += len(readings)
        print(f"   ✅ {inserted}/{len(df)} filas insertadas...")

    print(f"🎉 Ingesta completa: {inserted} lecturas cargadas desde {path.name}")


async def main(files: list[str]):
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with SessionLocal() as session:
        for filepath in files:
            await ingest_file(filepath, session)

    await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingesta de CSV histórico de Tángara")
    parser.add_argument("--file", nargs="+", required=True, help="Ruta(s) al archivo CSV")
    args = parser.parse_args()

    asyncio.run(main(args.file))
