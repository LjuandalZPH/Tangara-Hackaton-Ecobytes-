"""
Router: Juego
Persistencia de puntajes del módulo de gamificación.
Implementación completa en Sprint 4 (HU-07).
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/status")
async def game_status():
    """Stub — implementación completa en Sprint 4."""
    return {"module": "game", "status": "pendiente Sprint 4"}
