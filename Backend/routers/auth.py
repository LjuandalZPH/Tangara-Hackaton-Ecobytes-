"""
Router: Autenticación
Registro y login con JWT.
Implementación completa en Sprint 3 (HU-06).
"""

from fastapi import APIRouter

router = APIRouter()


@router.get("/status")
async def auth_status():
    """Stub — implementación completa en Sprint 3."""
    return {"module": "auth", "status": "pendiente Sprint 3"}
