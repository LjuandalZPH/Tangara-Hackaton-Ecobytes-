# data/sectores.geojson

Las **22 comunas oficiales de Santiago de Cali**, en WGS84 (EPSG:4326).

- **Fuente:** IDESC — Infraestructura de Datos Espaciales de Cali (Alcaldía),
  vía su servicio WFS de GeoServer. Catalogado también en `datos.cali.gov.co`
  como el dataset "Comunas de Santiago de Cali".
- **Descarga:**

  ```
  https://ws-idesc.cali.gov.co/geoserver/dapm/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=dapm:pdt_dpa_comunas&outputFormat=application/json&srsName=EPSG:4326
  ```

  Ojo: el servicio devuelve EPSG:6249 (proyección local en metros) por
  defecto. Hay que pedir explícitamente `srsName=EPSG:4326` para obtener
  lat/lon, o reproyectar a mano después.

- **Esquema:** cada feature es un `MultiPolygon` con las propiedades
  `comcodigo` (`"01"`..`"22"`) y `comnombre` (`"Comuna 01"`..`"Comuna 22"`).
  `services/geo.py` las normaliza al contrato público de la API
  (`id: "comuna-2"`, `nombre: "Comuna 2"`) — ver `docs/backend.md`.

Este archivo va versionado en el repo; cualquier cambio a los polígonos pasa
por PR.

> **Granularidad:** si más adelante se necesita nivel de barrio, la misma capa
> `dapm` de IDESC probablemente expone una capa equivalente de barrios. Hoy el
> alcance es a nivel de comuna.

---

# data/educacion.json

Contenido estático de la sección educativa (contaminantes, umbrales,
recomendaciones). No viene de ninguna fuente externa: se edita a mano en el
repo y lo sirve `routers/education.py` tal cual, sin transformarlo.

**Es la fuente única del contenido educativo del producto.** Lo consumen dos
clientes: la pantalla "Aprende" del frontend (`GET /education`) y el chatbot
(`services/chatbot_context.py`, que lo inyecta en el prompt filtrando `ui` y
`niveles_calidad`, que son solo copy de presentación). Esa es su razón de ser:
antes la pantalla tenía su propio contenido hardcodeado y decía que el CO2
aceptable era `<800 ppm` mientras el chatbot decía 1000 — dos cifras distintas
al mismo usuario.

Dos reglas al editarlo:

1. **Los umbrales de PM2.5 (15 y 35) también están en `config.py`**
   (`PM25_UMBRAL_BUENO`, `PM25_UMBRAL_MODERADO`). Si cambias uno, cambia el
   otro: el contenido educativo no puede enseñar una escala distinta de la que
   el mapa usa para colorear las comunas.
2. **Copia el archivo al asset del frontend** después de cualquier cambio:

   ```bash
   cp Backend/data/educacion.json Frontend/ecobytes/assets/educacion.json
   ```

   Esa copia es el respaldo que usa `/aprende` cuando no hay backend (con un
   aviso visible en pantalla). Es un artefacto, no una segunda fuente editable:
   `diff` entre ambos archivos debe salir vacío.
