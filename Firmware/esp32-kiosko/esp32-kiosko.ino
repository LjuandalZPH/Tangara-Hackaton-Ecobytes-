#include <WiFi.h>
#include <lvgl.h>

#include "LGFX_Config.h"
#include "net_client.h"
#include "storage_prefs.h"
#include "ui_config.h"
#include "ui_landing.h"

// T-07.2/T-07.3/T-07.4 (02-Backlog.md EPI-06): estructura del sketch +
// smoke test con LVGL v8 + LovyanGFX (T-07.2, panel ST7789, no ILI9341,
// ver LGFX_Config.h) + portal de configuracion tactil (T-07.3,
// ui_config.cpp) + pantalla Landing con datos reales (T-07.4,
// ui_landing.cpp). Los tres, confirmados en hardware real -- detalle de
// los bugs encontrados y corregidos en 06-Plan-de-Accion.md §5.2-5.6.
//
// Toolchain: Arduino IDE. Placa (Tools > Board): "ESP32 Dev Module".
// Requiere ArduinoJson v7.x, "lvgl" (kisvegabor) v8.x y "LovyanGFX"
// (lovyan03) desde Library Manager.
//
// Flujo real: primero se calibra el touch (una sola vez, persistido en
// NVS -- ver calibrarTouchSiHaceFalta() mas abajo). Despues, sin config de
// red guardada -> portal de configuracion (ui_config.cpp); con config
// guardada -> conectar WiFi con esos datos, si falla volver al portal, si
// conecta mostrar la Landing (ui_landing.cpp), que hace su propio fetch de
// /sectors. secrets.h ya NO es un fallback que salte el portal (a
// diferencia de T-07.2) -- pero ui_config.cpp si lo usa para precargar el
// campo de URL del backend con kBackendBaseUrl, asi no hay que tipearla a
// mano en cada prueba (sigue siendo editable).

namespace {

constexpr uint16_t kPantallaAncho = 320;
constexpr uint16_t kPantallaAlto = 240;
// Buffer parcial (no framebuffer completo), x2 para double buffer.
// Bajado de 40 a 20 lineas (2026-07-25): estos arrays son estaticos
// (.bss), no heap -- a 40 lineas sumaban ~50KB que, junto al pool estatico
// de LVGL (lv_conf.h, LV_MEM_SIZE), desbordaban dram0_0_seg por ~27KB en
// el link (ver detalle en 06-Plan-de-Accion.md). A 20 lineas son ~25KB,
// suficiente margen para las pantallas actuales; el costo es mas
// llamadas a lvglFlushCb por refresco, sin impacto visible con SPI a
// 40MHz en pantallas de datos (no animaciones).
constexpr uint16_t kBufAlturaLineas = 20;

LGFX lcd;
lv_disp_draw_buf_t drawBuf;
lv_color_t bufA[kPantallaAncho * kBufAlturaLineas];
lv_color_t bufB[kPantallaAncho * kBufAlturaLineas];
lv_disp_drv_t dispDrv;
lv_indev_drv_t indevDrv;

void lvglFlushCb(lv_disp_drv_t* drv, const lv_area_t* area, lv_color_t* colorP) {
  const int32_t w = area->x2 - area->x1 + 1;
  const int32_t h = area->y2 - area->y1 + 1;
  lcd.pushImage(area->x1, area->y1, w, h, (lgfx::rgb565_t*)&colorP->full);
  lv_disp_flush_ready(drv);
}

void lvglTouchReadCb(lv_indev_drv_t* drv, lv_indev_data_t* data) {
  int32_t x, y;
  if (lcd.getTouch(&x, &y)) {
    data->state = LV_INDEV_STATE_PRESSED;
    data->point.x = x;
    data->point.y = y;
  } else {
    data->state = LV_INDEV_STATE_RELEASED;
  }
}

void inicializarDisplay() {
  lcd.init();
  lcd.setRotation(1);  // landscape 320x240, ver kPantallaAncho/kPantallaAlto.
  lcd.setBrightness(255);

  lv_init();
  lv_disp_draw_buf_init(&drawBuf, bufA, bufB, kPantallaAncho * kBufAlturaLineas);

  lv_disp_drv_init(&dispDrv);
  dispDrv.hor_res = kPantallaAncho;
  dispDrv.ver_res = kPantallaAlto;
  dispDrv.flush_cb = lvglFlushCb;
  dispDrv.draw_buf = &drawBuf;
  lv_disp_drv_register(&dispDrv);

  lv_indev_drv_init(&indevDrv);
  indevDrv.type = LV_INDEV_TYPE_POINTER;
  indevDrv.read_cb = lvglTouchReadCb;
  // T-07.4: 2000ms para el gesto de "mantener presionado el header de la
  // Landing ~2s" (ui_landing.cpp) -- es una config global del indev, no
  // por widget, asi que aplica a toda la app (no hay otro uso de
  // long-press en el resto de las pantallas todavia).
  indevDrv.long_press_time = 2000;
  lv_indev_drv_register(&indevDrv);
}

// T-07.3: calibracion de touch de 4 puntos (rutina propia de LovyanGFX,
// no un widget LVGL -- por eso corre aca, antes de cargar cualquier
// pantalla, y no dentro de ui_config.cpp). Se corre una sola vez por
// dispositivo; el resultado se persiste en NVS (storage_prefs.h) y en los
// arranques siguientes se restaura sin volver a pedirle al usuario que
// toque los 4 puntos.
//
// CORREGIDO (2026-07-25, ver 06-Plan-de-Accion.md §5.6): la primera
// version de esto usaba un array de 4 elementos -- LGFXBase.hpp confirma
// que calibrateTouch()/setTouchCalibrate() necesitan un array de **8**
// (`memcpy(parameters, orig, sizeof(uint16_t) * 8)`), no 4. Con 4, la
// llamada desbordaba el stack en 8 bytes, corrompiendo memoria vecina --
// causa mas probable del touch erratico visto en hardware real (a veces
// no respondia, a veces en el lugar equivocado, a veces habia que tocar
// varias veces).
void calibrarTouchSiHaceFalta() {
  storage::CalibracionTouch calibracion = storage::cargarCalibracionTouch();
  if (calibracion.valida) {
    lcd.setTouchCalibrate(calibracion.parametros);
    Serial.println("Calibracion de touch restaurada desde NVS.");
    return;
  }

  Serial.println("Sin calibracion de touch guardada -- corriendo calibracion de 4 puntos.");
  lcd.calibrateTouch(calibracion.parametros, TFT_WHITE, TFT_BLACK, 20);
  calibracion.valida = true;
  storage::guardarCalibracionTouch(calibracion);
  Serial.println("Calibracion de touch guardada en NVS.");
}

}  // namespace

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== EcoBytes Kiosko -- T-07.4 (Landing con datos reales) ===");
  net::imprimirHeap("arranque (antes de LVGL)");

  inicializarDisplay();
  net::imprimirHeap("despues de inicializar LVGL+LovyanGFX");

  calibrarTouchSiHaceFalta();

  if (!storage::hayConfigRedGuardada()) {
    Serial.println("Sin config de red en NVS -- mostrando portal de configuracion.");
    lv_scr_load(ui_config::construirPantalla());
    return;
  }

  const storage::ConfigRed config = storage::cargarConfigRed();
  if (!net::conectarWifi(config.wifiSsid.c_str(), config.wifiPassword.c_str())) {
    Serial.println("No se pudo conectar con la config guardada -- mostrando portal de configuracion.");
    lv_scr_load(ui_config::construirPantalla());
    return;
  }
  net::imprimirHeap("despues de conectar WiFi");

  // El fetch de /sectors (T-07.4) ya no vive aca -- ui_landing.cpp lo
  // hace por su cuenta al construir la pantalla (mismo patron que
  // ui_config.cpp con WiFi.scanNetworks()), asi que tambien corre de
  // nuevo cada vez que se vuelve a la Landing desde Details, no solo en
  // este primer arranque.
  lv_scr_load(ui_landing::construirPantalla());
}

void loop() {
  lv_timer_handler();
  delay(5);
}
