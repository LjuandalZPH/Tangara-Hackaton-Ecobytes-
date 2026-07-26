#pragma once

#include <Arduino.h>
#include <ArduinoJson.h>

// Cliente HTTP para GET /sectors, con el patron validado en hardware real:
// filtra "geometry" con DeserializationOption::Filter y parsea en streaming
// directo desde el WiFiClient, para que el pico de memoria nunca incluya el
// JSON completo sin filtrar (~774 KB, ver docs/firmware-esp32-kiosko.md).
// Reusado por ui_landing.cpp y por el smoke test de esp32-kiosko.ino.

namespace net {

// Imprime heap libre/minimo historico/bloque contiguo mas grande por
// Serial, con una etiqueta. Mismo formato que el spike T-07.1, para poder
// comparar directamente contra esos numeros ahora que LVGL+LovyanGFX estan
// enlazados en el binario.
void imprimirHeap(const char* etiqueta);

// Conecta a la red WiFi indicada, bloqueando hasta conectar o hasta
// timeoutMs. Devuelve true si conecto. Movida aca desde esp32-kiosko.ino
// en T-07.3 para que ui_config.cpp (el portal de configuracion tactil)
// pueda reutilizarla al probar la red que el usuario elige en pantalla,
// sin duplicar la logica.
bool conectarWifi(const char* ssid, const char* password, unsigned long timeoutMs = 15000);

// Filtro de deserializacion: se queda con todo excepto "geometry" (el
// MultiPolygon de cada comuna, que el kiosko no dibuja). Construir una sola
// vez (es el mismo filtro en cada fetch) y pasarlo por referencia a
// fetchSectores().
JsonDocument construirFiltroSectores();

// Hace GET {backendUrl}/sectors y parsea la respuesta aplicando `filtro`.
// `backendUrl` viene de la config guardada en NVS (storage_prefs.h,
// llenada por el wizard de ui_config.cpp en T-07.3) -- ya no es la
// constante fija de secrets.h, que quedo sin uso en el flujo real desde
// T-07.3 (ver TODO en esp32-kiosko.ino). Si devuelve true, `doc` queda
// poblado con {"sectores": [...]}; si devuelve false, `doc` no es valido --
// el detalle del fallo (codigo HTTP, error TLS, o error de parseo) ya se
// imprimio por Serial, mismo criterio que T-07.1.
bool fetchSectores(const String& backendUrl, const JsonDocument& filtro, JsonDocument& doc);

// Hace GET {backendUrl}/sectors/{sectorId} (indicadores actuales +
// historial_24h de ese sector, ~2-3KB) y GET {backendUrl}/risk/{sectorId}
// (4 agregados anuales, <1KB) -- payloads chicos, T-07.5/T-07.6
// (ui_details.cpp). A diferencia de fetchSectores(), vuelcan la respuesta
// completa a un String antes de parsear (sin filtro ni streaming, no hace
// falta para este tamaño). Mismo criterio de error que el resto: true si
// pudo, false con el detalle ya impreso por Serial.
bool fetchDetalleSector(const String& backendUrl, const String& sectorId, JsonDocument& doc);
bool fetchRiesgoSector(const String& backendUrl, const String& sectorId, JsonDocument& doc);

}  // namespace net
