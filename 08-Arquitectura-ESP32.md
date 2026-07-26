# 📟 Arquitectura ESP32 — kiosko táctil de calidad del aire

**Última actualización:** 2026-07-24
**Rama:** `develop`
**Estado:** documento de diseño. **No hay firmware escrito todavía** — esto define
qué se va a construir, no describe código existente (a diferencia de
[`07-Integracion-Backend-Frontend.md`](./07-Integracion-Backend-Frontend.md), que
documenta estado real).

> Este componente es nuevo y no está cubierto por `01-Arquitectura.md` ni por
> `04-Arquitectura-Frontend.md` (esos hablan de la app Flutter web). Vive fuera
> del árbol `Frontend/`/`Backend/` — ver §6 para dónde va el código cuando exista.

---

## 1. Resumen en una línea

Un ESP32 con pantalla táctil de 2.8" actúa como cliente HTTP puro del backend
FastAPI ya existente (mismos 5 endpoints que consume el frontend Flutter, sin
tocar el contrato), mostrando un flujo **Landing → Details**: la Landing lista
los 22 sectores con un resumen agregado de ciudad, y al tocar uno se entra al
Details de ese sector (indicadores actuales + gráfico de 24h + resumen de
riesgo anual). **No se muestran datos de sensores individuales** — ver §3.

```
ESP32-2432S028 (touch) ──HTTP/JSON──> FastAPI (mismo backend que Flutter) ──> ClickHouse
      │
      LVGL (UI) + LovyanGFX (driver display+touch) + ArduinoJson (parseo)
```

---

## 2. Hardware

Placa: **ESP32-2432S028R**, conocida en la comunidad maker como *"Cheap Yellow
Display" (CYD)*. Specs relevantes para el diseño:

| Ítem | Valor | Por qué importa |
| --- | --- | --- |
| MCU | ESP32-WROOM-32, dual-core 240 MHz | Suficiente para LVGL + HTTP + JSON sin problema |
| SRAM | 520 KB, **sin PSRAM** | Es la restricción dura de todo el diseño — ver §5 |
| Pantalla | ILI9341 320×240, SPI | `LovyanGFX` tiene panel ya soportado |
| Touch | XPT2046 resistivo, SPI (CS distinto al de la pantalla) | Requiere calibración de 4 puntos, no es capacitivo |
| Flash | 32 Mbit (4 MB) SPI | Suficiente para firmware + LVGL + fuentes; no para guardar históricos propios |
| WiFi | 802.11 b/g/n | Única vía de red — no hay Ethernet |
| Config persistente | NVS (partición flash) vía `Preferences.h` | Guarda WiFi + URL del backend entre reinicios (§4) |

---

## 3. Decisiones de alcance (tomadas 2026-07-24)

| Decisión | Elegido | Alternativa descartada |
| --- | --- | --- |
| Selección de sector | **Selector en pantalla** (Landing lista los 22 sectores) | Sector fijo por dispositivo (kiosko de un solo sector) |
| Config de red | **Portal de configuración táctil** (WiFiManager-style, guarda en NVS) | Credenciales hardcodeadas en firmware |
| Alcance de "Historia" en Details | **Se incluyen los 4 indicadores** (promedio anual, peor mes, mejor mes, días sobre límite OMS) | Omitirlos y dejar solo Resumen |
| Datos de sensores individuales (`GET /sectors/{id}/sensores`) | **No se muestran.** Details queda en 2 pestañas: Resumen + Historia | Pestaña "Sensores" (como en Flutter) con lista por sensor |
| Reloj / hora relativa ("hace X min") | **NTP al conectar WiFi** | Mostrar el timestamp crudo del backend sin relativizar |

---

## 4. Flujo de pantallas

### 4.0 Primer arranque / sin credenciales guardadas

Si `Preferences` no tiene `wifi_ssid` guardado, el dispositivo abre directo la
**pantalla de configuración** en vez de la Landing:

- Escaneo de redes WiFi visibles → `lv_dropdown` o `lv_list` para elegir SSID.
- `lv_textarea` + `lv_keyboard` (componente estándar de LVGL) para el password.
- `lv_textarea` para la URL/IP del backend (ej. `http://192.168.1.50:8000`) —
  **no hay descubrimiento automático**, hay que escribirla; el backend corre en
  la LAN del hackathon, no hay DNS público para esto.
- Botón "Guardar y conectar" → persiste en NVS, reintenta conexión, si falla
  vuelve a mostrar el formulario con el error.
- Acceso posterior a esta pantalla (para cambiar de red): mantener presionado
  el header de la Landing ~2s.

### 4.1 Landing (info general de la ciudad)

- Pide `GET /sectors` una vez al entrar (y al volver desde Details).
- Calcula **client-side** (el backend no expone un endpoint de resumen de
  ciudad): PM2.5 promedio de los sectores con dato no nulo, y conteo de
  sectores por `estado` (verde/amarillo/rojo/gris).
- Cabecera con esos agregados + hora de la última actualización.
- Lista scrolleable (`lv_list`) de los 22 sectores, cada fila con nombre +
  badge de color de `estado`. Tocar una fila navega a Details con ese `id`.

### 4.2 Details (sector seleccionado)

Un solo `lv_tabview` con **2 pestañas** (Resumen + Historia — **sin pestaña
Sensores**, decisión 2026-07-24: el kiosko no presenta datos de sensores
individuales, ver §3), calcadas de las mismas pestañas de
`sector_detail_page.dart` del frontend Flutter:

**Pestaña Resumen** (`GET /sectors/{id}`):
- 3 indicadores: PM2.5 (+ badge de estado), CO2, humedad.
- Gráfico de línea de `historial_24h` con `lv_chart` (tipo `LV_CHART_TYPE_LINE`,
  hasta 24 puntos). Si `historial_24h` viene vacío, texto "Sin historial
  suficiente en las últimas 24h" en vez de gráfico — igual que hace hoy Flutter.
- "Última lectura hace X" calculado con la hora real del dispositivo (NTP, ver
  §10), mismo criterio que usa Flutter con `ultima_lectura`.

**Pestaña Historia** (`GET /risk/{sector}`):
- **No lleva gráfico** — el endpoint no serializa una serie temporal, solo
  agregados (ver §5.2). 4 indicadores de texto: promedio anual, peor mes,
  mejor mes, días sobre el límite OMS del último año. Si
  `historico_suficiente` es `false`, banner de aviso ("todavía no hay
  suficiente histórico para este sector").

> `GET /sectors/{id}/sensores` **no se consume desde el firmware** — es el
> único de los 5 endpoints que el kiosko no usa. Ver §5.3.

---

## 5. Contrato de datos — lo que el firmware puede y no puede mostrar

Verificado contra el código real del backend (`Backend/routers/risk.py`,
`Backend/routers/sectors.py`, `Backend/services/clickhouse_client.py`) el
2026-07-24, no asumido:

### 5.1 `historial_24h` (dentro de `GET /sectors/{id}`) — sí es una serie

Hasta 24 puntos `{"hora": "<ISO datetime>", "pm25_promedio": <float|null>}`,
uno por hora (`HORAS_HISTORIAL_SECTOR = 24` en `config.py`). Puede venir con
menos de 24 puntos, o vacío — **nunca inventar puntos que faltan**, mismo
criterio que ya sigue el frontend Flutter.

### 5.2 `GET /risk/{sector}` — NO es una serie, son 4 agregados

```json
{
  "sector": "comuna-3",
  "promedio_anual": 7.98,
  "peor_mes": {"mes": "2026-01", "promedio": 12.4},
  "mejor_mes": {"mes": "2026-05", "promedio": 5.1},
  "dias_sobre_limite_oms_ultimo_anio": 8,
  "historico_suficiente": true
}
```

Internamente el backend calcula hasta 12 promedios mensuales
(`promedio_mensual()`), pero **nunca los serializa** — solo expone el máximo,
el mínimo y el promedio de esos 12. Por eso un gráfico de barras "por mes" en
el ESP32 **no es viable con el contrato actual**: no hay de dónde sacar los
puntos intermedios sin pedir un cambio de backend (fuera de alcance de este
documento; si se quiere en el futuro, sería un 6º endpoint o extender este,
igual que se hizo con `/sectors/{id}/sensores`).

### 5.3 `GET /sectors/{id}/sensores` — no se usa desde el firmware

El endpoint existe y el backend lo sigue exponiendo para el frontend Flutter
(snapshots puntuales por sensor, sin histórico propio), pero el kiosko **no lo
consume**: decisión 2026-07-24 de no presentar datos de sensores individuales
en esta pantalla (ver §3). Queda documentado acá solo para que quede explícito
que la omisión es deliberada, no un olvido.

---

## 6. Dónde vive el código (cuando exista)

Nueva carpeta a nivel de raíz, hermana de `Backend/` y `Frontend/`:

```
Firmware/esp32-kiosko/
├── platformio.ini
├── src/
│   ├── main.cpp
│   ├── ui/            # pantallas LVGL: config, landing, details
│   ├── net/            # cliente HTTP + parseo JSON
│   └── storage/         # wrapper de Preferences (NVS)
└── lib/                # config de LovyanGFX para ESP32-2432S028
```

No se toca `Backend/` ni `Frontend/ecobytes/` — el firmware es un cliente más
del mismo contrato, igual que ya lo es el frontend Flutter.

---

## 7. Stack técnico propuesto

| Pieza | Elección | Motivo |
| --- | --- | --- |
| Toolchain | PlatformIO | Mejor manejo de dependencias que Arduino IDE para este combo de librerías |
| UI | LVGL v8 | Estándar de facto para touch embebido; `lv_chart`, `lv_tabview`, `lv_keyboard` cubren todo lo de §4 sin widgets custom |
| Driver display+touch | LovyanGFX | Config ya publicada por la comunidad para "ESP32-2432S028"; mejor soportado que TFT_eSPI para este board específico |
| HTTP | `HTTPClient` (core WiFi de Arduino) | No hace falta TLS si el backend corre en HTTP plano dentro de la LAN del hackathon |
| Parseo JSON | `ArduinoJson` v7, **con filtro** | Ver advertencia crítica en §8 |
| Persistencia config | `Preferences.h` (NVS) | Estándar de Arduino-ESP32 para este caso, no hace falta filesystem propio |

---

## 8. ⚠️ Advertencia crítica: `GET /sectors` trae `geometry`, y pesa mucho

`GET /sectors` (el que alimenta la Landing) incluye el campo `geometry`
(`MultiPolygon` con las coordenadas de la comuna) porque el frontend Flutter lo
necesita para pintar el mapa. El ESP32 **no dibuja mapas** — no necesita ese
campo para nada, y es caro: el GeoJSON completo tiene ~29 864 vértices en las
22 comunas (verificado en `07-Integracion-Backend-Frontend.md` §6), lo que en
JSON de texto son cientos de KB — muy por encima de los 520 KB de SRAM
disponibles, y ni de cerca cabe en un buffer estático razonable.

**No es aceptable pedir un 6º endpoint solo para esto** (el contrato de 5
endpoints es deliberado, ver `CLAUDE.md`). La solución vive del lado del
firmware, no del backend:

- Usar el **filtro de deserialización de ArduinoJson**
  (`DeserializationOption::Filter`) para descartar `geometry` mientras se
  parsea, sin nunca materializarlo en memoria.
- Idealmente, parsear **en streaming directo desde el `WiFiClient`**
  (`deserializeJson(doc, client, filter)`) en vez de volcar la respuesta a un
  `String` primero — así el pico de memoria nunca incluye el JSON completo,
  solo los campos filtrados.

Sin este filtro, la Landing probablemente ni siquiera complete el parseo antes
de quedarse sin RAM. Esto hay que probarlo primero contra el backend real,
antes de construir el resto de la UI encima.

---

## 9. Presupuesto de memoria (estimado, a validar en hardware real)

| Uso | Estimado | Nota |
| --- | --- | --- |
| Buffer de LVGL (parcial, no framebuffer completo) | ~50 KB (320×40px ×2 bytes ×2 buffers) | Recomendado por LVGL para boards sin PSRAM |
| `StaticJsonDocument` para `/sectors` (con filtro, sin `geometry`) | A medir — sin filtro es inviable (§8) | Bloqueante: validar antes de seguir |
| `StaticJsonDocument` para `/sectors/{id}` (incluye `historial_24h`, 24 puntos) | ~2-3 KB | Liviano, sin riesgo |
| `StaticJsonDocument` para `/risk/{sector}` | <1 KB | 4 valores + 2 sub-objetos pequeños |
| Stack WiFi/TLS + heap de red | ~40-60 KB mientras hay una request activa | No sostenido, solo durante el fetch |
| Cliente NTP (`sntp`/`configTime`) | Despreciable | No mantiene buffer propio, solo ajusta el reloj interno del ESP32 |

`GET /sectors/{id}/sensores` no aparece en esta tabla — el firmware no lo
consume (ver §3, §5.3).

**Siguiente paso técnico antes de escribir UI:** un spike mínimo que solo haga
`GET /sectors` con el filtro de ArduinoJson y mida heap libre real
(`ESP.getFreeHeap()`) antes/después, para confirmar que §8 es viable en la
práctica y no solo en teoría.

---

## 10. Advertencias vivas / riesgos abiertos

- **CORS no aplica.** El ESP32 no es un browser — no hay preflight ni
  `Access-Control-Allow-Origin` que configurar, a diferencia de lo que exige
  `07-Integracion-Backend-Frontend.md` §2 para Flutter web. Sí hace falta que
  el backend sea alcanzable por IP dentro de la misma LAN (no `localhost`).
- **Reloj de red: NTP al conectar WiFi (decidido 2026-07-24).** Tras conectar
  a la red configurada en el portal (§4.0), el firmware sincroniza la hora vía
  NTP (`configTime()`/`sntp`, servidor por defecto `pool.ntp.org`, con la zona
  horaria de Cali `America/Bogota`, UTC-5 sin horario de verano) antes de
  mostrar Landing. Con eso, "última lectura hace X min" para `ultima_lectura`
  se calcula igual que en Flutter. Si la sincronización falla (sin salida a
  internet, solo LAN local), se degrada mostrando el timestamp crudo del
  backend sin relativizar, en vez de bloquear la pantalla.
- **`historico_suficiente: false` es un caso real y frecuente.** Con solo 7 de
  22 comunas con sensores propios, varios sectores van a mostrar el banner de
  "histórico insuficiente" en la pestaña Historia — no es un bug de la UI.
- **Touch resistivo requiere calibración por unidad.** A diferencia de touch
  capacitivo, cada placa XPT2046 puede tener ligeras variaciones — LovyanGFX
  trae una rutina de calibración de 4 puntos que hay que correr una vez y
  guardar en NVS junto con la config de red.

---

## 11. Pendiente (no empezado)

- [ ] Spike de memoria de §9 (bloqueante para todo lo demás).
- [ ] Estructura de proyecto PlatformIO (`Firmware/esp32-kiosko/`).
- [ ] Pantalla de configuración táctil (WiFi + URL backend + calibración touch).
- [ ] Sincronización NTP tras conectar WiFi, con fallback a timestamp crudo (ver §10).
- [ ] Pantalla Landing (lista de sectores + agregados de ciudad).
- [ ] Pantalla Details (2 pestañas: Resumen + Historia — sin Sensores).
