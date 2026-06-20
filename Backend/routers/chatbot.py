"""
Router: Chatbot
Preguntas en lenguaje natural sobre los datos de Tángara.
Implementación completa en Sprint 3 (HU-05).
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/chatbot/status")
async def chatbot_status():
    """Stub — implementación completa en Sprint 3."""
    return {"module": "chatbot", "status": "pendiente Sprint 3"}
