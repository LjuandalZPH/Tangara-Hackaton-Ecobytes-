"""
Router: Riesgo
GET /risk/{sector} — perfil histórico: peor mes, mejor mes, promedio
anual y días sobre el límite OMS del último año.
"""

from fastapi import APIRouter, HTTPException, Request

from config import MIN_MESES_HISTORICO_SUFICIENTE, PM25_UMBRAL_DIARIO_OMS
from services import clickhouse_client
from services.geo import obtener_mapeo_sensor_sector

router = APIRouter()


@router.get("/{sector_id}")
async def get_risk(sector_id: str, request: Request):
    """Perfil histórico de riesgo (PM2.5) de un sector."""
    sector_index = request.app.state.sector_index
    sector = sector_index.sector_por_id(sector_id)
    if sector is None:
        raise HTTPException(status_code=404, detail=f"Sector '{sector_id}' no encontrado.")

    mapeo_sensor_sector = await obtener_mapeo_sensor_sector(sector_index)
    sensores_del_sector = [
        name for name, sid in mapeo_sensor_sector.items() if sid == sector_id
    ]

    meses = await clickhouse_client.promedio_mensual(sensores_del_sector)
    dias_sobre_limite = await clickhouse_client.dias_sobre_limite(
        sensores_del_sector, PM25_UMBRAL_DIARIO_OMS
    )

    historico_suficiente = len(meses) >= MIN_MESES_HISTORICO_SUFICIENTE

    if not meses:
        return {
            "sector": sector_id,
            "promedio_anual": None,
            "peor_mes": None,
            "mejor_mes": None,
            "dias_sobre_limite_oms_ultimo_anio": dias_sobre_limite,
            "historico_suficiente": False,
        }

    promedios = [m["pm25_promedio"] for m in meses if m["pm25_promedio"] is not None]
    promedio_anual = sum(promedios) / len(promedios) if promedios else None

    peor = max(meses, key=lambda m: m["pm25_promedio"] if m["pm25_promedio"] is not None else float("-inf"))
    mejor = min(meses, key=lambda m: m["pm25_promedio"] if m["pm25_promedio"] is not None else float("inf"))

    return {
        "sector": sector_id,
        "promedio_anual": promedio_anual,
        "peor_mes": {
            "mes": peor["mes"].strftime("%Y-%m"),
            "promedio": peor["pm25_promedio"],
        },
        "mejor_mes": {
            "mes": mejor["mes"].strftime("%Y-%m"),
            "promedio": mejor["pm25_promedio"],
        },
        "dias_sobre_limite_oms_ultimo_anio": dias_sobre_limite,
        "historico_suficiente": historico_suficiente,
    }
