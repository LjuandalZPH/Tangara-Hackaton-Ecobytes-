#include "ui_details.h"

#include <cmath>

#include "net_client.h"
#include "storage_prefs.h"
#include "ui_landing.h"

namespace ui_details {

namespace {

void alVolver(lv_event_t* e) {
  Serial.println("ui_details: volviendo a la Landing.");
  lv_scr_load(ui_landing::construirPantalla());
}

lv_color_t colorEstado(const String& estado) {
  if (estado == "verde") return lv_color_hex(0x2ecc71);
  if (estado == "amarillo") return lv_color_hex(0xf1c40f);
  if (estado == "rojo") return lv_color_hex(0xe74c3c);
  return lv_color_hex(0x95a5a6);  // "gris" (o cualquier valor inesperado).
}

lv_obj_t* crearEtiqueta(lv_obj_t* padre, const String& texto) {
  lv_obj_t* etiqueta = lv_label_create(padre);
  lv_obj_set_width(etiqueta, lv_pct(95));
  lv_label_set_long_mode(etiqueta, LV_LABEL_LONG_WRAP);
  lv_label_set_text(etiqueta, texto.c_str());
  return etiqueta;
}

// Formatea un valor numerico opcional (pm25/co2/hum) con una unidad, o
// "Sin dato" si vino null -- varios campos de /sectors/{id} pueden ser
// null (sector sin sensores con dato reciente).
String formatearOSinDato(JsonVariantConst valor, const char* unidad, int decimales) {
  if (valor.isNull()) return "Sin dato";
  return String(valor.as<double>(), decimales) + " " + unidad;
}

void construirTabResumen(lv_obj_t* tab, const char* sectorId, const String& backendUrl) {
  lv_obj_set_flex_flow(tab, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_style_pad_row(tab, 6, 0);

  JsonDocument doc;
  if (!net::fetchDetalleSector(backendUrl, sectorId, doc)) {
    crearEtiqueta(tab, "No se pudo cargar la informacion del sector.");
    return;
  }

  const char* nombre = doc["nombre"] | sectorId;
  const char* estadoCstr = doc["estado"] | "gris";
  const String estado(estadoCstr);

  lv_obj_t* titulo = crearEtiqueta(tab, nombre);
  lv_obj_set_style_text_font(titulo, lv_theme_get_font_large(titulo), 0);

  lv_obj_t* etiquetaPm25 = crearEtiqueta(
      tab, "PM2.5: " + formatearOSinDato(doc["pm25_promedio"], "ug/m3", 1) + "  (" + estado + ")");
  lv_obj_set_style_text_color(etiquetaPm25, colorEstado(estado), 0);

  crearEtiqueta(tab, "CO2: " + formatearOSinDato(doc["co2_promedio"], "ppm", 0));
  crearEtiqueta(tab, "Humedad: " + formatearOSinDato(doc["hum_promedio"], "%", 0));

  // "Ultima lectura hace X" (08-Arquitectura-ESP32.md §4.2) depende de
  // hora real vs. NTP (T-07.8, todavia no implementado) -- mientras
  // tanto, mismo criterio de fallback que ya documenta ese parrafo:
  // mostrar el timestamp crudo del backend sin relativizar.
  const char* ultimaLectura = doc["ultima_lectura"] | nullptr;
  if (ultimaLectura != nullptr) {
    crearEtiqueta(tab, String("Ultima lectura: ") + ultimaLectura);
  }

  JsonArray historial = doc["historial_24h"].as<JsonArray>();
  if (historial.size() == 0) {
    crearEtiqueta(tab, "Sin historial suficiente en las ultimas 24h.");
    return;
  }

  lv_obj_t* chart = lv_chart_create(tab);
  lv_obj_set_size(chart, lv_pct(95), 100);
  lv_chart_set_type(chart, LV_CHART_TYPE_LINE);
  lv_chart_set_point_count(chart, historial.size());
  lv_chart_series_t* serie =
      lv_chart_add_series(chart, lv_palette_main(LV_PALETTE_BLUE), LV_CHART_AXIS_PRIMARY_Y);

  for (JsonObject punto : historial) {
    JsonVariantConst valor = punto["pm25_promedio"];
    if (valor.isNull()) {
      // No inventar puntos que faltan (08-Arquitectura-ESP32.md §5.1) --
      // LV_CHART_POINT_NONE deja un hueco visible en la linea en vez de
      // interpolar o poner un 0 falso.
      lv_chart_set_next_value(chart, serie, LV_CHART_POINT_NONE);
    } else {
      lv_chart_set_next_value(chart, serie, (lv_coord_t)lround(valor.as<double>()));
    }
  }
}

void construirTabHistoria(lv_obj_t* tab, const char* sectorId, const String& backendUrl) {
  lv_obj_set_flex_flow(tab, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_style_pad_row(tab, 6, 0);

  JsonDocument doc;
  if (!net::fetchRiesgoSector(backendUrl, sectorId, doc)) {
    crearEtiqueta(tab, "No se pudo cargar el historico del sector.");
    return;
  }

  const bool historicoSuficiente = doc["historico_suficiente"] | false;
  if (!historicoSuficiente) {
    crearEtiqueta(tab, "Todavia no hay suficiente historico para este sector.");
  }

  crearEtiqueta(tab, "Promedio anual: " + formatearOSinDato(doc["promedio_anual"], "ug/m3", 2));

  JsonVariantConst peorMes = doc["peor_mes"];
  if (!peorMes.isNull()) {
    const char* mesCstr = peorMes["mes"] | "?";
    crearEtiqueta(tab, "Peor mes: " + String(mesCstr) + " (" +
                            formatearOSinDato(peorMes["promedio"], "ug/m3", 1) + ")");
  } else {
    crearEtiqueta(tab, "Peor mes: sin dato");
  }

  JsonVariantConst mejorMes = doc["mejor_mes"];
  if (!mejorMes.isNull()) {
    const char* mesCstr = mejorMes["mes"] | "?";
    crearEtiqueta(tab, "Mejor mes: " + String(mesCstr) + " (" +
                            formatearOSinDato(mejorMes["promedio"], "ug/m3", 1) + ")");
  } else {
    crearEtiqueta(tab, "Mejor mes: sin dato");
  }

  const int diasSobreLimite = doc["dias_sobre_limite_oms_ultimo_anio"] | 0;
  crearEtiqueta(tab, "Dias sobre el limite OMS (ultimo anio): " + String(diasSobreLimite));
}

}  // namespace

lv_obj_t* construirPantalla(const char* sectorId) {
  lv_obj_t* pantalla = lv_obj_create(nullptr);
  lv_obj_set_flex_flow(pantalla, LV_FLEX_FLOW_COLUMN);

  // Boton para volver a la Landing -- sin esto no hay forma de salir de
  // Details (el gesto de mantener presionado ~2s solo existe en el header
  // de la Landing, para ir al portal de configuracion, no aplica aca).
  lv_obj_t* botonVolver = lv_btn_create(pantalla);
  lv_obj_set_size(botonVolver, lv_pct(100), 30);
  lv_obj_t* etiquetaVolver = lv_label_create(botonVolver);
  lv_label_set_text(etiquetaVolver, LV_SYMBOL_LEFT " Volver");
  lv_obj_add_event_cb(botonVolver, alVolver, LV_EVENT_CLICKED, nullptr);

  lv_obj_t* tabview = lv_tabview_create(pantalla, LV_DIR_TOP, 30);
  lv_obj_set_width(tabview, lv_pct(100));
  lv_obj_set_flex_grow(tabview, 1);
  lv_obj_t* tabResumen = lv_tabview_add_tab(tabview, "Resumen");
  lv_obj_t* tabHistoria = lv_tabview_add_tab(tabview, "Historia");

  const storage::ConfigRed config = storage::cargarConfigRed();

  construirTabResumen(tabResumen, sectorId, config.backendUrl);
  construirTabHistoria(tabHistoria, sectorId, config.backendUrl);

  return pantalla;
}

}  // namespace ui_details
