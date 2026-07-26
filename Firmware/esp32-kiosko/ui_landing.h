#pragma once

#include <lvgl.h>

// T-07.4: pantalla Landing -- pide GET /sectors filtrado (net_client.h,
// patron validado en el spike T-07.1) de forma sincronica/bloqueante al
// construir la pantalla (~35-40s, ver 06-Plan-de-Accion.md parrafo 5.1),
// calcula client-side el PM2.5 promedio de ciudad y el conteo de sectores
// por estado, y lista los 22 sectores en un lv_list con un badge de color
// por fila. Tocar una fila navega a Details (ui_details.h) con ese id.
// Mantener presionado el header ~2s vuelve al portal de configuracion
// (ui_config.h) -- requiere indevDrv.long_press_time = 2000 seteado en
// esp32-kiosko.ino (por defecto LVGL usa un valor mas corto, global para
// toda la app, no por widget). Ver 08-Arquitectura-ESP32.md seccion 4.1.

namespace ui_landing {

// Construye la pantalla y la devuelve sin cargarla (lv_scr_load() queda a
// cargo de quien llama).
lv_obj_t* construirPantalla();

}  // namespace ui_landing
