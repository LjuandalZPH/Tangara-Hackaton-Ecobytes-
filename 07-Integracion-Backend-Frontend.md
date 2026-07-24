# 🔌 Integración Backend ↔ Frontend — Estado real

**Última actualización:** 2026-07-23
**Rama:** `feature/backend-clickhouse`

> Este documento describe **cómo está el sistema hoy**, no cómo debería estar.
> Para el diseño objetivo ver [`03-Arquitectura-Backend.md`](./03-Arquitectura-Backend.md)
> y [`04-Arquitectura-Frontend.md`](./04-Arquitectura-Frontend.md); para lo que
> falta, [`06-Plan-de-Accion.md`](./06-Plan-de-Accion.md).

---

## 1. Resumen en una línea

El mapa de `/mapa` ya consume datos reales: Flutter pide `GET /sectors` cada 45 s
a FastAPI, que agrega lecturas de la red Tángara desde ClickHouse y las agrupa en
las 22 comunas de Cali. **De esas 22, hoy solo 7 tienen sensores.**

```
Sensores Tángara → ClickHouse (tangara_plata) → FastAPI → Flutter web
                                                  │
                          geohashDecode() ────────┤
                          shapely point-in-polygon┤
                          calibración por humedad ┘
```

---

## 2. Cómo levantar el sistema completo

Se necesitan **dos procesos**. El backend no sirve el frontend.

### Backend (puerto 8000)

```bash
cd Backend
cp .env.example .env      # rellenar credenciales CLICKHOUSE_* y CORS_ORIGINS
pip install -r requirements.txt
uvicorn main:app --reload
```

Verificar: `curl http://localhost:8000/health` y Swagger en `http://localhost:8000/docs`.

### Frontend (puerto asignado por Flutter)

```bash
cd Frontend/ecobytes
flutter pub get
flutter run -d chrome
```

Para apuntar a un backend que no sea `localhost:8000`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=https://api.tu-dominio.dev
```

> **Si el navegador no es Chrome** (ej. Brave o Chromium), Flutter no lo encuentra
> solo. Hay que indicárselo: `export CHROME_EXECUTABLE=/usr/bin/brave`.

### ⚠️ El paso que más se olvida: CORS

`flutter run -d chrome` levanta el frontend en un **puerto aleatorio** cada vez.
El backend rechaza cualquier origen que no esté declarado en `CORS_ORIGINS`, así
que hay que fijar el puerto y declararlo:

```bash
# Terminal 1 — backend, declarando el origen del frontend
cd Backend
CORS_ORIGINS=http://localhost:8080 uvicorn main:app --reload

# Terminal 2 — frontend en ese mismo puerto
cd Frontend/ecobytes
flutter run -d chrome --web-port=8080
```

El default de `CORS_ORIGINS` es **vacío a propósito** (fail-closed), como exige el
Definition of Done de `03-Arquitectura-Backend.md` §8. Si se te olvida, el backend
lo avisa al arrancar y el navegador bloqueará las llamadas con un error de CORS en
consola — el mapa quedará en estado de error, no vacío.

---

## 3. Contrato en uso

Los cuatro endpoints documentados en `03-Arquitectura-Backend.md` §3 son los que
existen. Estado de consumo desde el frontend:

| Endpoint | Consumido por | Estado |
| --- | --- | --- |
| `GET /sectors` | `SectorsProvider` (polling 45 s) | ✅ Conectado |
| `GET /sectors/{id}` | `SectorDetailProvider` (bajo demanda) | ✅ Conectado (2026-07-23), pestaña "Resumen" de `sector_detail_page.dart` |
| `GET /risk/{sector}` | `RiskProvider` (bajo demanda) | ✅ Conectado (2026-07-23), pestaña "Historia" de `sector_detail_page.dart` |
| `GET /education` | — | ❌ Sin conectar (la página Aprende usa contenido estático propio) |

### Detalle de `GET /sectors`

```json
{
  "sectores": [
    {
      "id": "comuna-2",
      "nombre": "Comuna 2",
      "geometry": { "type": "MultiPolygon", "coordinates": [[[[-76.55, 3.45], ...]]] },
      "pm25_promedio": 11.27,
      "estado": "verde",
      "ultima_lectura": "2026-07-23T05:49:40",
      "sin_datos_recientes": false
    }
  ]
}
```

Tres detalles que importan al consumirlo:

1. **`geometry` es siempre `MultiPolygon`**, nunca `Polygon`. Las coordenadas van
   en orden GeoJSON `[longitud, latitud]` — **invertido** respecto al `LatLng(lat, lon)`
   de `flutter_map`. `Sector.fromJson` hace la conversión; si alguien parsea esto
   en otro lado, tiene que hacerla también.
2. **`pm25_promedio` y `ultima_lectura` pueden ser `null`, pero `sin_datos_recientes`
   no lo garantiza.** Hay dos casos distintos que producen `estado: "gris"` y
   `sin_datos_recientes: true` (ver `routers/sectors.py:64-92`):
   - **Sin ningún sensor en el polígono** → `pm25_promedio` y `ultima_lectura` son
     `null`. Es el caso de las 15 comunas grises de hoy.
   - **Con sensores, pero la última lectura tiene más de 1 hora** → ambos campos
     traen **valor real** (el último conocido), y aun así el estado es `gris`.

   Es decir: `sin_datos_recientes: true` significa "no confíes en esto como dato
   actual", no "no hay número". Al consumirlo hay que chequear el `null` por
   separado. Es aprovechable para mostrar "última lectura hace 3 h: 12 µg/m³".
3. **`estado` tiene cuatro valores**: `verde`, `amarillo`, `rojo`, `gris`. El `gris`
   no es un color de calidad del aire — significa *dato no confiable ahora*.

---

## 4. Cómo fluye un dato, de punta a punta

1. **ClickHouse.** `services/clickhouse_client.py` consulta
   `tangara_plata.plata_tangara_sensores` (solo lectura) y agrega por sensor la
   última hora: `avg(pm25)`, `avg(co2)`, `avg(hum)`, `max(time)`.
2. **Ubicación.** La columna `geo` es un geohash; se decodifica con
   `geohashDecode()` **dentro de la propia query**, no en Python. Por eso el
   backend no necesita `pygeohash`.
3. **Calibración.** `services/calibration.py` corrige el PM2.5 por humedad. Se
   aplica **una sola vez, dentro de `clickhouse_client.py`**, de modo que el valor
   crudo nunca llega a los routers. Ver el aviso de doble calibración en §7.
4. **Sectorización.** `services/geo.py` carga `data/sectores.geojson` (22 comunas
   oficiales de IDESC) en memoria con `shapely` al arrancar, y resuelve
   point-in-polygon para mapear cada sensor a su comuna. Ese mapeo se cachea ~1 h
   porque los sensores no se mueven.
5. **Estado.** `routers/sectors.py` promedia los sensores de cada comuna y aplica
   los umbrales OMS de `config.py`: `<15` verde, `15–35` amarillo, `>35` rojo. Si
   la última lectura tiene más de 1 hora → `gris` + `sin_datos_recientes: true`.
6. **Caché.** La respuesta completa se cachea 30 s (`services/cache.py`) para
   absorber el polling sin golpear ClickHouse en cada request.
7. **Frontend.** `SectorsProvider` hace `GET /sectors` cada 45 s, `Sector.fromJson`
   convierte el MultiPolygon a `List<List<LatLng>>` y `MapArea` lo pinta con
   `PolygonLayer`, coloreado por `estado`.

---

## 5. Mapa de archivos del frontend

```scheme
lib/
├── core/
│   ├── config/api_config.dart        # baseUrl vía --dart-define
│   ├── data/api_client.dart          # HTTP + ApiException
│   └── utils/geo_utils.dart          # puntoEnPoligono (ray-casting)
├── core/router/app_router.dart        # AppRoutes + GoRouter
├── features/
│   ├── dashboard/
│   │   ├── domain/models/sector.dart # Sector, SectorDetalle (+ historial_24h), EstadoSector
│   │   ├── presentation/providers/sectors_provider.dart
│   │   ├── presentation/providers/sector_detail_provider.dart
│   │   ├── presentation/pages/map_page.dart
│   │   ├── presentation/pages/sector_detail_page.dart  # /mapa/:sectorId — pestañas Resumen/Historia
│   │   └── presentation/widgets/map_area.dart
│   └── risk/
│       ├── domain/models/riesgo.dart
│       └── presentation/providers/risk_provider.dart  # consumido por sector_detail_page.dart, pestaña "Historia"
└── main.dart                         # MultiProvider + GoRouter
```

**Gestión de estado: `Provider`.** `presentation/bloc/` fue eliminado — era código
muerto, sin una sola referencia fuera de su propia carpeta. `flutter_bloc` ya no es
dependencia.

**Detección de tap sobre el mapa.** `flutter_map` no dice qué polígono se tocó, solo
entrega la coordenada. `MapOptions.onTap` resuelve el sector con
`puntoEnPoligono()`, un ray-casting propio en `core/utils/geo_utils.dart` (no hay
librería para eso entre las dependencias).

**Comportamiento del polling.** Los refrescos periódicos **no** ponen el estado en
`cargando`, para que el mapa no parpadee cada 45 s; solo la carga inicial muestra
spinner. Si un refresco falla, se conservan los datos anteriores en vez de vaciar
el mapa.

---

## 6. Qué se verificó, y cómo

Verificado el 2026-07-23 con Flutter 3.44.7 / Dart 3.12.2 contra el ClickHouse real:

| Qué | Resultado |
| --- | --- |
| `flutter analyze` | Sin problemas |
| `flutter build web --release` | Compila |
| Los 4 endpoints contra ClickHouse real | Responden; `/docs` carga (DoD §8) |
| CORS con origen permitido | Devuelve `access-control-allow-origin` |
| CORS preflight `OPTIONS` | 200 con métodos correctos |
| CORS con origen no permitido | **No** devuelve la cabecera (correcto) |
| Parseo del GeoJSON real | 22 sectores, 29 864 vértices, ninguno sin geometría |
| Orden lon/lat | Todas las coordenadas dentro del bounding box de Cali |
| Ray-casting de Dart vs. `shapely` del backend | Coinciden en `comuna-3` y `comuna-17` |
| Manejo de nulos | Los 15 grises traen `pm25`/`ultima_lectura` en `null` — pero ojo, eso es porque hoy ninguno tiene sensores; un gris por lectura vieja **sí** traería valor (ver §3) |

Lo que **no** está verificado: el render visual del mapa en un navegador. Compila y
los datos llegan bien parseados, pero nadie ha visto los polígonos dibujados.

---

## 7. Advertencias vivas

### ⚠️ Posible doble calibración (sin resolver)

Nadie ha confirmado si el pipeline de Tángara ya corrige el PM2.5 por humedad al
construir la capa Plata. Si lo hace, EcoBytes está corrigiendo **dos veces** y
subreportando la contaminación. El efecto medido no es menor:

| Métrica (comuna-17) | Sin calibrar | Calibrado |
| --- | --- | --- |
| PM2.5 actual | 4.35 | 3.41 |
| Promedio anual | 7.98 | 6.76 |
| **Días sobre el límite OMS** | **16** | **8** |

Los días sobre el límite se reducen a la mitad. **Preguntarle al mantenedor del
pipeline antes de que esto llegue a producción.**

### ⚠️ La red cubre 7 de 22 comunas

15 comunas salen en `gris` porque no tienen ningún sensor dentro del polígono. No
es un bug: es la cobertura real de la red Tángara. El mapa las pinta en gris con la
entrada "Sin datos" en la leyenda y muestra la cobertura real calculada de los
datos. **El gris no debe leerse como "aire limpio".**

### ⚠️ `K_FACTOR = 0.24` sin validar

El factor de calibración es empírico y está pendiente de que el equipo de
Electrónica lo valide contra un equipo de referencia (tarea `T-01.1`).

---

## 8. Deuda pendiente

- **`features/landing/` sigue con `MockSensorRepository`** (`hero_section.dart`,
  `dashboard_preview_section.dart`). La landing se conserva permanentemente
  (respaldada por el Figma del equipo, ver `05-Discrepancias.md` §2), así que sus
  números (`StatsBar`: "47 sensores", "2.4M ciudadanos", "22 comunas cubiertas")
  merecen revisión: confirmar si son reales/objetivo o solo ilustrativas del
  diseño — hoy la red solo cubre 7 de 22 comunas.
- **`_SidePanelSection` de `map_page.dart` es el mayor foco de datos inventados
  que quedan.** Todo esto se le muestra al usuario como si fuera real:
  - `map_page.dart:287` — `"Actualizado hace 3 min · Cali, Colombia"` fijo, sin
    relación con `SectorsProvider.ultimaActualizacion`, que sí existe.
  - `map_page.dart:330-334` — PM2.5 `18`, CO2 `420 ppm`, O3 `67 %`. La unidad del
    O3 ni siquiera es plausible (se mide en ppb o µg/m³, no en porcentaje), y el
    backend no expone O3 en absoluto.
  - `map_page.dart:342-344` — nombres de zona inventados ("Buitrera", "Cordoba
    city"), AQIs fijos (18, 108, 52) y un typo bilingüe ("sensor más contaminated").
  - `map_page.dart:359` — texto que insinúa un análisis geográfico ("zonas sur y
    centro") sin ningún cálculo detrás.
  - ✅ `map_page.dart:372` y `386` — corregido (2026-07-23): los botones "Preguntar
    al chatbot" y "Ver detalle del sector" ya no tienen `onPressed: () {}`. El
    primero navega a `/chatbot`; el segundo navega a `sector_detail_page.dart`
    con el sector que el usuario tocó en el mapa (deshabilitado si no hay
    ninguno seleccionado). Ver `06-Plan-de-Accion.md` §3 paso 9.
- **`dashboard_layout.dart` es código muerto** (nadie instancia `DashboardLayout`).
  `control_sidebar.dart` **no** lo es: lo usa `dashboard_preview_section.dart:10,62,78`
  en la landing, alimentado por `MockSensorRepository`. Eliminarlo exige tocar
  también esa sección.
- ✅ **`GET /risk/{sector}` y `GET /sectors/{id}` ya tienen UI (2026-07-23).**
  `sector_detail_page.dart`, ver arriba y `06-Plan-de-Accion.md` §3 paso 9.
- **`GET /education` sin conectar.** La página Aprende sirve contenido estático
  propio en vez del `data/educacion.json` del backend.
- ✅ **`widget_test.dart` corregido (2026-07-23).** El overflow de layout en
  `landing_footer.dart` (ahora en `shared/widgets/`) era real: la condición de
  apilado usaba el breakpoint de *mobile* (`context.isMobile`, <600) en vez del
  de *desktop* (`context.isDesktop`, ≥1200), así que cualquier ancho intermedio
  —incluido el viewport 800×600 por defecto de `flutter_test`— desbordaba. Se
  corrigió la condición a `!context.isDesktop`. Detalle completo en
  `06-Plan-de-Accion.md` §3 paso 3.
- **No hay tests** del parseo, los providers ni los endpoints. La verificación de
  §6 fue manual y puntual, no automatizada.
