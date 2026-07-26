"""
Contexto real que se le inyecta al LLM en POST /chatbot.

El chatbot no "sabe" nada por su cuenta: todo lo que puede afirmar sobre
el aire de Cali sale de este snapshot, construido con los mismos datos
que alimentan el mapa (`services/sectores.py` → ClickHouse capa Plata)
más el contenido educativo estático (`data/educacion.json`).

Dos decisiones importantes:

- **Se descarta `geometry`.** El GeoJSON de las 22 comunas pesa cientos
  de KB y al modelo no le sirve de nada; solo gastaría tokens.
- **Si ClickHouse falla, el snapshot no se rompe: se degrada.** El bloque
  de sectores se marca como no disponible y el modelo lo dice honestamente,
  en vez de que el endpoint entero devuelva un error.
"""

import json
from datetime import datetime, timezone
from pathlib import Path

from config import PM25_UMBRAL_BUENO, PM25_UMBRAL_MODERADO
from services.cache import chatbot_context_cache
from services.geo import SectorIndex
from services.sectores import construir_sectores

_EDUCACION_PATH = Path(__file__).resolve().parent.parent / "data" / "educacion.json"

_CLAVE_CACHE = "contexto"


# Claves de educacion.json que solo sirven para pintar /aprende y que no se le
# mandan al modelo. Mismo criterio con el que se descarta `geometry`: lo que no
# ayuda a responder, no se paga en tokens.
#   - `ui`: copys de sección ("APRENDE", "CUÍDATE", títulos), cero valor.
#   - `niveles_calidad`: redundante, el contexto ya construye
#     `umbrales_oms_pm25_ug_m3` desde config.py, incluida la advertencia sobre
#     gris. Duplicar la escala en prosa solo invita al modelo a citar la otra.
_CLAVES_EDUCACION_SOLO_UI = ("ui", "niveles_calidad", "umbrales_pm25_ug_m3", "version")


def _cargar_educacion() -> dict:
    with open(_EDUCACION_PATH, encoding="utf-8") as f:
        contenido = json.load(f)
    return {k: v for k, v in contenido.items() if k not in _CLAVES_EDUCACION_SOLO_UI}


def _resumir_sectores(sectores: list[dict]) -> dict:
    """
    Reduce la respuesta de `construir_sectores` a lo que el modelo necesita:
    sin geometría, con el PM2.5 redondeado y con los agregados de ciudad ya
    calculados (para que el modelo no tenga que hacer aritmética).
    """
    comunas = []
    for sector in sectores:
        pm25 = sector["pm25_promedio"]
        comunas.append(
            {
                "comuna": sector["nombre"],
                # `sin_datos_recientes` no implica pm25 nulo: un sector con
                # sensores pero lectura vieja conserva su último valor conocido.
                # Se expone igual, marcado como no confiable, para no mentir
                # por omisión si el usuario pregunta por esa comuna.
                "pm25_ug_m3": round(pm25, 1) if pm25 is not None else None,
                "estado": sector["estado"],
                # Se deriva de `estado`, NO de `sin_datos_recientes`: un sensor
                # puede reportar a tiempo pero con `pm25` nulo (solo humedad o
                # CO2), y entonces el estado es "gris" aunque la lectura sea
                # reciente. Derivarlo de la frescura dejaría al modelo viendo
                # `estado: "gris"` junto a `dato_confiable: true` — exactamente
                # la contradicción que la regla 4 del system prompt prohíbe.
                "dato_confiable": sector["estado"] != "gris",
            }
        )

    # Los agregados de ciudad solo se calculan con comunas de dato confiable:
    # promediar lecturas viejas daría una cifra que nadie puede reproducir
    # desde el mapa.
    confiables = [c for c in comunas if c["dato_confiable"]]

    resumen = {
        "total_comunas": len(comunas),
        "comunas_con_dato_confiable": len(confiables),
        "comunas_en_gris": len(comunas) - len(confiables),
        "promedio_ciudad_ug_m3": None,
        "mejor_comuna": None,
        "peor_comuna": None,
    }

    if confiables:
        resumen["promedio_ciudad_ug_m3"] = round(
            sum(c["pm25_ug_m3"] for c in confiables) / len(confiables), 1
        )
        mejor = min(confiables, key=lambda c: c["pm25_ug_m3"])
        peor = max(confiables, key=lambda c: c["pm25_ug_m3"])
        resumen["mejor_comuna"] = {"comuna": mejor["comuna"], "pm25_ug_m3": mejor["pm25_ug_m3"]}
        resumen["peor_comuna"] = {"comuna": peor["comuna"], "pm25_ug_m3": peor["pm25_ug_m3"]}

    return {"comunas": comunas, "resumen_ciudad": resumen}


async def construir_contexto(sector_index: SectorIndex) -> dict:
    """
    Devuelve el snapshot de contexto (cacheado ~1 min, ver
    TTL_CONTEXTO_CHATBOT_SEGUNDOS). Nunca lanza por un fallo de ClickHouse:
    en ese caso devuelve el snapshot con `datos_sensores_disponibles: False`.
    """
    cacheado = chatbot_context_cache.get(_CLAVE_CACHE)
    if cacheado is not None:
        return cacheado

    contexto = {
        "generado_en": datetime.now(timezone.utc).isoformat(),
        "ciudad": "Cali, Colombia",
        "umbrales_oms_pm25_ug_m3": {
            "verde_bueno": f"< {PM25_UMBRAL_BUENO}",
            "amarillo_moderado": f"{PM25_UMBRAL_BUENO} a {PM25_UMBRAL_MODERADO}",
            "rojo_dañino": f"> {PM25_UMBRAL_MODERADO}",
            "gris": "sin lecturas recientes — dato NO confiable, no significa aire limpio",
        },
        "contenido_educativo": _cargar_educacion(),
    }

    try:
        sectores = await construir_sectores(sector_index)
        contexto["datos_sensores_disponibles"] = True
        contexto.update(_resumir_sectores(sectores))
    except Exception as exc:  # noqa: BLE001 — cualquier fallo de ClickHouse degrada, no rompe
        print(f"[chatbot] No se pudo construir el snapshot de sectores: {exc!r}")
        contexto["datos_sensores_disponibles"] = False
        contexto["nota"] = (
            "Los datos de los sensores no están disponibles en este momento. "
            "No hay cifras de PM2.5 que reportar; dilo explícitamente."
        )
        # No se cachea un contexto degradado: si ClickHouse se recupera en
        # 5 segundos, el siguiente mensaje debe volver a intentarlo.
        return contexto

    chatbot_context_cache[_CLAVE_CACHE] = contexto
    return contexto


def serializar(contexto: dict) -> str:
    """Convierte el snapshot al bloque de texto que va dentro del system prompt."""
    return json.dumps(contexto, ensure_ascii=False, indent=None, default=str)
