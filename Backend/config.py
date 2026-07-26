"""
Configuración central del backend.

Carga las variables de entorno (.env) con pydantic-settings y expone
las constantes fijas usadas por los routers (umbrales OMS, TTLs de caché).
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    clickhouse_host: str = "localhost"
    clickhouse_port: int = 443
    clickhouse_user: str = "default"
    clickhouse_password: str = ""
    clickhouse_database: str = "tangara_plata"
    clickhouse_secure: bool = True

    # Vacío por defecto (fail-closed): el Definition of Done de
    # 03-Arquitectura-Backend.md §8 exige CORS configurado explícitamente
    # para el dominio del frontend. Un default de "*" combinado con
    # allow_credentials=True hace que Starlette refleje cualquier Origin,
    # es decir, acceso con credenciales desde cualquier sitio.
    cors_origins: str = ""

    environment: str = "development"

    # ── Chatbot (OpenAI) ──
    # Sin openai_api_key el endpoint POST /chatbot responde 503 (ver
    # routers/chatbot.py); el resto de la API sigue funcionando igual,
    # así que esta ausencia no debe tumbar el arranque de la app.
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    openai_timeout_segundos: float = 30.0

    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()

# ─────────────────────────────────────────────────────────────
# Umbrales OMS para PM2.5 (µg/m3, promedio de 24h)
# Fuente: Guías mundiales de calidad del aire de la OMS (2021),
# https://www.who.int/publications/i/item/9789240034228
#   - "verde"   (bueno):   PM2.5 < 15
#   - "amarillo"(moderado):15 <= PM2.5 <= 35
#   - "rojo"    (dañino):  PM2.5 > 35
# ─────────────────────────────────────────────────────────────
PM25_UMBRAL_BUENO = 15.0
PM25_UMBRAL_MODERADO = 35.0

# Umbral usado para contar "días sobre el límite OMS" en /risk/{sector}
# (guía OMS de promedio diario para PM2.5: 15 µg/m3)
PM25_UMBRAL_DIARIO_OMS = 15.0

# Una lectura se considera "no reciente" si supera esta antigüedad
MAX_ANTIGUEDAD_LECTURA_SEGUNDOS = 3600  # 1 hora

# TTLs de caché en memoria (services/cache.py)
TTL_SECTORS_SEGUNDOS = 30
TTL_MAPEO_SENSOR_SECTOR_SEGUNDOS = 3600  # 1 hora, las posiciones no cambian

# Mínimo de meses de histórico para considerar el perfil de riesgo confiable
MIN_MESES_HISTORICO_SUFICIENTE = 3

# Ventana del historial horario ("Evolución de la calidad del aire") que
# devuelve GET /sectors/{id}
HORAS_HISTORIAL_SECTOR = 24

# ─────────────────────────────────────────────────────────────
# Chatbot (POST /chatbot)
# ─────────────────────────────────────────────────────────────
# TTL del snapshot de contexto (services/chatbot_context.py) que se le
# inyecta al modelo. Corto para que el chatbot no diga datos desfasados,
# pero suficiente para no reconstruirlo en cada mensaje del usuario.
TTL_CONTEXTO_CHATBOT_SEGUNDOS = 60

# Cuántos turnos de historial (usuario+asistente) se conservan como
# máximo; el resto se recorta en el servidor, nunca se rechaza la request.
MAX_TURNOS_HISTORIAL_CHATBOT = 10

# Longitud máxima del mensaje del usuario en POST /chatbot
MAX_LONGITUD_MENSAJE_CHATBOT = 1000

# Vueltas máximas del bucle de function calling (services/chatbot_tools.py).
# Cada vuelta es una llamada facturable a OpenAI: sin tope, un modelo que se
# atasque pidiendo herramientas encadenaría llamadas indefinidamente. 4 da
# margen para consultar dos comunas distintas y aún así responder.
MAX_ITERACIONES_TOOLS_CHATBOT = 4

# Techo de tiempo para responder un mensaje, contando TODAS las vueltas del
# bucle de tools. Sin esto, 4 llamadas secuenciales de 30s con 2 reintentos
# cada una pueden sumar varios minutos: el navegador se rinde mucho antes
# (45s en ApiClient) y el usuario ve un error de red mientras el servidor
# sigue facturando llamadas que ya nadie va a leer. Debe quedar por debajo
# del timeout del cliente.
PRESUPUESTO_TOTAL_CHATBOT_SEGUNDOS = 40.0

# Lista cerrada de botones/acciones que el modelo puede sugerir a la UI.
# El frontend (chatbot_page.dart) ya sabe pintar botones con estos textos
# exactos; cualquier otra acción que devuelva el modelo se filtra en el
# servidor antes de responder (services/llm_client.py).
ACCIONES_CHATBOT = [
    "Ver mapa de Cali",
    "Recomendación de hoy",
    "Comparar comunas",
    "Aprender sobre PM2.5",
]
