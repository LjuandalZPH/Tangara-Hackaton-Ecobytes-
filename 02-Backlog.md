# 📋 Product Backlog — EcoBytes

**Equipo:** Bit&Volt Labs | **Marco:** Scrum

> El acceso a EcoBytes es abierto (sin cuentas de usuario), la app es Flutter compilado solo a web, y el mapa se actualiza por sondeo periódico. El backlog arranca con la limpieza de la base de código Flutter existente antes de conectar datos reales.

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
| EPI-04 | Riesgo por Dirección |
| EPI-05 | Contenido Educativo |

---

## 🧹 EPI-01 — Limpieza y Preparación de la Base de Código

**Objetivo:** dejar el proyecto Flutter existente reducido exactamente al alcance del producto — solo web, solo las tres pantallas que importan — antes de conectar ningún dato real.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-00.1 | Tarea | Eliminar del repositorio las carpetas de plataformas nativas (`android/`, `ios/`, `macos/`, `linux/`, `windows/`) y regenerar el proyecto solo para target web. | Crítica | 1 | 0 | — |
| T-00.2 | Tarea | Actualizar `pubspec.yaml`: agregar `http`, `intl`, `provider`; retirar cualquier dependencia exclusiva de plataformas nativas. | Crítica | 1 | 0 | T-00.1 |
| T-00.3 | Tarea | Correr `flutter clean && flutter pub get` y validar que `flutter run -d chrome` levanta sin errores. | Crítica | 1 | 0 | T-00.2 |
| T-00.4 | Tarea | Eliminar por completo las pantallas de Landing y Chatbot (código, rutas y widgets asociados) — no forman parte del alcance del producto. | Alta | 2 | 0 | T-00.3 |
| T-00.5 | Tarea | Simplificar el router (`app.dart`) a solo tres rutas: mapa, riesgo, aprender. | Alta | 1 | 0 | T-00.4 |
| T-00.6 | Tarea | Crear `core/utils/responsive.dart` con breakpoints centralizados y `shared/widgets/adaptive_scaffold.dart` (navbar inferior en móvil, lateral en desktop), reemplazando cualquier lógica de layout dispersa. | Alta | 3 | 0 | T-00.5 |
| T-00.7 | Tarea | Confirmar con el equipo de backend el contrato final de los cuatro endpoints (`/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education`) y validar CORS contra el dominio de desarrollo. | Crítica | 1 | 0 | — |

**Subtotal Sprint 0: 10 SP**

---

## 🔌 EPI-02 — Capa de Datos e Integración con el Backend

**Objetivo:** construir la capa que conecta la UI existente con datos reales, sin acoplar cada pantalla directamente a llamadas HTTP.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-01.1 | Tarea | Crear `services/api_client.dart`: cliente HTTP centralizado con la URL base configurable (desarrollo/producción) y manejo uniforme de errores de red. | Crítica | 2 | 1 | T-00.7 |
| T-01.2 | Tarea | Crear el modelo `Sector` (`features/map/models/sector.dart`) mapeado a la respuesta de `/sectors`. | Crítica | 1 | 1 | T-01.1 |
| T-01.3 | Tarea | Crear el modelo `RiskProfile` (`features/risk/models/risk_profile.dart`) mapeado a la respuesta de `/risk/{sector}`. | Alta | 1 | 1 | T-01.1 |
| T-01.4 | Tarea | Crear el modelo `EducationContent` (`features/learn/models/education_content.dart`) mapeado a la respuesta de `/education`. | Media | 1 | 1 | T-01.1 |
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
| T-02.3 | Tarea | Simplificar `control_sidebar.dart`: mostrar solo el sector seleccionado y sus valores actuales, retirando cualquier referencia a chat o aprender. | Media | 1 | 1 | T-00.4, T-02.2 |
| T-02.4 | Tarea | Conectar los estados de carga/error de `SectorsProvider` a la UI del mapa (spinner mientras carga, mensaje si falla el fetch). | Alta | 1 | 1 | T-02.1 |

**Subtotal: 7 SP**

### HU-02 — Detalle de sector al tocar
> Como usuario, quiero tocar un sector del mapa para ver sus valores exactos de PM2.5, CO2 y humedad, y no solo el color general.

**Criterios de aceptación:**
- Al tocar un sector aparece una tarjeta con los valores numéricos actuales y la hora de la última lectura.
- Si el sector no tiene datos recientes, la tarjeta lo indica explícitamente en vez de mostrar un valor engañoso.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-03.1 | Tarea | Crear `sector_detail_card.dart`, consumiendo `GET /sectors/{id}` bajo demanda al tocar un sector. | Alta | 2 | 1 | T-02.2 |
| T-03.2 | Tarea | Validar el renderizado de la tarjeta en pantallas móviles usando `responsive.dart`. | Media | 1 | 1 | T-03.1, T-00.6 |

**Subtotal: 3 SP**

---

## 📍 EPI-04 — Riesgo por Dirección

**Objetivo:** construir desde cero la única pantalla que no existe en el código actual — el resto del backlog es integración, esta es la única feature completamente nueva.

### HU-03 — Perfil histórico por dirección
> Como ciudadano, padre o paciente vulnerable, quiero ingresar mi barrio o dirección y ver un perfil histórico de calidad del aire (peor mes, mejor mes, promedio anual, comparación con la norma OMS) para ese punto.

**Criterios de aceptación:**
- El usuario selecciona un barrio/comuna de una lista desplegable (sin necesidad de coordenadas exactas ni geocoding).
- El sistema devuelve: promedio anual, peor mes, mejor mes, y días al año sobre la norma OMS.
- Si el sector no tiene suficiente histórico (`historico_suficiente: false`), se indica claramente en vez de mostrar datos parciales sin contexto.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-04.1 | Tarea | Crear `risk_page.dart` con el layout base de la pantalla (nueva por completo). | Alta | 2 | 2 | T-00.6 |
| T-04.2 | Tarea | Crear `sector_selector.dart`: dropdown poblado con la lista de barrios/comunas disponibles. | Alta | 2 | 2 | T-04.1 |
| T-04.3 | Tarea | Crear `risk_profile_card.dart`: visualización del perfil histórico (promedio anual, peor/mejor mes, días sobre OMS). | Alta | 3 | 2 | T-04.1 |
| T-04.4 | Tarea | Conectar `RiskProvider` a la pantalla: fetch al seleccionar barrio, estados de carga/error, y aviso explícito cuando `historico_suficiente: false`. | Alta | 2 | 2 | T-01.6, T-04.2, T-04.3 |
| T-04.5 | Tarea | Agregar la ruta `/risk` a la navegación (`adaptive_scaffold.dart`). | Media | 1 | 2 | T-04.4, T-00.6 |

**Subtotal: 10 SP**

---

## 📚 EPI-05 — Contenido Educativo

**Objetivo:** conservar la pantalla de "Aprender" ya construida (bien maquetada, actualmente con contenido hardcodeado) y decidir si vale la pena conectarla a un endpoint o dejarla estática.

### HU-04 — Sección educativa
> Como estudiante o usuario curioso, quiero leer una explicación clara de PM2.5 y CO2, sus efectos en la salud y qué puedo hacer, sin tener que navegar múltiples pantallas.

**Criterios de aceptación:**
- El contenido existente (definiciones, rangos de AQI, recomendaciones) se mantiene tal como está maquetado.
- Incluye explícitamente los límites de la OMS para dar contexto a lo que el usuario ve en el mapa y en su perfil de riesgo.

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Dependencias |
| --- | --- | --- | --- | --- | --- | --- |
| T-05.1 | Tarea | Extraer el contenido actualmente hardcodeado en `learn_page.dart` hacia el modelo `EducationContent`, sin cambiar el diseño visual. | Media | 2 | 2 | T-01.4 |
| T-05.2 | Tarea | Decidir y ejecutar: conectar a `GET /education`, o dejar el contenido como asset local estático (ambas opciones son válidas; la segunda ahorra una llamada de red). | Baja | 1 | 2 | T-05.1 |
| T-05.3 | Tarea | Verificar legibilidad y adaptabilidad de la pantalla en móvil con `responsive.dart`. | Baja | 1 | 2 | T-05.1, T-00.6 |

**Subtotal: 4 SP**

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
| Sprint 0 | Limpieza de la base de código Flutter y contrato de API | 10 |
| Sprint 1 | Capa de datos + Mapa por sectores conectado | 19 |
| Sprint 2 | Riesgo por dirección (nueva) + sección educativa | 14 |
| Sprint 3 | QA final y despliegue | 5 |
| **Total** | | **~48 SP** |

---

## 🔗 Dependencias entre épicas

```scheme
EPI-01 (limpieza) ──► EPI-02 (capa de datos) ──► EPI-03 (mapa)
                                              ├──► EPI-04 (riesgo)
                                              └──► EPI-05 (educativo)
```

**EPI-03, EPI-04 y EPI-05 son independientes entre sí** una vez completa la capa de datos (EPI-02) — pueden avanzar en paralelo por distintas personas del equipo sin bloquearse mutuamente. Solo EPI-01 y EPI-02 son estrictamente secuenciales, porque no tiene sentido conectar datos a una base de código que todavía no está limpia.
