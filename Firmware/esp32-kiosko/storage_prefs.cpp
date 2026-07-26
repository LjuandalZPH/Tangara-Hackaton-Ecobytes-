#include "storage_prefs.h"

#include <Preferences.h>

namespace storage {

namespace {
constexpr const char* kNamespace = "ecobytes";
}  // namespace

bool hayConfigRedGuardada() {
  Preferences prefs;
  prefs.begin(kNamespace, /*readOnly=*/true);
  const String ssid = prefs.getString("wifi_ssid", "");
  prefs.end();
  return ssid.length() > 0;
}

ConfigRed cargarConfigRed() {
  Preferences prefs;
  prefs.begin(kNamespace, /*readOnly=*/true);
  ConfigRed config;
  config.wifiSsid = prefs.getString("wifi_ssid", "");
  config.wifiPassword = prefs.getString("wifi_pass", "");
  config.backendUrl = prefs.getString("backend_url", "");
  prefs.end();
  return config;
}

void guardarConfigRed(const ConfigRed& config) {
  Preferences prefs;
  prefs.begin(kNamespace, /*readOnly=*/false);
  prefs.putString("wifi_ssid", config.wifiSsid);
  prefs.putString("wifi_pass", config.wifiPassword);
  prefs.putString("backend_url", config.backendUrl);
  prefs.end();
}

CalibracionTouch cargarCalibracionTouch() {
  Preferences prefs;
  prefs.begin(kNamespace, /*readOnly=*/true);
  CalibracionTouch calibracion;
  calibracion.valida = prefs.getBool("touch_ok", false);
  prefs.getBytes("touch_cal", calibracion.parametros, sizeof(calibracion.parametros));
  prefs.end();
  return calibracion;
}

void guardarCalibracionTouch(const CalibracionTouch& calibracion) {
  Preferences prefs;
  prefs.begin(kNamespace, /*readOnly=*/false);
  prefs.putBool("touch_ok", calibracion.valida);
  prefs.putBytes("touch_cal", calibracion.parametros, sizeof(calibracion.parametros));
  prefs.end();
}

}  // namespace storage
