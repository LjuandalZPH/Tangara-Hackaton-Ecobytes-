# Firmware ESP32 — kiosko EcoBytes

Ver diseño completo en [`../../docs/firmware-esp32-kiosko.md`](../../docs/firmware-esp32-kiosko.md).
Estado actual:

- **T-07.1 (spike, ✅ hecho):** midió heap real al pedir `GET /sectors`
  filtrando el campo `geometry` con ArduinoJson — el paso bloqueante antes de
  construir cualquier pantalla. Esa lógica de red ya no vive suelta en el
  `.ino`: se migró a `net_client.h`/`.cpp` sin cambiar su comportamiento.
- **T-07.2 (estructura + smoke test, ✅ hecho, 2026-07-25):** estructura de
  archivos del sketch (ver `docs/firmware-esp32-kiosko.md`) + primer
  arranque real de LVGL v8 + LovyanGFX sobre el panel **ST7789**/touch
  XPT2046 (no ILI9341 -- ver nota abajo), confirmado en hardware real:
  WiFi conecta, el fetch de `/sectors` completa (`Sectores parseados: 22`)
  y la Landing se dibuja limpia, sin reinicios. Detalle de los tres
  problemas reales que hubo que resolver (overflow de DRAM estática,
  overflow de flash, panel mal identificado) en `docs/firmware-esp32-kiosko.md`.

  **⚠️ Esta unidad es la variante ST7789 del ESP32-2432S028R, no ILI9341**
  (se distingue por tener puerto USB-C *además* del Micro-USB) --
  `LGFX_Config.h` ya está configurado para `Panel_ST7789`. Si se prueba en
  otra unidad con un solo puerto Micro-USB, es la variante ILI9341 y hay
  que revertir esa configuración (ver el comentario en `LGFX_Config.h`).
- **T-07.3 (portal de configuración táctil, ✅ hecho, 2026-07-25):**
  `ui_config.cpp` pasó de placeholder a un wizard de 3 pasos (elegir red
  WiFi escaneada, password con teclado en pantalla, URL del backend) que
  persiste todo en NVS (`storage_prefs.h`) y prueba la conexión antes de
  reiniciar hacia el flujo normal. Confirmado en hardware real: interfaz
  limpia, calibración de touch precisa, wizard completo (red → password →
  URL → conectar) sin errores ni reinicios. En el camino aparecieron y se
  corrigieron dos bugs reales:
  1. `storage::CalibracionTouch` usaba un array de 4 `uint16_t`, pero
     `LGFX_Device::calibrateTouch()`/`setTouchCalibrate()` de LovyanGFX
     necesitan un array de **8** (verificado contra el código fuente real
     del repo) — con 4, se desbordaba el stack en cada calibración.
  2. Reintentar `WiFi.begin()` después de un timeout fallido crasheaba el
     ESP32 (`wifi:sta is connecting, cannot set config`) — corregido con
     `WiFi.disconnect(true, true)` antes de cada intento en
     `net::conectarWifi` (`net_client.cpp`).

  De paso se encontró que `WiFi.setTxPower(WIFI_POWER_2dBm)` (mitigación
  de brownout) solo se aplicaba después de conectar
  con éxito — ahora también corre antes del escaneo de redes y de cada
  intento de conexión, para cubrir todo el camino donde antes se vio
  inestabilidad. **`secrets.h` volvió a tener un uso real** (parcial): ya
  no es un fallback que salta el wizard entero (eso sigue retirado, ver
  punto 7 de "Cómo correrlo"), pero `ui_config.cpp` sí usa
  `kBackendBaseUrl` para precargar el campo de URL del backend cuando no
  hay nada guardado en NVS todavía, para no tener que tipearla a mano en
  cada prueba.

## Qué mide y por qué

`GET /sectors` incluye `geometry` (el `MultiPolygon` de cada comuna) porque
el frontend Flutter lo necesita para el mapa. El kiosko no dibuja mapas — ese
campo son ~29 864 vértices en total, cientos de KB en JSON de texto, muy por
encima de los 520 KB de SRAM del ESP32-2432S028 (sin PSRAM). El firmware
filtra ese campo con `DeserializationOption::Filter` de ArduinoJson y parsea
en streaming directo desde el `WiFiClient`, sin volcar la respuesta completa
a un `String` primero.

`esp32-kiosko.ino` hace 5 fetches seguidos (con pausa de 5s) e imprime por
Serial, en cada uno: heap libre, mínimo histórico y **el bloque contiguo más
grande disponible** (`ESP.getMaxAllocHeap()`) — este último es el dato que de
verdad importa: `JsonDocument` necesita un bloque contiguo, así que
fragmentación progresiva (más relevante que la caída de heap total) es lo que
rompería el kiosko real tras horas de polling continuo.

## ⚠️ Backend detrás de Tailscale — HTTPS obligatorio, no LAN directa

El backend de este proyecto corre en un servidor accedido por Tailscale, no
en la misma red física que el ESP32. El ESP32 **no puede unirse a la
tailnet** (no existe cliente Tailscale para Arduino/ESP32), así que no sirve
apuntar a la IP `100.x.y.z` del backend — hay que exponerlo con
**[Tailscale Funnel](https://tailscale.com/kb/1223/funnel)**, que publica el
servicio en una URL HTTPS pública normal, alcanzable desde cualquier WiFi con
internet (el ESP32 no necesita estar en la tailnet para esto). Ver
`docs/firmware-esp32-kiosko.md` para el protocolo de comunicación completo.

**En el servidor donde corre `docker compose up` (el backend escucha en el
puerto 8000, ver `docker-compose.yml`):**

1. Confirmar que Tailscale está activo: `tailscale status`.
2. Si es la primera vez que se usa Funnel en esta tailnet, habilitar HTTPS
   para el tailnet desde el [admin console](https://login.tailscale.com/admin/dns)
   → pestaña "DNS" → "Enable HTTPS" (una sola vez, no por dispositivo).
3. Si la cuenta lo requiere, habilitar Funnel para este nodo específico desde
   el admin console (menú "..." del dispositivo → habilitar Funnel/ACL con
   atributo `funnel`). En cuentas personales normalmente ya viene disponible.
4. Levantar Funnel apuntando al puerto del backend:
   ```bash
   sudo tailscale funnel --bg 8000
   ```
   Con `--bg` queda corriendo en segundo plano y sobrevive a cerrar la
   terminal. Confirmar con `tailscale funnel status`, que debe mostrar la URL
   pública asignada (algo como `https://tu-maquina.tu-tailnet.ts.net`).
5. Probar desde cualquier máquina fuera de la tailnet (ej. datos móviles):
   `curl https://tu-maquina.tu-tailnet.ts.net/health` debe responder 200.

Esa URL (sin puerto, Funnel sirve en 443) es la que se completa en el paso
3 (URL del backend) del portal de configuración táctil (`ui_config.cpp`,
T-07.3) la primera vez que arranca el kiosko, y queda persistida en NVS —
ya no es una constante que el `.ino` use directamente en el flujo real,
pero `kBackendBaseUrl` de `secrets.h` sí se usa para precargar ese campo
por defecto (ver nota sobre `secrets.h` más abajo), para no tener que
tipearla a mano en cada prueba. El firmware ya usa
`WiFiClientSecure` con `setInsecure()` para hablar HTTPS con esa URL —
`setInsecure()` salta la validación del certificado, aceptable para este
spike de memoria pero **no** para el firmware final del kiosko (ahí hay
que fijar el cert raíz de Let's Encrypt con `setCACert()`, o el bundle de
CAs con `setCACertBundle()`).

## Cómo correrlo (Arduino IDE 2.x)

1. **Board Manager:** ya tienes el core "esp32 by Espressif Systems"
   instalado (v3.3.10 confirmado). No hace falta reinstalarlo.
2. **Tools → Board:** seleccionar **"ESP32 Dev Module"** — el
   ESP32-2432S028 lleva un ESP32-WROOM-32 clásico. **No** selecciones
   "ESP32P4 Dev Module" ni ninguna variante S2/S3/C3/P4: el core 3.3.10 tiene
   un bug de compilación conocido con los headers de P4
   (`#if CONFIG_IDF_TARGET_ESP32` vacío) que no tiene nada que ver con este
   proyecto — es la placa equivocada, no un bug de nuestro código.
3. **Tools → Partition Scheme:** seleccionar **"Custom"** (no "Default 4MB
   with spiffs", que es lo que trae por defecto). El sketch trae su propio
   `partitions.csv` versionado en esta misma carpeta (una sola partición de
   app de 3 MB, sin slots de OTA que no usamos) — pero el IDE solo lo usa
   *y* saca el techo de tamaño de "Default" (1.25 MB, insuficiente para
   LVGL+LovyanGFX+WiFi+ArduinoJson) si el menú está en "Custom".
4. **Library Manager** (`Sketch → Include Library → Manage Libraries...`),
   instalar:
   - **"ArduinoJson"** de Benoit Blanchon, versión **7.x** (no la 6, la API
     de filtro que usamos es la de v7).
   - **"lvgl"** de kisvegabor, versión **8.x** (no la 9 — todo el firmware
     está escrito contra la API v8, que difiere bastante de v9).
   - **"LovyanGFX"** de lovyan03 (última versión, no hay pin de versión
     específica documentado todavía).
5. **`lv_conf.h` ya está versionado en esta carpeta** — no hay que copiarlo
   a ningún lado ni configurarlo a mano: el build de Arduino agrega la
   carpeta del sketch al include path siempre, así que un `lv_conf.h` acá
   mismo alcanza.
6. Abrir esta carpeta (`Firmware/esp32-kiosko/`) en Arduino IDE — debe abrir
   `esp32-kiosko.ino` como sketch principal, con el resto de los `.h`/`.cpp`
   (`net_client`, `storage_prefs`, `ui_config`, `ui_landing`, `ui_details`,
   `LGFX_Config`) como pestañas adicionales del mismo sketch. Si abriste por
   error otro archivo (ej. un ejemplo de otra librería como TFT_eSPI),
   ciérralo primero: el error `ArduinoJson.h: No such file or directory`
   sobre un archivo con otro nombre es síntoma de que Arduino IDE está
   compilando el sketch equivocado, no de una librería faltante en este
   proyecto.
7. `cp secrets.h.example secrets.h` (misma carpeta que el `.ino`) y completar
   al menos la URL de Funnel (`kBackendBaseUrl`) — **`secrets.h` sigue
   haciendo falta para compilar** (`ui_config.cpp` lo incluye), pero su rol
   cambió desde T-07.3: ya no es un fallback que salta el portal de
   configuración entero (la config de red se sigue cargando a mano desde
   el wizard táctil y persiste en NVS), ahora solo se usa para precargar
   el campo de URL del backend en el paso 3 del wizard, así no hay que
   tipearla en cada prueba — sigue siendo editable en pantalla.
   `kWifiSsid`/`kWifiPassword` de `secrets.h.example` ya no se leen en
   ningún lado (la red se elige del escaneo real), podés dejarlos con
   cualquier valor.
8. Backend corriendo (`docker compose up` en la raíz del repo) y Funnel
   activo en el servidor (ver sección de arriba).
9. Conectar el ESP32-2432S028 por USB, seleccionar el puerto correcto en
   **Tools → Port**, y subir (▶ Upload).
10. Abrir **Tools → Serial Monitor** a 115200 baudios. En el primer
    arranque (sin config guardada en NVS) va a correr la calibración de
    touch de 4 puntos (tocar donde indique la cruz en cada esquina) y
    después mostrar el portal de configuración: elegir la red WiFi,
    escribir el password, escribir la URL de Funnel del backend, y
    "Guardar y conectar" — si conecta, guarda la config y reinicia solo
    hacia el flujo normal (fetch de prueba + Landing).

## Qué hace falta para considerar el spike T-07.1 exitoso (✅ ya corrido)

- Los 5 fetches completan sin `Fallo al parsear JSON` ni reinicio/panic del
  ESP32 (síntoma típico de quedarse sin heap: fallo silencioso o
  `Guru Meditation Error`).
- `bloque_max_contiguo` no cae de forma sostenida fetch tras fetch (una
  caída puntual en el primer fetch es esperable — WiFi/TLS stack
  calentando; lo que importa es que se estabilice, no que seguir bajando).
- `Sectores parseados: 22` en cada fetch (el dataset completo de comunas).

Resultado real y números anotados en `docs/firmware-esp32-kiosko.md` y `docs/backlog.md`.

## Qué hace falta para considerar el smoke test T-07.2 exitoso

- El sketch compila con LVGL v8 + LovyanGFX enlazadas (si falla por
  `lv_conf.h` no encontrado o mal configurado, revisar el paso 4 de arriba).
- La pantalla enciende y muestra el placeholder de `ui_config.cpp` (si no hay
  `secrets.h`/NVS con credenciales válidas) o de `ui_landing.cpp` (si WiFi
  conectó) — con texto legible, sin colores invertidos ni pantalla en blanco
  (si los colores salen mal, revisar `cfg.invert`/`cfg.rgb_order` en
  `LGFX_Config.h`, marcados ahí mismo como el primer sospechoso).
- Tocar la pantalla genera algún efecto visible (LVGL resalta el widget
  tocado por defecto) — confirma que el touch XPT2046 está leyendo, aunque
  todavía sin calibrar (eso es T-07.3).
- El fetch de prueba en `setup()` sigue completando igual que en T-07.1
  (`Sectores parseados: 22` por Serial) — confirma que migrar la lógica de
  red a `net_client.cpp` no le cambió el comportamiento.
- Comparar los `[heap]` impresos contra los de T-07.1: ahora incluyen LVGL +
  LovyanGFX enlazados (~50 KB de buffer adicional presupuestados en
  `docs/firmware-esp32-kiosko.md`) — si el heap libre después de inicializar
  LVGL cae peligrosamente cerca de lo que necesita el fetch, es la señal de
  que el presupuesto de memoria ya no alcanza con la UI real encima.

Este documento no se actualiza solo — una vez corrido en hardware real,
anotar el resultado aquí y en `docs/backlog.md`.
