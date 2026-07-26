#pragma once

#include <lvgl.h>

// Portal de configuracion tactil. Wizard de 3 pasos en la misma
// pantalla (mostrando/ocultando contenedores, no pantallas separadas --
// 320x240 no alcanza para mostrar todo el formulario + teclado a la vez):
//   1. Elegir red (lv_dropdown poblado con WiFi.scanNetworks()).
//   2. Password de esa red (lv_textarea en modo password + lv_keyboard).
//   3. URL del backend (lv_textarea + el mismo lv_keyboard reutilizado) y
//      boton "Guardar y conectar", que persiste en NVS (storage_prefs.h) y
//      prueba la conexion antes de reiniciar hacia el flujo normal.
// La calibracion de touch de 4 puntos NO vive aca -- es una rutina de
// LovyanGFX (lcd.calibrateTouch()), no un widget LVGL, y corre en
// esp32-kiosko.ino antes de cargar cualquier pantalla (si no, ni tocar el
// dropdown/teclado de este wizard seria confiable). Ver
// docs/firmware-esp32-kiosko.md.
//
// Acceso posterior (para cambiar de red): mantener presionado el header de
// la Landing ~2s -- ese gesto se implementa en ui_landing.cpp.

namespace ui_config {

// Construye la pantalla y la devuelve sin cargarla (lv_scr_load() queda a
// cargo de quien llama, normalmente el .ino).
lv_obj_t* construirPantalla();

}  // namespace ui_config
