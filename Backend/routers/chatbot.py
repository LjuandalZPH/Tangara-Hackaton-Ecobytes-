"""
Router: Chatbot
POST /chatbot — asistente ambiental conversacional.

El modelo (OpenAI, ver services/llm_client.py) solo puede hablar de lo que
haya en el snapshot de datos reales que construye services/chatbot_context.py:
las 22 comunas con su PM2.5 y estado actual, más el contenido educativo del
propio producto. No hay memoria en el servidor — el historial de la
conversación lo manda el cliente en cada request.
"""

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from config import MAX_LONGITUD_MENSAJE_CHATBOT, MAX_TURNOS_HISTORIAL_CHATBOT
from services import chatbot_context, llm_client
from services.llm_client import ChatbotNoConfigurado

router = APIRouter()


class TurnoConversacion(BaseModel):
    rol: str = Field(..., pattern="^(usuario|asistente)$")
    texto: str = Field(..., min_length=1, max_length=MAX_LONGITUD_MENSAJE_CHATBOT)


class MensajeChatbot(BaseModel):
    mensaje: str = Field(..., min_length=1, max_length=MAX_LONGITUD_MENSAJE_CHATBOT)
    historial: list[TurnoConversacion] = Field(default_factory=list)


@router.post("")
async def post_chatbot(payload: MensajeChatbot, request: Request):
    """Responde una pregunta del usuario sobre la calidad del aire en Cali."""
    if not llm_client.esta_configurado():
        raise HTTPException(
            status_code=503,
            detail="El chatbot no está configurado en este servidor "
                   "(falta OPENAI_API_KEY). El resto de la API funciona con normalidad.",
        )

    contexto = await chatbot_context.construir_contexto(request.app.state.sector_index)

    # Se recorta en el servidor en vez de rechazar la request: una conversación
    # larga es un caso normal, no un error del cliente. Se conservan los turnos
    # más recientes, que son los que dan continuidad.
    historial = [t.model_dump() for t in payload.historial][-MAX_TURNOS_HISTORIAL_CHATBOT:]

    try:
        resultado = await llm_client.responder(
            mensaje=payload.mensaje,
            historial=historial,
            contexto=chatbot_context.serializar(contexto),
        )
    except ChatbotNoConfigurado:
        raise HTTPException(status_code=503, detail="El chatbot no está configurado en este servidor.")
    except Exception as exc:  # noqa: BLE001 — se traduce cualquier fallo del proveedor
        # El error real (que puede incluir detalles del proveedor o de la
        # cuenta) se queda en el log del servidor, no viaja al navegador.
        print(f"[chatbot] Fallo al consultar el modelo: {exc!r}")
        raise HTTPException(
            status_code=502,
            detail="El asistente no está disponible en este momento. Intenta de nuevo en unos segundos.",
        )

    return {
        "respuesta": resultado["respuesta"],
        "acciones": resultado["acciones"],
        "contexto_actualizado": contexto["generado_en"],
    }
