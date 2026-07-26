#pragma once

// Config de LovyanGFX (v1.x) para el ESP32-2432S028R ("Cheap Yellow
// Display" / CYD): panel ILI9341 240x320 SPI + touch resistivo XPT2046.
//
// Pines verificados contra dos fuentes independientes que coinciden entre
// si (Mischianti, "ESP32-2432S028 high-resolution pinout" y RandomNerdTutorials,
// "LVGL Cheap Yellow Display ESP32-2432S028R"), 2026-07-25 -- no inventados
// de memoria, este board tiene variantes de pinout entre proveedores y no
// vale la pena arriesgarse. Si el hardware real no coincide (pantalla en
// blanco, touch invertido), lo primero a revisar es si esta unidad
// especifica es una variante distinta.
//
// display (bus HSPI / SPI2_HOST):
//   SCLK=14  MOSI=13  MISO=12  DC=2  CS=15  BL(backlight)=21
//   RST: atado a HIGH en la placa, no hay pin de GPIO para resetear el panel.
// touch XPT2046 (bus VSPI / SPI3_HOST, bus propio, no compartido con el
// display):
//   CLK=25  CS=33  MOSI(T_DIN)=32  MISO(T_DOUT)=39  IRQ=36

#include <LovyanGFX.hpp>

// Cambiado de Panel_ILI9341 a Panel_ST7789 (2026-07-25, ver
// 06-Plan-de-Accion.md §5.3): esta unidad concreta tiene DOS puertos USB
// (Micro-USB + USB-C), lo que segun la comunidad identifica la variante
// ST7789 del ESP32-2432S028R (la variante ILI9341 trae un solo
// Micro-USB) -- no hay forma de distinguirlas por software/ID de chip
// facil, el numero de puertos USB es la señal conocida. Estabamos
// mandando comandos de ILI9341 a un controlador ST7789: suficiente
// parecido para dibujar *algo*, pero no para direccionar la pantalla
// completa de forma consistente -- de ahi las franjas de pantalla que
// nunca se actualizaban (visto en fillScreen() ademas de LVGL, en
// cualquier color).
class LGFX : public lgfx::LGFX_Device {
  lgfx::Panel_ST7789 _panel_instance;
  lgfx::Bus_SPI _bus_instance;
  lgfx::Light_PWM _light_instance;
  lgfx::Touch_XPT2046 _touch_instance;

 public:
  LGFX() {
    {
      auto cfg = _bus_instance.config();
      // SPI2_HOST/SPI3_HOST (nombres modernos de spi_host_device_t) en vez
      // de los alias legacy HSPI_HOST/VSPI_HOST -- estos ultimos generan
      // warnings de deprecacion en el core ESP32 v3.3.10 (IDF5).
      cfg.spi_host = SPI2_HOST;
      cfg.spi_mode = 0;
      // Subido de 40MHz a 80MHz (ST7789 tolera/espera mas velocidad que
      // ILI9341, ver comentario de la clase LGFX arriba). Si aparecen
      // "garbage strips" nuevos con pushImage()/pushSprite() a 80MHz
      // (quirk conocido de la comunidad LovyanGFX en block-transfers),
      // volver a 40000000 como primer paso de rollback.
      cfg.freq_write = 80000000;
      cfg.freq_read = 16000000;
      cfg.spi_3wire = true;
      cfg.use_lock = true;
      cfg.dma_channel = SPI_DMA_CH_AUTO;
      cfg.pin_sclk = 14;
      cfg.pin_mosi = 13;
      cfg.pin_miso = 12;
      cfg.pin_dc = 2;
      _bus_instance.config(cfg);
      _panel_instance.setBus(&_bus_instance);
    }

    {
      auto cfg = _panel_instance.config();
      cfg.pin_cs = 15;
      cfg.pin_rst = -1;  // atado a HIGH en la placa, sin control por GPIO.
      cfg.pin_busy = -1;
      // Ancho/alto en orientacion nativa del panel (portrait). La rotacion a
      // landscape (320x240, la que usa el kiosko) se aplica en runtime con
      // setRotation(), no aca.
      cfg.panel_width = 240;
      cfg.panel_height = 320;
      cfg.offset_x = 0;
      cfg.offset_y = 0;
      cfg.offset_rotation = 0;
      cfg.dummy_read_pixel = 8;
      // Subido de 1 a 16 (valor tipico para ST7789 segun la comunidad,
      // ver comentario de la clase LGFX). Solo afecta lecturas (ej.
      // readPixel), no fillScreen/pushImage -- no es la causa de las
      // franjas, pero corresponde ajustarlo junto con el cambio de panel.
      cfg.dummy_read_bits = 16;
      cfg.readable = true;
      // invert/rgb_order: valores tipicos para este clon de ILI9341, pero
      // varia por lote/proveedor -- si los colores salen invertidos o con
      // rojo/azul cambiados en hardware real, este es el primer par de
      // flags a probar en sentido contrario.
      cfg.invert = true;
      cfg.rgb_order = false;
      cfg.dlen_16bit = false;
      cfg.bus_shared = false;  // touch va en un bus SPI propio (VSPI), ver abajo.
      _panel_instance.config(cfg);
    }

    {
      auto cfg = _light_instance.config();
      cfg.pin_bl = 21;
      cfg.invert = false;
      cfg.freq = 12000;
      cfg.pwm_channel = 0;
      _light_instance.config(cfg);
      _panel_instance.setLight(&_light_instance);
    }

    {
      auto cfg = _touch_instance.config();
      cfg.spi_host = SPI3_HOST;
      cfg.freq = 2500000;
      cfg.pin_cs = 33;
      cfg.pin_int = 36;
      cfg.pin_sclk = 25;
      cfg.pin_mosi = 32;
      cfg.pin_miso = 39;
      cfg.bus_shared = false;  // bus VSPI propio, no compartido con el display.
      // Cambiado de 0 a 2 (valor tipico para la variante ST7789 de este
      // board segun la comunidad, ver comentario de la clase LGFX). Si el
      // touch queda desalineado con lo que se ve en pantalla despues del
      // cambio de panel, este es el primer valor a probar entre 0-3 (T-07.3
      // hace la calibracion real de 4 puntos, esto es solo el default).
      cfg.offset_rotation = 2;
      // Rango crudo sin calibrar -- T-07.3 corre la rutina de calibracion de
      // 4 puntos de LovyanGFX y persiste los valores reales en NVS
      // (storage_prefs.h). Estos son solo el default de arranque.
      cfg.x_min = 0;
      cfg.x_max = 4095;
      cfg.y_min = 0;
      cfg.y_max = 4095;
      _touch_instance.config(cfg);
      _panel_instance.setTouch(&_touch_instance);
    }

    setPanel(&_panel_instance);
  }
};
