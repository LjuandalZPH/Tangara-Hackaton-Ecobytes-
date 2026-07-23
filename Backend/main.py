"""
EcoBytes — Backend Principal
FastAPI app con CORS habilitado y routers registrados.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import sensors
from services import clickhouse_client

# ─────────────────────────────────────────
# Instancia principal de la app
# ─────────────────────────────────────────
app = FastAPI(
    title="EcoBytes API",
    description="API de monitoreo de calidad del aire para Cali, Colombia. "
                "Desarrollado por Bit&Volt Labs para la Hackathon Tángara 2026.",
    version="0.1.0",
    docs_url="/docs",       # documentación interactiva: http://localhost:8000/docs
    redoc_url="/redoc",     # documentación alternativa:  http://localhost:8000/redoc
)

# ─────────────────────────────────────────
# CORS — permite que Flutter web se conecte
# ─────────────────────────────────────────
# En producción, reemplaza ["*"] por el dominio real de tu app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────
# Routers — cada módulo en su archivo
# ─────────────────────────────────────────
app.include_router(sensors.router,  prefix="/sensors",  tags=["Sensores"])


# ─────────────────────────────────────────
# Eventos del ciclo de vida
# ─────────────────────────────────────────
@app.on_event("startup")
async def on_startup():
    """Se ejecuta cuando arranca el servidor."""
    await clickhouse_client.connect()
    print("✅ Cliente de ClickHouse conectado.")


@app.on_event("shutdown")
async def on_shutdown():
    """Se ejecuta cuando el servidor se apaga."""
    await clickhouse_client.disconnect()


# ─────────────────────────────────────────
# Endpoint de salud — para verificar que la API funciona
# ─────────────────────────────────────────
@app.get("/health", tags=["Sistema"])
async def health_check():
    """
    Verifica que la API está corriendo.

    Úsalo para confirmar que Docker levantó todo correctamente:
        curl http://localhost:8000/health
    """
    return {
        "status": "ok",
        "service": "EcoBytes API",
        "version": "0.1.0",
    }
