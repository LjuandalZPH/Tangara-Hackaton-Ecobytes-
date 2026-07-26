#pragma once

#include <Arduino.h>

// Wrapper sobre Preferences.h (NVS) para lo que el kiosko necesita recordar
// entre reinicios: credenciales WiFi + URL del backend (portal de config,
// T-07.3) y la calibracion de 4 puntos del touch resistivo XPT2046 (por
// unidad, ver 08-Arquitectura-ESP32.md §10). Namespace unico "ecobytes"
// para no chocar con otras librerias que tambien usen NVS.

namespace storage {

struct ConfigRed {
  String wifiSsid;
  String wifiPassword;
  String backendUrl;
};

// true si ya hay una config de red guardada (wifi_ssid no vacio) -- el
// sketch la usa para decidir si arrancar directo en Landing o abrir la
// pantalla de configuracion (ver 08-Arquitectura-ESP32.md §4.0).
bool hayConfigRedGuardada();

ConfigRed cargarConfigRed();
void guardarConfigRed(const ConfigRed& config);

struct CalibracionTouch {
  // 8 elementos, no 4 -- asi lo requiere LGFX_Device::calibrateTouch()/
  // setTouchCalibrate() de LovyanGFX (verificado contra el codigo fuente
  // real en T-07.3, 06-Plan-de-Accion.md §5.6: memcpy(parameters, orig,
  // sizeof(uint16_t) * 8) en LGFXBase.cpp). La primera version de este
  // struct (T-07.2) tenia 4 campos con nombre (xMin/xMax/yMin/yMax)
  // asumiendo una calibracion simple de min/max por eje -- nunca se pudo
  // confirmar contra la libreria real en ese momento, y era la firma
  // equivocada: pasarle un array de 4 a calibrateTouch() desbordaba el
  // stack en 8 bytes (escribia los ultimos 4 de los 8 valores fuera del
  // array). No son valores con significado individual simple (min/max de
  // un eje) -- son los puntos de referencia crudos que LovyanGFX usa
  // internamente para mapear touch->pantalla, se guardan/restauran como
  // bloque opaco.
  uint16_t parametros[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  bool valida = false;  // false = todavia no se corrio la calibracion de 4 puntos.
};

CalibracionTouch cargarCalibracionTouch();
void guardarCalibracionTouch(const CalibracionTouch& calibracion);

}  // namespace storage
