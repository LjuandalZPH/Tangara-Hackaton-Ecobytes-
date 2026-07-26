"""
Herramientas (function calling) que el chatbot puede invocar.

El snapshot de `chatbot_context.py` lleva el **estado actual** de las 22
comunas y con eso se responde la mayoría de preguntas sin ninguna ida y
vuelta extra. Lo que no cabe ahí —histórico de meses, evolución hora a
hora, sensores individuales, CO2 y humedad— vive aquí: el modelo lo pide
solo para la comuna concreta sobre la que le preguntaron.

Ese es el criterio para decidir qué va en el prompt y qué es una tool:
**lo que se necesita siempre y es pequeño va en el prompt; lo que se
necesita a veces y crece con las 22 comunas va en una tool.**

Las tools no llaman a la API por HTTP: usan los mismos servicios que los
routers (`clickhouse_client`, `geo`, `sectores`), así que devuelven
exactamente los mismos números que `GET /risk/{sector}` o
`GET /sectors/{id}` — no hay dos fuentes de verdad.
"""

import json
import re

from config import (
    HORAS_HISTORIAL_SECTOR,
    MIN_MESES_HISTORICO_SUFICIENTE,
    PM25_UMBRAL_DIARIO_OMS,
)
from services import clickhouse_client
from services.geo import SectorIndex, obtener_mapeo_sensor_sector
from services.sectores import es_reciente, estado_por_pm25


class ToolDesconocida(ValueError):
    """El modelo pidió una herramienta que no existe."""


# ─────────────────────────────────────────────────────────────
# Declaración de las tools para la API de OpenAI
# ─────────────────────────────────────────────────────────────
# `comuna` se declara como string libre (no enum de 22 valores) a
# propósito: el modelo escribe lo que entendió del usuario ("17",
# "Comuna 17", "comuna-17") y `_resolver_sector_id` lo normaliza. Un enum
# obligaría al modelo a acertar el formato exacto y fallaría más.
_PARAMETRO_COMUNA = {
    "type": "object",
    "properties": {
        "comuna": {
            "type": "string",
            "description": "Comuna de Cali sobre la que se consulta. "
                           "Acepta '17', 'Comuna 17' o 'comuna-17'.",
        }
    },
    "required": ["comuna"],
}

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "perfil_historico_comuna",
            "description": "Perfil histórico de PM2.5 del último año de una comuna: "
                           "promedio anual, peor mes, mejor mes y cuántos días "
                           "superaron el límite diario de la OMS. Úsala cuando "
                           "pregunten por meses, tendencias, el año, o cómo ha "
                           "estado históricamente una comuna.",
            "parameters": _PARAMETRO_COMUNA,
        },
    },
    {
        "type": "function",
        "function": {
            "name": "evolucion_24h_comuna",
            "description": "Promedio de PM2.5 hora a hora de las últimas 24 horas "
                           "de una comuna. Úsala cuando pregunten por hoy, las "
                           "últimas horas, si mejoró o empeoró, o a qué hora "
                           "conviene salir.",
            "parameters": _PARAMETRO_COMUNA,
        },
    },
    {
        "type": "function",
        "function": {
            "name": "sensores_de_comuna",
            "description": "Sensores individuales de una comuna con su última "
                           "lectura. Úsala cuando pregunten cuántos sensores hay, "
                           "dónde están, o por qué una comuna no tiene datos.",
            "parameters": _PARAMETRO_COMUNA,
        },
    },
    {
        "type": "function",
        "function": {
            "name": "detalle_actual_comuna",
            "description": "Medidas actuales completas de una comuna: además del "
                           "PM2.5 que ya está en el contexto, trae CO2 y humedad, "
                           "que no vienen en él. Úsala solo si preguntan por CO2 "
                           "o humedad.",
            "parameters": _PARAMETRO_COMUNA,
        },
    },
]


def _resolver_sector_id(sector_index: SectorIndex, comuna: str) -> str:
    """
    Normaliza lo que escriba el modelo al `id` real del sector.

    Lanza ValueError con un mensaje pensado para que el modelo lo lea y se
    lo explique al usuario, en vez de un 500 que cortaría la conversación.
    """
    # Se exige que haya UN solo número en el texto. Tomar el primero de
    # varios resolvería en silencio a la comuna equivocada: con "comuna 5,
    # cerca de la calle 15" devolvería la 5 sin avisar de la ambigüedad, y
    # el modelo daría datos de una comuna que nadie pidió.
    numeros = re.findall(r"\d+", comuna or "")
    if len(numeros) != 1:
        raise ValueError(
            f"No se entiende '{comuna}' como una única comuna de Cali. "
            f"Pide una sola comuna a la vez, por su número del 1 al 22."
        )

    sector_id = f"comuna-{int(numeros[0])}"
    if sector_index.sector_por_id(sector_id) is None:
        raise ValueError(
            f"La comuna {numeros[0]} no existe: Cali tiene 22 comunas, "
            f"numeradas de la 1 a la 22."
        )
    return sector_id


async def _sensores_del_sector(sector_index: SectorIndex, sector_id: str) -> list[str]:
    mapeo = await obtener_mapeo_sensor_sector(sector_index)
    return [nombre for nombre, sid in mapeo.items() if sid == sector_id]


async def _perfil_historico(sector_index: SectorIndex, sector_id: str) -> dict:
    """Mismos cálculos que `GET /risk/{sector}` (routers/risk.py)."""
    sensores = await _sensores_del_sector(sector_index, sector_id)
    meses = await clickhouse_client.promedio_mensual(sensores)
    dias = await clickhouse_client.dias_sobre_limite(sensores, PM25_UMBRAL_DIARIO_OMS)

    if not meses:
        return {
            "comuna": sector_id,
            "hay_historico": False,
            "nota": "Esta comuna no tiene sensores con histórico registrado.",
            "dias_sobre_limite_oms_ultimo_anio": dias,
        }

    promedios = [m["pm25_promedio"] for m in meses if m["pm25_promedio"] is not None]
    peor = max(meses, key=lambda m: m["pm25_promedio"] or float("-inf"))
    mejor = min(meses, key=lambda m: m["pm25_promedio"] or float("inf"))
    promedio_anual = sum(promedios) / len(promedios) if promedios else None

    return {
        "comuna": sector_id,
        "hay_historico": True,
        "meses_con_datos": len(meses),
        # El frontend muestra una advertencia bajo este mismo criterio; el
        # modelo debe poder decir lo mismo en palabras.
        "historico_suficiente": len(meses) >= MIN_MESES_HISTORICO_SUFICIENTE,
        "promedio_anual_ug_m3": round(promedio_anual, 1) if promedio_anual is not None else None,
        # El promedio anual es el número más citado en preguntas de tendencia
        # y también necesita su estado: 14.9 sin clasificar invita al modelo
        # a llamarlo "moderado" cuando todavía es verde.
        "estado_promedio_anual": estado_por_pm25(promedio_anual),
        # Redondeados y con su estado, por el mismo motivo que en
        # `_evolucion_24h`: sin el estado el modelo lo clasifica mal, y sin
        # redondear recita "11.142857 µg/m³", una precisión que el dato no tiene.
        "peor_mes": {
            "mes": peor["mes"].strftime("%Y-%m"),
            "pm25_ug_m3": round(peor["pm25_promedio"], 1) if peor["pm25_promedio"] is not None else None,
            "estado": estado_por_pm25(peor["pm25_promedio"]),
        },
        "mejor_mes": {
            "mes": mejor["mes"].strftime("%Y-%m"),
            "pm25_ug_m3": round(mejor["pm25_promedio"], 1) if mejor["pm25_promedio"] is not None else None,
            "estado": estado_por_pm25(mejor["pm25_promedio"]),
        },
        "dias_sobre_limite_oms_ultimo_anio": dias,
        "limite_oms_diario_ug_m3": PM25_UMBRAL_DIARIO_OMS,
    }


async def _evolucion_24h(sector_index: SectorIndex, sector_id: str) -> dict:
    sensores = await _sensores_del_sector(sector_index, sector_id)
    horas = await clickhouse_client.promedio_horario(sensores, horas=HORAS_HISTORIAL_SECTOR)

    if not horas:
        return {
            "comuna": sector_id,
            "hay_datos": False,
            "nota": "Sin lecturas en las últimas 24 horas en esta comuna.",
        }

    # El `estado` va calculado, no se deja que el modelo clasifique: en una
    # prueba real llamó "moderado" a 6.1 µg/m³ (que es verde) al ver solo el
    # número. La clasificación es de `estado_por_pm25`, la misma del mapa.
    return {
        "comuna": sector_id,
        "hay_datos": True,
        "horas": [
            {
                "hora": h["hora"].strftime("%Y-%m-%d %H:00"),
                "pm25_ug_m3": round(h["pm25_promedio"], 1) if h["pm25_promedio"] is not None else None,
                "estado": estado_por_pm25(h["pm25_promedio"]),
            }
            for h in horas
        ],
    }


async def _sensores(sector_index: SectorIndex, sector_id: str) -> dict:
    nombres = await _sensores_del_sector(sector_index, sector_id)
    lecturas = {l["name"]: l for l in await clickhouse_client.ultimo_promedio_por_sensor()}

    sensores = []
    for nombre in sorted(nombres):
        lectura = lecturas.get(nombre)
        if lectura is None:
            # `estado: "gris"` explícito, igual que en el resto del código:
            # omitir la clave dejaría al modelo deduciendo qué significa un
            # sensor sin lectura, que es justo donde confunde "sin dato" con
            # "aire limpio".
            sensores.append(
                {"nombre": nombre, "activo": False, "pm25_ug_m3": None, "estado": "gris"}
            )
            continue
        reciente = es_reciente(lectura["ultima_lectura"])
        sensores.append(
            {
                "nombre": nombre,
                "activo": reciente,
                "pm25_ug_m3": round(lectura["pm25_promedio"], 1) if lectura["pm25_promedio"] is not None else None,
                "estado": estado_por_pm25(lectura["pm25_promedio"]) if reciente else "gris",
            }
        )

    return {
        "comuna": sector_id,
        "total_sensores": len(sensores),
        "sensores_activos": sum(1 for s in sensores if s["activo"]),
        "sensores": sensores,
    }


async def _detalle_actual(sector_index: SectorIndex, sector_id: str) -> dict:
    nombres = set(await _sensores_del_sector(sector_index, sector_id))
    lecturas = [l for l in await clickhouse_client.ultimo_promedio_por_sensor() if l["name"] in nombres]

    if not lecturas:
        return {
            "comuna": sector_id,
            "hay_datos": False,
            "nota": "Sin lecturas recientes: el estado de esta comuna es gris.",
        }

    def _promedio(campo: str):
        valores = [l[campo] for l in lecturas if l[campo] is not None]
        return round(sum(valores) / len(valores), 1) if valores else None

    ultima = max(l["ultima_lectura"] for l in lecturas)
    return {
        "comuna": sector_id,
        "hay_datos": True,
        "pm25_ug_m3": _promedio("pm25_promedio"),
        "estado": estado_por_pm25(_promedio("pm25_promedio")) if es_reciente(ultima) else "gris",
        "co2_ppm": _promedio("co2_promedio"),
        "humedad_pct": _promedio("hum_promedio"),
        "ultima_lectura": ultima.isoformat(),
        "dato_reciente": es_reciente(ultima),
    }


_EJECUTORES = {
    "perfil_historico_comuna": _perfil_historico,
    "evolucion_24h_comuna": _evolucion_24h,
    "sensores_de_comuna": _sensores,
    "detalle_actual_comuna": _detalle_actual,
}


async def ejecutar(nombre: str, argumentos: dict, sector_index: SectorIndex) -> str:
    """
    Ejecuta una tool y devuelve su resultado ya serializado.

    Los errores previsibles (comuna inexistente, ClickHouse caído) se
    devuelven **como resultado**, no se lanzan: el modelo puede explicarle
    al usuario qué pasó y seguir la conversación, mientras que una
    excepción cortaría la respuesta entera con un 502.
    """
    ejecutor = _EJECUTORES.get(nombre)
    if ejecutor is None:
        raise ToolDesconocida(nombre)

    try:
        sector_id = _resolver_sector_id(sector_index, argumentos.get("comuna", ""))
        resultado = await ejecutor(sector_index, sector_id)
    except ValueError as exc:
        resultado = {"error": str(exc)}
    except Exception as exc:  # noqa: BLE001 — un fallo de datos no debe tumbar la charla
        print(f"[chatbot] Fallo ejecutando la tool {nombre}: {exc!r}")
        resultado = {
            "error": "No se pudieron consultar esos datos en este momento. "
                     "Dile al usuario que lo intente de nuevo en unos minutos."
        }

    return json.dumps(resultado, ensure_ascii=False, default=str)
