"""
Router: Educación
GET /education — devuelve el contenido estático de data/educacion.json.
Deliberadamente el endpoint más simple del sistema: sin lógica.
"""

import json
from pathlib import Path

from fastapi import APIRouter

router = APIRouter()

_EDUCACION_PATH = Path(__file__).resolve().parent.parent / "data" / "educacion.json"


@router.get("")
async def get_education():
    """Devuelve el contenido educativo estático (PM2.5, CO2, salud, límites OMS)."""
    with open(_EDUCACION_PATH, encoding="utf-8") as f:
        return json.load(f)
