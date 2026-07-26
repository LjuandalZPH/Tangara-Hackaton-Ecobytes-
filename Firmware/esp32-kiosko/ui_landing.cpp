#include "ui_landing.h"

#include "net_client.h"
#include "storage_prefs.h"
#include "ui_config.h"
#include "ui_details.h"

namespace ui_landing {

namespace {

lv_color_t colorEstado(const String& estado) {
  if (estado == "verde") return lv_color_hex(0x2ecc71);
  if (estado == "amarillo") return lv_color_hex(0xf1c40f);
  if (estado == "rojo") return lv_color_hex(0xe74c3c);
  return lv_color_hex(0x95a5a6);  // "gris" (o cualquier valor inesperado).
}

void alTocarSector(lv_event_t* e) {
  String* sectorId = static_cast<String*>(lv_event_get_user_data(e));
  Serial.printf("ui_landing: navegando a Details de %s\n", sectorId->c_str());
  lv_scr_load(ui_details::construirPantalla(sectorId->c_str()));
}

void alMantenerPresionadoHeader(lv_event_t* e) {
  Serial.println("ui_landing: header mantenido presionado -- volviendo al portal de configuracion.");
  lv_scr_load(ui_config::construirPantalla());
}

}  // namespace

lv_obj_t* construirPantalla() {
  // Pantalla de carga temporal -- sin esto, la pantalla anterior (Details,
  // o la misma Landing si se volvio desde ahi) quedaba "congelada" en
  // pantalla durante los ~35-40s que tarda el fetch de mas abajo, sin
  // ningun indicio de que estaba cargando (reportado probando en hardware
  // real). Se carga y se fuerza a pintar de inmediato con lv_refr_now()
  // (NO lv_timer_handler(): esta funcion se llama desde adentro de un
  // callback de touch, que ya corre dentro del lv_timer_handler() de
  // loop() -- llamarlo de nuevo aca seria reentrante, causa de cuelgues/
  // demoras raras vistas en hardware real. lv_refr_now() solo fuerza el
  // redibujado, sin knowledge de handlers de indev/timers, es seguro
  // llamarlo desde un callback), y se borra despues de cargar la
  // pantalla real -- a diferencia de otros objetos que este firmware deja
  // sin liberar al navegar (simplificacion aceptada porque se crean una
  // sola vez), esta conviene liberarla porque se crea en cada entrada a la
  // Landing (arranque + cada "Volver" desde Details), no una sola vez.
  lv_obj_t* pantallaCarga = lv_obj_create(nullptr);
  lv_obj_t* etiquetaCarga = lv_label_create(pantallaCarga);
  lv_label_set_text(etiquetaCarga, "Cargando datos de sectores...\n(puede tardar unos segundos)");
  lv_obj_set_style_text_align(etiquetaCarga, LV_TEXT_ALIGN_CENTER, 0);
  lv_obj_center(etiquetaCarga);
  lv_scr_load(pantallaCarga);
  lv_refr_now(nullptr);

  lv_obj_t* pantalla = lv_obj_create(nullptr);
  lv_obj_set_flex_flow(pantalla, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_style_pad_all(pantalla, 4, 0);
  lv_obj_set_style_pad_row(pantalla, 4, 0);

  // --- Header: agregados de ciudad (se completa mas abajo, despues del
  // fetch) + gesto de "mantener presionado ~2s" para volver al portal de
  // configuracion (ver docs/firmware-esp32-kiosko.md, "acceso posterior").
  lv_obj_t* header = lv_obj_create(pantalla);
  lv_obj_set_size(header, lv_pct(100), 60);
  lv_obj_add_flag(header, LV_OBJ_FLAG_CLICKABLE);
  lv_obj_add_event_cb(header, alMantenerPresionadoHeader, LV_EVENT_LONG_PRESSED, nullptr);

  lv_obj_t* etiquetaHeader = lv_label_create(header);
  lv_obj_set_width(etiquetaHeader, lv_pct(95));
  lv_label_set_long_mode(etiquetaHeader, LV_LABEL_LONG_WRAP);
  lv_label_set_text(etiquetaHeader, "Cargando datos de sectores...");

  lv_obj_t* lista = lv_list_create(pantalla);
  lv_obj_set_width(lista, lv_pct(100));
  lv_obj_set_flex_grow(lista, 1);

  // Fetch sincronico/bloqueante -- ~35-40s (ver docs/firmware-esp32-kiosko.md).
  // La pantallaCarga de arriba es lo unico que se ve mientras esto
  // corre (ver comentario al principio de la funcion).
  const storage::ConfigRed config = storage::cargarConfigRed();
  const JsonDocument filtro = net::construirFiltroSectores();
  JsonDocument doc;
  const bool ok = net::fetchSectores(config.backendUrl, filtro, doc);

  if (!ok) {
    lv_label_set_text(etiquetaHeader,
                       "No se pudo cargar la informacion de sectores. Reintenta volviendo a esta pantalla.");
    lv_scr_load(pantalla);
    lv_obj_del(pantallaCarga);
    return pantalla;
  }

  JsonArray sectores = doc["sectores"].as<JsonArray>();

  double sumaPm25 = 0;
  int contadorPm25 = 0;
  int conteoVerde = 0, conteoAmarillo = 0, conteoRojo = 0, conteoGris = 0;

  for (JsonObject sector : sectores) {
    const char* nombre = sector["nombre"] | "?";
    const char* id = sector["id"] | "";
    const char* estadoCstr = sector["estado"] | "gris";
    const String estado(estadoCstr);

    if (!sector["pm25_promedio"].isNull()) {
      sumaPm25 += sector["pm25_promedio"].as<double>();
      contadorPm25++;
    }

    if (estado == "verde") conteoVerde++;
    else if (estado == "amarillo") conteoAmarillo++;
    else if (estado == "rojo") conteoRojo++;
    else conteoGris++;

    lv_obj_t* boton = lv_list_add_btn(lista, nullptr, nombre);
    lv_obj_set_style_bg_color(boton, colorEstado(estado), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(boton, LV_OPA_40, LV_PART_MAIN);

    // El id se copia a memoria propia (String* con new, sin liberar
    // despues) porque `doc` -- y con el, el const char* de sector["id"] --
    // deja de ser valido apenas construirPantalla() retorna, mucho antes
    // de que el usuario llegue a tocar la fila. Mismo tipo de
    // simplificacion que el resto del firmware por ahora (pantallas no se
    // liberan explicitamente al navegar entre ellas).
    lv_obj_add_event_cb(boton, alTocarSector, LV_EVENT_CLICKED, new String(id));
  }

  String textoHeader;
  if (contadorPm25 > 0) {
    textoHeader = "PM2.5 promedio ciudad: " + String(sumaPm25 / contadorPm25, 1) +
                  "  |  verde:" + String(conteoVerde) + " amarillo:" + String(conteoAmarillo) +
                  " rojo:" + String(conteoRojo) + " gris:" + String(conteoGris);
  } else {
    textoHeader = "Sin datos de PM2.5 disponibles todavia.  |  verde:" + String(conteoVerde) +
                  " amarillo:" + String(conteoAmarillo) + " rojo:" + String(conteoRojo) +
                  " gris:" + String(conteoGris);
  }
  lv_label_set_text(etiquetaHeader, textoHeader.c_str());

  lv_scr_load(pantalla);
  lv_obj_del(pantallaCarga);
  return pantalla;
}

}  // namespace ui_landing
