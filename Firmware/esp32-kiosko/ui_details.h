#pragma once

#include <lvgl.h>

// Pantalla Details del sector elegido en la Landing. Un
// lv_tabview con 2 pestañas -- Resumen (GET /sectors/{id}: PM2.5/CO2/
// humedad + lv_chart de historial_24h) e Historia (GET /risk/{sector}: 4
// indicadores de texto, sin grafico -- el endpoint no serializa una serie
// temporal). Sin pestaña Sensores (el kiosko no presenta datos de sensores
// individuales). Ambos fetches son sincronicos/bloqueantes al construir la
// pantalla, payloads chicos (~2-3KB y <1KB, ver docs/firmware-esp32-kiosko.md)
// -- no hace falta el streaming/filtro de net::fetchSectores(). Boton
// "Volver" arriba de las pestañas (fuera del tabview, visible en ambas)
// para regresar a la Landing (ui_landing.h).

namespace ui_details {

// Construye la pantalla del sector `sectorId` (ej. "comuna-3") y la
// devuelve sin cargarla (lv_scr_load() queda a cargo de quien llama).
lv_obj_t* construirPantalla(const char* sectorId);

}  // namespace ui_details
