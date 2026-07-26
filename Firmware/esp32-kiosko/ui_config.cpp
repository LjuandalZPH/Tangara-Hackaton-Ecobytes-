#include "ui_config.h"

#include <WiFi.h>

#include "net_client.h"
#include "storage_prefs.h"
#include "secrets.h"

namespace ui_config {

namespace {

// Todo el estado del wizard vive en estos punteros namespace-scoped en vez
// de una struct/clase -- solo existe una pantalla de config a la vez en
// este kiosko (no hay multiples instancias concurrentes), asi que no vale
// la pena la indireccion extra de lv_event_get_user_data() para pasar un
// contexto. Se resetean cada vez que construirPantalla() corre de nuevo.
lv_obj_t* pasoRed = nullptr;
lv_obj_t* pasoPassword = nullptr;
lv_obj_t* pasoUrl = nullptr;
lv_obj_t* dropdownRedes = nullptr;
lv_obj_t* tituloPassword = nullptr;
lv_obj_t* areaPassword = nullptr;
lv_obj_t* areaUrl = nullptr;
lv_obj_t* teclado = nullptr;
lv_obj_t* etiquetaEstado = nullptr;
lv_obj_t* botonGuardar = nullptr;

String ssidElegido;

void mostrarSoloPaso(lv_obj_t* paso) {
  lv_obj_add_flag(pasoRed, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_flag(pasoPassword, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_flag(pasoUrl, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_flag(teclado, LV_OBJ_FLAG_HIDDEN);
  lv_obj_clear_flag(paso, LV_OBJ_FLAG_HIDDEN);
}

void alElegirRed(lv_event_t* e) {
  char buffer[64];
  lv_dropdown_get_selected_str(dropdownRedes, buffer, sizeof(buffer));
  ssidElegido = String(buffer);

  lv_label_set_text_fmt(tituloPassword, "Password de \"%s\"", ssidElegido.c_str());
  lv_textarea_set_text(areaPassword, "");
  mostrarSoloPaso(pasoPassword);
}

void alConfirmarPassword(lv_event_t* e) {
  lv_obj_add_flag(teclado, LV_OBJ_FLAG_HIDDEN);
  lv_keyboard_set_textarea(teclado, nullptr);
  mostrarSoloPaso(pasoUrl);
}

void alEnfocarArea(lv_event_t* e) {
  lv_obj_t* area = lv_event_get_target(e);
  lv_keyboard_set_textarea(teclado, area);
  lv_obj_clear_flag(teclado, LV_OBJ_FLAG_HIDDEN);
}

void alCancelarTeclado(lv_event_t* e) {
  lv_obj_add_flag(teclado, LV_OBJ_FLAG_HIDDEN);
  lv_keyboard_set_textarea(teclado, nullptr);
}

void alGuardar(lv_event_t* e) {
  const String password = lv_textarea_get_text(areaPassword);
  const String url = lv_textarea_get_text(areaUrl);

  if (url.length() == 0) {
    lv_label_set_text(etiquetaEstado, "Falta la URL del backend.");
    return;
  }

  lv_obj_add_flag(teclado, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_state(botonGuardar, LV_STATE_DISABLED);
  lv_label_set_text(etiquetaEstado, "Conectando...");
  // Fuerza a LVGL a pintar "Conectando..." antes del bloqueo sincronico de
  // conectarWifi() (hasta 15s). NO lv_timer_handler(): este callback ya
  // corre dentro del lv_timer_handler() de loop() (lo dispara el touch del
  // boton) -- llamarlo de nuevo aca es reentrante, LVGL no lo soporta y
  // causa cuelgues/demoras raras (visto en hardware real). lv_refr_now()
  // solo fuerza el redibujado, sin tocar handlers de indev/timers, es
  // seguro llamarlo desde un callback.
  lv_refr_now(nullptr);

  if (net::conectarWifi(ssidElegido.c_str(), password.c_str())) {
    storage::ConfigRed config;
    config.wifiSsid = ssidElegido;
    config.wifiPassword = password;
    config.backendUrl = url;
    storage::guardarConfigRed(config);

    lv_label_set_text(etiquetaEstado, "Conectado. Reiniciando...");
    lv_refr_now(nullptr);
    delay(1000);
    ESP.restart();
  } else {
    lv_label_set_text(etiquetaEstado, "No se pudo conectar. Revisa el password e intenta de nuevo.");
    lv_obj_clear_state(botonGuardar, LV_STATE_DISABLED);
  }
}

lv_obj_t* crearContenedorPaso(lv_obj_t* padre) {
  lv_obj_t* contenedor = lv_obj_create(padre);
  lv_obj_set_size(contenedor, lv_pct(100), lv_pct(100));
  lv_obj_set_style_pad_all(contenedor, 10, 0);
  lv_obj_set_flex_flow(contenedor, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_flex_align(contenedor, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_row(contenedor, 8, 0);
  return contenedor;
}

}  // namespace

lv_obj_t* construirPantalla() {
  lv_obj_t* pantalla = lv_obj_create(nullptr);

  // --- Paso 1: elegir red ---
  pasoRed = crearContenedorPaso(pantalla);

  lv_obj_t* tituloRed = lv_label_create(pasoRed);
  lv_label_set_text(tituloRed, "Elegi tu red WiFi");

  dropdownRedes = lv_dropdown_create(pasoRed);
  lv_obj_set_width(dropdownRedes, lv_pct(90));

  Serial.println("ui_config: escaneando redes WiFi...");
  WiFi.mode(WIFI_STA);
  // Mitigacion de brownout: el escaneo
  // usa la radio a full power igual que una conexion -- sin esto corria
  // sin la reduccion de TX power que se aplica en net::conectarWifi(),
  // reintroduciendo la misma inestabilidad vista antes.
  WiFi.setTxPower(WIFI_POWER_2dBm);
  const int cantidadRedes = WiFi.scanNetworks();
  if (cantidadRedes <= 0) {
    Serial.println("ui_config: no se encontraron redes.");
    lv_dropdown_set_options(dropdownRedes, "(sin redes encontradas)");
  } else {
    String opciones;
    for (int i = 0; i < cantidadRedes; i++) {
      if (i > 0) opciones += "\n";
      opciones += WiFi.SSID(i);
    }
    lv_dropdown_set_options(dropdownRedes, opciones.c_str());
    Serial.printf("ui_config: %d redes encontradas.\n", cantidadRedes);
  }
  WiFi.scanDelete();  // libera el resultado del scan, no hace falta mas.

  lv_obj_t* botonSiguienteRed = lv_btn_create(pasoRed);
  lv_obj_t* etiquetaSiguienteRed = lv_label_create(botonSiguienteRed);
  lv_label_set_text(etiquetaSiguienteRed, "Siguiente");
  lv_obj_add_event_cb(botonSiguienteRed, alElegirRed, LV_EVENT_CLICKED, nullptr);

  // --- Paso 2: password ---
  pasoPassword = crearContenedorPaso(pantalla);

  tituloPassword = lv_label_create(pasoPassword);
  lv_label_set_text(tituloPassword, "Password");

  areaPassword = lv_textarea_create(pasoPassword);
  lv_obj_set_width(areaPassword, lv_pct(90));
  lv_textarea_set_password_mode(areaPassword, true);
  lv_textarea_set_one_line(areaPassword, true);
  lv_textarea_set_placeholder_text(areaPassword, "Password WiFi (vacio si es abierta)");
  lv_obj_add_event_cb(areaPassword, alEnfocarArea, LV_EVENT_FOCUSED, nullptr);

  lv_obj_t* botonSiguientePassword = lv_btn_create(pasoPassword);
  lv_obj_t* etiquetaSiguientePassword = lv_label_create(botonSiguientePassword);
  lv_label_set_text(etiquetaSiguientePassword, "Siguiente");
  lv_obj_add_event_cb(botonSiguientePassword, alConfirmarPassword, LV_EVENT_CLICKED, nullptr);

  // --- Paso 3: URL del backend + guardar ---
  pasoUrl = crearContenedorPaso(pantalla);

  lv_obj_t* tituloUrl = lv_label_create(pasoUrl);
  lv_label_set_text(tituloUrl, "URL del backend");

  areaUrl = lv_textarea_create(pasoUrl);
  lv_obj_set_width(areaUrl, lv_pct(90));
  lv_textarea_set_one_line(areaUrl, true);
  lv_textarea_set_placeholder_text(areaUrl, "https://tu-backend.ts.net");
  // Precarga: primero la config ya guardada en NVS (si el usuario esta
  // reabriendo el portal para cambiar de red, no hace falta que reescriba
  // la URL); si no hay nada guardado (ej. recien borrada la flash durante
  // pruebas de T-07.3), cae a kBackendBaseUrl de secrets.h para no tener
  // que tipear la URL de Funnel a mano en cada prueba -- sigue siendo
  // editable, esto es solo un default, no un bypass del wizard.
  const storage::ConfigRed configPrevia = storage::cargarConfigRed();
  if (configPrevia.backendUrl.length() > 0) {
    lv_textarea_set_text(areaUrl, configPrevia.backendUrl.c_str());
  } else {
    lv_textarea_set_text(areaUrl, kBackendBaseUrl);
  }
  lv_obj_add_event_cb(areaUrl, alEnfocarArea, LV_EVENT_FOCUSED, nullptr);

  botonGuardar = lv_btn_create(pasoUrl);
  lv_obj_t* etiquetaGuardar = lv_label_create(botonGuardar);
  lv_label_set_text(etiquetaGuardar, "Guardar y conectar");
  lv_obj_add_event_cb(botonGuardar, alGuardar, LV_EVENT_CLICKED, nullptr);

  etiquetaEstado = lv_label_create(pasoUrl);
  lv_label_set_text(etiquetaEstado, "");
  lv_obj_set_width(etiquetaEstado, lv_pct(90));
  lv_label_set_long_mode(etiquetaEstado, LV_LABEL_LONG_WRAP);

  // --- Teclado, compartido entre los pasos 2 y 3 ---
  // Se re-vincula al textarea que corresponda vía alEnfocarArea() (evento
  // FOCUSED); DEFOCUSED no lo oculta a propósito -- si no, tocar el botón
  // "Siguiente"/"Guardar" (que desenfoca el textarea) lo escondería un
  // instante antes de procesar el click, dando una sensación de parpadeo.
  teclado = lv_keyboard_create(pantalla);
  lv_obj_set_size(teclado, lv_pct(100), 120);
  lv_obj_align(teclado, LV_ALIGN_BOTTOM_MID, 0, 0);
  lv_obj_add_flag(teclado, LV_OBJ_FLAG_HIDDEN);
  lv_obj_add_event_cb(teclado, alCancelarTeclado, LV_EVENT_CANCEL, nullptr);

  mostrarSoloPaso(pasoRed);

  return pantalla;
}

}  // namespace ui_config
