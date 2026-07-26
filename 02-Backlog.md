# 📋 Product Backlog — EcoBytes

**Equipo:** Bit&Volt Labs | **Marco:** Scrum

> El acceso a EcoBytes es abierto (sin cuentas de usuario), la app es Flutter con web como target principal de despliegue (carpetas nativas conservadas para builds a demanda), y el mapa se actualiza por sondeo periódico. El backlog arranca con la limpieza de la base de código Flutter existente antes de conectar datos reales — landing y chatbot se conservan (respaldados por el Figma del equipo), ver `04-Arquitectura-Frontend.md`.

---

## Leyenda

| Campo | Descripción |
| --- | --- |
| **ID** | Identificador único del ítem |
| **Tipo** | `Historia` / `Tarea Técnica` / `Spike` |
| **Prioridad** | `Crítica` › `Alta` › `Media` › `Baja` |
| **Estimación** | Story Points (Fibonacci: 1, 2, 3, 5, 8) |
| **Sprint** | Sprint asignado |
| **Dependencias** | IDs de ítems que deben completarse antes |

---

## Épicas

| Código | Nombre |
| --- | --- |
| EPI-01 | Limpieza y Preparación de la Base de Código |
| EPI-02 | Capa de Datos e Integración con el Backend |
| EPI-03 | Mapa por Sectores |
| EPI-04 | Detalle de Sector (Historia) |
| EPI-05 | Contenido Educativo |
| EPI-06 | Kiosko ESP32 (planificado, sin código todavía) |

---

## 🧹 EPI-01 — Limpieza y Preparación de la Base de Código

**Objetivo:** dejar el proyecto Flutter existente ordenado y alineado al [Figma del equipo](https://www.figma.com/design/DdGdcWdvPtcSdZ7mRRzXW9/EcoBytes-%E2%80%94-Landing-Page) — landing, mapa, aprende y chatbot, target principal web — antes de conectar ningún dato real.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-00.1 | ~~Tarea~~ | ~~Eliminar del repositorio las carpetas de plataformas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) y regenerar el proyecto solo para target web.~~ **Obsoleta (2026-07-23):** el equipo decidió conservar las carpetas nativas para poder compilar builds nativos a demanda. Ver `04-Arquitectura-Frontend.md` §1 y `06-Plan-de-Accion.md` §3. | — | — | — | — |
| T-00.2 | Tarea | Actualizar `pubspec.yaml`: agregar `http`, `intl`, `provider`. | Crítica | 1 | 0 | — |
| T-00.3 | Tarea | Correr `flutter clean && flutter pub get` y validar que `flutter run -d chrome` levanta sin errores. | Crítica | 1 | 0 | T-00.2 |
| T-00.4 | ~~Tarea~~ | ~~Eliminar por completo las pantallas de Landing y Chatbot~~ **Obsoleta (2026-07-23):** el Figma del equipo confirma que landing y chatbot sí son parte del producto — no se eliminan. El chatbot queda con su implementación real en pausa (ver `04-Arquitectura-Frontend.md` §8), pero su código y ruta se conservan. | — | — | — | — |
| T-00.5 | Tarea | Resolver la duplicación de arranque (`lib/main.dart` vs `lib/app.dart`) y dejar `AppRoutes`/`GoRouter` en `core/router/app_router.dart` con las cuatro rutas reales: `/`, `/mapa`, `/aprende`, `/chatbot`. | Alta | 1 | 0 | T-00.3 |
| T-00.6 | Tarea | Crear `core/utils/responsive.dart` con breakpoints centralizados y `shared/widgets/adaptive_scaffold.dart` (navbar inferior en móvil, lateral en desktop), reemplazando cualquier lógica de layout dispersa. | Alta | 3 | 0 | T-00.5 |
| T-00.7 | Tarea | Confirmar con el equipo de backend el contrato final de los cuatro endpoints (`/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education`) y validar CORS contra el dominio de desarrollo. | Crítica | 1 | 0 | — |

**Subtotal Sprint 0: 7 SP** (T-00.1 y T-00.4 quedaron obsoletas, ver arriba)

---

## 🔌 EPI-02 — Capa de Datos e Integración con el Backend

**Objetivo:** construir la capa que conecta la UI existente con datos reales, sin acoplar cada pantalla directamente a llamadas HTTP.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-01.1 | Tarea | Crear `services/api_client.dart`: cliente HTTP centralizado con la URL base configurable (desarrollo/producción) y manejo uniforme de errores de red. | Crítica | 2 | 1 | T-00.7 |
| T-01.2 | Tarea | Crear el modelo `Sector` (`features/map/models/sector.dart`) mapeado a la respuesta de `/sectors`. | Crítica | 1 | 1 | T-01.1 |
| T-01.3 | Tarea | Crear el modelo `RiskProfile` (`features/risk/models/risk_profile.dart`) mapeado a la respuesta de `/risk/{sector}`. | Alta | 1 | 1 | T-01.1 |
| T-01.4 | ~~Tarea~~ | ~~Crear el modelo `EducationContent`~~ **Cerrada (2026-07-25):** el modelo existe como `features/learn/domain/models/contenido_educativo.dart` (nombre en español, como el resto del repo). | Media | 1 | 1 | T-01.1 |
| T-01.5 | Tarea | Crear `SectorsProvider` (`ChangeNotifier`) con fetch inicial + polling cada 30-60s, manejando estados de carga/datos/error. | Crítica | 2 | 1 | T-01.2 |
| T-01.6 | Tarea | Crear `RiskProvider` (`ChangeNotifier`) con fetch bajo demanda al seleccionar un sector. | Alta | 2 | 1 | T-01.3 |

**Subtotal: 9 SP**

---

## 🗺️ EPI-03 — Mapa por Sectores

**Objetivo:** conectar el widget de mapa ya existente (`MapArea`, actualmente con datos hardcodeados) a datos reales del backend.

### HU-01 — Mapa coloreado por sector
> Como ciudadano, quiero ver un mapa de Cali donde cada sector está coloreado según su calidad del aire actual, para identificar rápidamente zonas saludables y zonas en alerta.

**Criterios de aceptación:**
- El mapa muestra todos los sectores devueltos por `/sectors`, cada uno coloreado (verde/amarillo/rojo) según el campo `estado` recibido del backend.
- Si un sector llega marcado como `sin_datos_recientes: true`, se muestra en gris con indicación de "sin datos".
- El color se refresca automáticamente cada 30-60 segundos sin recargar la pantalla completa ni perder el zoom/posición del usuario.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-02.1 | Tarea | Actualizar `map_page.dart` para consumir `SectorsProvider` en lugar de los sectores hardcodeados actuales. | Crítica | 2 | 1 | T-01.5 |
| T-02.2 | Tarea | Actualizar `map_area.dart` para recibir los sectores como parámetro y renderizar los polígonos reales del GeoJSON, no los puntos fijos actuales (La Flora, Parque del Amor, etc.). | Crítica | 3 | 1 | T-02.1 |
| T-02.3 | Tarea | Simplificar `control_sidebar.dart`: mostrar solo el sector seleccionado y sus valores actuales. | Media | 1 | 1 | T-02.2 |
| T-02.4 | Tarea | Conectar los estados de carga/error de `SectorsProvider` a la UI del mapa (spinner mientras carga, mensaje si falla el fetch). | Alta | 1 | 1 | T-02.1 |

**Subtotal: 7 SP**

### HU-02 — Detalle de sector al tocar
> Como usuario, quiero tocar un sector del mapa para ver sus valores exactos de PM2.5, CO2 y humedad, y no solo el color general.

**Criterios de aceptación:**
- Al tocar un sector aparece una tarjeta con los valores numéricos actuales y la hora de la última lectura.
- Si el sector no tiene datos recientes, la tarjeta lo indica explícitamente en vez de mostrar un valor engañoso.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-03.1 | Tarea | Crear `sector_detail_page.dart` con su pestaña "Resumen" (indicadores actuales + evolución 24h), consumiendo `GET /sectors/{id}` bajo demanda al tocar "Ver detalle del sector". Ver Figma "Detalle de Producto". | Alta | 2 | 1 | T-02.2 |
| T-03.2 | Tarea | Validar el renderizado de la pestaña "Resumen" en pantallas móviles usando `responsive.dart`. | Media | 1 | 1 | T-03.1, T-00.6 |

**Subtotal: 3 SP**

---

## 📍 EPI-04 — Detalle de Sector (Historia)

**Objetivo (corregido 2026-07-23):** este documento planeaba antes una pantalla `/risk` completamente nueva y separada, con selector de barrio propio. El Figma del equipo ("Detalle de Producto") muestra otra cosa: **no hay pantalla ni selector aparte** — se llega desde el mapa (botón "Ver detalle del sector" o tap en un sector, ver EPI-03/HU-02), y esta épica completa esa misma `sector_detail_page.dart` con la pestaña "Historia" que le falta a la pestaña "Resumen" ya cubierta en EPI-03. Por eso deja de ser independiente de EPI-03 (ver §🔗 Dependencias entre épicas).

**✅ Pestaña "Sensores" construida (2026-07-24) — la decisión de 2026-07-23 de dejarla fuera quedó superada.** Estaba bloqueada porque ningún endpoint exponía sensores individuales por sector; se desbloqueó agregando `GET /sectors/{id}/sensores` (reusa el mapeo sensor→sector y la query de última lectura ya existentes, sin datos inventados — mismo criterio que se mantuvo todo el proyecto). Detalle completo en `05-Discrepancias.md` §2.1 y `06-Plan-de-Accion.md` §3 paso 12.

### HU-03 — Perfil histórico de un sector
> Como ciudadano, padre o paciente vulnerable, quiero ver el perfil histórico de calidad del aire de un sector (peor mes, mejor mes, promedio anual, comparación con la norma OMS), al entrar a su detalle desde el mapa.

**Criterios de aceptación:**
- Se llega a esta vista desde el mapa (botón "Ver detalle del sector" o tap en un sector) — no hay un selector de barrio independiente ni una ruta `/riesgo` nueva.
- La pestaña "Historia" muestra: promedio anual, peor mes, mejor mes, y días al año sobre la norma OMS.
- Si el sector no tiene suficiente histórico (`historico_suficiente: false`), se indica claramente en vez de mostrar datos parciales sin contexto.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-04.1 | Tarea | Agregar la estructura de pestañas (Resumen / Historia) a `sector_detail_page.dart`. | Alta | 2 | 2 | T-03.1 |
| T-04.3 | Tarea | Crear `risk_profile_card.dart` para la pestaña "Historia": promedio anual, peor/mejor mes, días sobre OMS. | Alta | 3 | 2 | T-04.1 |
| T-04.4 | Tarea | Conectar `RiskProvider` a la pestaña "Historia": fetch al entrar al detalle del sector, estados de carga/error, y aviso explícito cuando `historico_suficiente: false`. | Alta | 2 | 2 | T-01.6, T-04.1, T-04.3 |
| T-04.6 | Tarea | ✅ Agregar pestaña "Sensores": endpoint `GET /sectors/{id}/sensores` (backend) + modelo `SensorDeSector`, `SectorDetailProvider` extendido y UI de lista de sensores (frontend). | Media | 2 | — | T-04.1 |

**Subtotal: 9 SP** (T-04.6 se había retirado el 2026-07-23 por falta de endpoint — se reincorporó y cerró el 2026-07-24, ver DECISIÓN arriba)

---

## 📚 EPI-05 — Contenido Educativo

**Objetivo:** conservar la pantalla de "Aprender" ya construida y decidir si vale la pena conectarla a un endpoint o dejarla estática. ✅ **Decidido y ejecutado (2026-07-25): se conectó a `GET /education`.** El contenido hardcodeado desapareció; queda un asset local solo como respaldo offline, copia literal del JSON del backend.

### HU-04 — Sección educativa
> Como estudiante o usuario curioso, quiero leer una explicación clara de PM2.5 y CO2, sus efectos en la salud y qué puedo hacer, sin tener que navegar múltiples pantallas.

**Criterios de aceptación:**
- El contenido existente (definiciones, rangos de AQI, recomendaciones) se mantiene tal como está maquetado.
- Incluye explícitamente los límites de la OMS para dar contexto a lo que el usuario ve en el mapa y en su perfil de riesgo.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-05.1 | ~~Tarea~~ | ~~Extraer el contenido hardcodeado de `learn_page.dart`~~ **Cerrada (2026-07-25):** las tres constantes de tuplas desaparecieron; el contenido vive en `Backend/data/educacion.json`. Diseño de escritorio sin cambios. | Media | 2 | 2 | T-01.4 |
| T-05.2 | ~~Tarea~~ | ~~Decidir y ejecutar: conectar a `GET /education` o dejar asset local~~ **Cerrada (2026-07-25): se conectó al endpoint**, y además se amplió el JSON para que cubra todo el contenido de la pantalla. Motivo: la pantalla decía "<800 ppm" de CO2 y el chatbot (que ya leía el JSON) decía 1000 — dos cifras distintas al mismo usuario. Se conserva un asset de respaldo, pero es una **copia literal** del JSON del backend, no una segunda fuente editable. | Baja | 1 | 2 | T-05.1 |
| T-05.3 | Tarea | Verificar legibilidad y adaptabilidad de la pantalla en móvil con `responsive.dart`. **Parcial (2026-07-25):** `test/learn_page_test.dart` ya comprueba que no hay overflow en 390/900/1400 px, y las columnas se derivan del ancho (`columnasParaAncho`). Falta la revisión visual de legibilidad en dispositivo real. | Baja | 1 | 2 | T-05.1, T-00.6 |
| T-05.4 | Tarea | **Nueva (2026-07-25):** extraer un widget compartido de error/carga a `shared/widgets/`. El bloque "icono `cloud_off` + mensaje + Reintentar" está duplicado **cuatro** veces: `map_page.dart`, `sector_detail_page.dart` (`_ErrorState`), `chatbot_page.dart` (`_MensajeDeError`) y `learn_page.dart` (`_ErrorContenido`). No se hizo junto con T-05.2 para no tocar tres pantallas ya cerradas dentro de una tarea de prioridad Baja. | Baja | 2 | — | — |

**Subtotal: 6 SP** (4 originales + 2 de `T-05.4`, agregada el 2026-07-25)

---

## 📟 EPI-06 — Kiosko ESP32

**Objetivo:** construir el firmware del kiosko físico documentado en [`08-Arquitectura-ESP32.md`](./08-Arquitectura-ESP32.md) — un ESP32-2432S028 (touch) que consume el mismo backend que el frontend Flutter, sin tocar su contrato. Épica nueva, **sin código todavía**; independiente de EPI-01 a EPI-05 (no bloquea ni depende de la limpieza del frontend Flutter), solo requiere que el contrato de los 5 endpoints (EPI-02) esté estable.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-07.1 | Spike | ✅ **Hecho (2026-07-25).** Medir heap libre real (`ESP.getFreeHeap()`) parseando `GET /sectors` con el filtro de deserialización de ArduinoJson (descartando `geometry`). Corrido en hardware real: 5/5 fetches sin fallo de parseo, sin fragmentación (`bloque_max_contiguo` estable). El diseño de la Landing es viable en memoria. Riesgo abierto (no bloqueante para T-07.1, sí para T-07.4): cada fetch tarda ~45-50s por el volumen de datos transferido vía Tailscale Funnel — detalle en `06-Plan-de-Accion.md` §5.1. | Crítica | 2 | — | T-01.5 (contrato `/sectors` estable) |
| T-07.2 | Tarea | ✅ **Hecho (2026-07-25).** Estructura de archivos del sketch en `Firmware/esp32-kiosko/` (Arduino IDE), `LGFX_Config.h`, `net_client`/`storage_prefs` migrados, stubs de `ui_config`/`ui_landing`/`ui_details`. Smoke test corrido en hardware real con éxito: WiFi conecta, fetch de `/sectors` completa (`Sectores parseados: 22`), Landing se dibuja limpia, sin reinicios. Costó tres rondas de fixes no triviales, documentadas en `06-Plan-de-Accion.md` §5.2-5.4: (1) overflow de DRAM estática (buffers de LVGL + `LV_MEM_SIZE`, ambos son `.bss` no heap) — bajados con margen; (2) overflow de flash (esquema de particiones por defecto reserva 2 slots de OTA que no se usan) — `partitions.csv` custom versionado, 3MB de app; (3) el bug real detrás del "ruido" en pantalla: esta unidad es la variante **ST7789** del ESP32-2432S028R (identificable por tener USB-C *y* Micro-USB), y `LGFX_Config.h` tenía `Panel_ILI9341` configurado — corregido junto con `freq_write`/`dummy_read_bits`/`offset_rotation` del touch. Los resets intermitentes que parecían brownout desaparecieron con el panel ya bien identificado. | Alta | 2 | — | — |
| T-07.3 | Tarea | ✅ **Hecho (2026-07-25).** `ui_config.cpp`: wizard de 3 pasos (elegir red WiFi escaneada con `lv_dropdown`, password con `lv_textarea`+`lv_keyboard`, URL del backend precargada desde `secrets.h`), persistido en NVS (`storage_prefs.h`) y con prueba de conexión real antes de reiniciar. `esp32-kiosko.ino` corre la calibración de touch de 4 puntos (`lcd.calibrateTouch()`) antes de cargar cualquier pantalla, una sola vez por dispositivo. Confirmado en hardware real: interfaz limpia, calibración de touch funcionando, wizard completo (red → password → URL → conectar) sin errores. Costó dos rondas de bugs reales, documentados en `06-Plan-de-Accion.md` §5.6: (1) `storage::CalibracionTouch` usaba un array de 4 `uint16_t`, pero LovyanGFX necesita 8 (verificado contra el código fuente real) — con 4 se desbordaba el stack en cada calibración, causando touch errático; (2) reintentar `WiFi.begin()` tras un timeout crasheaba el driver (`wifi:sta is connecting, cannot set config`) — corregido con `WiFi.disconnect(true, true)` antes de cada intento; de paso se encontró que la mitigación de brownout de T-07.2 (`WiFi.setTxPower`) no cubría el escaneo de redes ni los reintentos, solo el fetch final — ahora cubre todo el camino. De paso: `net::conectarWifi` se movió a `net_client.cpp` (reutilizada por el flujo normal y por el wizard) y `net::fetchSectores` ahora toma la URL del backend como parámetro en vez de una constante fija. | Alta | 3 | — | T-07.2 |
| T-07.4 | Tarea | ✅ **Hecho (2026-07-25).** `ui_landing.cpp`: fetch de `/sectors` filtrado (`net::fetchSectores`, T-07.1) al construir la pantalla, agregados de ciudad calculados client-side (PM2.5 promedio de sectores con dato no nulo, conteo por estado verde/amarillo/rojo/gris) en el header, y lista scrolleable (`lv_list`) de los 22 sectores con un badge de color por fila (tocar una fila navega a Details con ese `id`, todavía placeholder). También se cableó el gesto pendiente de T-07.3: mantener presionado el header ~2s vuelve al portal de configuración (`indevDrv.long_press_time = 2000` en `esp32-kiosko.ino`, global para toda la app). El fetch de "smoke test" que vivía en el `.ino` desde T-07.2 se sacó — ahora `ui_landing.cpp` hace el suyo propio, así también se refresca al volver desde Details. Confirmado en hardware real: despliegue de las 22 comunas y agregados de ciudad andando bien. | Alta | 3 | — | T-07.1, T-07.3 |
| T-07.5 | Tarea | ✅ **Hecho (2026-07-25).** `ui_details.cpp`: pestaña Resumen (`lv_tabview`) con `GET /sectors/{id}` (`net::fetchDetalleSector`, nuevo en `net_client`) — PM2.5 con badge de color según `estado`, CO2, humedad, y gráfico de línea (`lv_chart`) de `historial_24h` (hasta 24 puntos, huecos con `LV_CHART_POINT_NONE` si algún punto viene null, nunca inventados); si `historial_24h` viene vacío, texto en vez de gráfico. Confirmado en hardware real. Se agregó además un botón "Volver" (fuera del tabview, visible en ambas pestañas) para regresar a la Landing — faltaba en la primera versión, no había ninguna forma de salir de Details. | Alta | 2 | — | T-07.4 |
| T-07.6 | Tarea | ✅ **Hecho (2026-07-25).** Pestaña Historia del mismo `ui_details.cpp`, con `GET /risk/{sector}` (`net::fetchRiesgoSector`, nuevo en `net_client`): promedio anual, peor mes, mejor mes, días sobre el límite OMS, con aviso si `historico_suficiente: false`. Details queda en 2 pestañas — **sin pestaña Sensores** (decisión 2026-07-24). Confirmado en hardware real junto con T-07.5 (mismo `lv_tabview`). | Media | 1 | — | T-07.4 |
| T-07.8 | Tarea | Sincronización de hora por NTP al conectar WiFi (`configTime()`, zona `America/Bogota`), con fallback a timestamp crudo sin relativizar si falla (decidido 2026-07-24, ver `08-Arquitectura-ESP32.md` §10). | Media | 1 | — | T-07.3 |

**Subtotal: 14 SP** (sin asignar a sprint todavía — pista independiente del roadmap web)

---

## 🚀 Cierre — QA y Despliegue

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-06.1 | Tarea | Probar manualmente en desktop (1920px), móvil (375px) y tablet (768px) — sin scroll horizontal indeseado en ninguna pantalla. | Alta | 2 | 3 | Todo lo anterior |
| T-06.2 | Tarea | Verificar que el polling del mapa se detiene correctamente al cambiar de pantalla (sin fugas de memoria ni requests de fondo innecesarios). | Media | 1 | 3 | T-02.1 |
| T-06.3 | Tarea | `flutter build web --release` y despliegue en el hosting elegido; verificar CORS contra el backend en producción. | Crítica | 2 | 3 | T-06.1 |

**Subtotal: 5 SP**

---

## 📊 Resumen por Sprint

| Sprint | Foco | SP |
| --- | --- | --- |
| Sprint 0 | Limpieza de la base de código Flutter y contrato de API | 7 |
| Sprint 1 | Capa de datos + Mapa por sectores conectado | 19 |
| Sprint 2 | Detalle de sector (historia) + sección educativa | 11 |
| Sprint 3 | QA final y despliegue | 5 |
| **Total** | | **~42 SP** |

---

## 🔗 Dependencias entre épicas

```scheme
EPI-01 (limpieza) ──► EPI-02 (capa de datos) ──► EPI-03 (mapa) ──► EPI-04 (detalle de sector)
                                              └──► EPI-05 (educativo)
```

**EPI-03 y EPI-05 son independientes entre sí** una vez completa la capa de datos (EPI-02) — pueden avanzar en paralelo por distintas personas del equipo sin bloquearse mutuamente. **EPI-04 ya no es independiente** (corregido 2026-07-23): al ser pestañas adicionales de `sector_detail_page.dart`, depende de que EPI-03/HU-02 (`T-03.1`) haya creado esa página primero. Solo EPI-01 y EPI-02 siguen siendo estrictamente secuenciales frente al resto, porque no tiene sentido conectar datos a una base de código que todavía no está limpia.
