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
  (`id: "comuna-2"`, `nombre: "Comuna 2"`) — ver `03-Arquitectura-Backend.md` §3.

Este archivo va versionado en el repo; cualquier cambio a los polígonos pasa
por PR (`03-Arquitectura-Backend.md` §8).

> **Granularidad:** si más adelante se necesita nivel de barrio, la misma capa
> `dapm` de IDESC probablemente expone una capa equivalente de barrios. Hoy el
> alcance es a nivel de comuna.

---

# data/educacion.json

Contenido estático de la sección educativa (contaminantes, umbrales,
recomendaciones). No viene de ninguna fuente externa: se edita a mano en el
repo y lo sirve `routers/education.py`.
