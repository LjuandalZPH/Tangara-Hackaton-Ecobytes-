#pragma once

#include <lvgl.h>

// T-07.4: pantalla Landing -- pide GET /sectors filtrado (net_client.h,
// patron validado en hardware real) de forma sincronica/bloqueante al
// construir la pantalla (~35-40s, ver docs/firmware-esp32-kiosko.md),
// calcula client-side el PM2.5 promedio de ciudad y el conteo de sectores
// por estado, y lista los 22 sectores en un lv_list con un badge de color
// por fila. Tocar una fila navega a Details (ui_details.h) con ese id.
// Mantener presionado el header ~2s vuelve al portal de configuracion
// (ui_config.h) -- requiere indevDrv.long_press_time = 2000 seteado en
// esp32-kiosko.ino (por defecto LVGL usa un valor mas corto, global para
// toda la app, no por widget). Ver docs/firmware-esp32-kiosko.md.

namespace ui_landing {

// Construye la pantalla y la devuelve sin cargarla (lv_scr_load() queda a
// cargo de quien llama).
lv_obj_t* construirPantalla();

}  // namespace ui_landing
