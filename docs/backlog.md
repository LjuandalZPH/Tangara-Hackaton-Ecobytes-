# Backlog

Estado real de cada funcionalidad, reconstruido a partir del código (no de documentación de proceso). "Implementado" significa que existe código funcional y conectado de punta a punta; "pendiente" son huecos identificables en el propio código — comentarios de riesgo abierto, funcionalidad sin construir, o configuración insegura marcada explícitamente para reemplazar.

## Backend

### Implementado

| Funcionalidad | Detalle |
| --- | --- |
| `GET /sectors` | Estado agregado de las 22 comunas, cacheado 30s |
| `GET /sectors/{id}` | Detalle de una comuna + historial horario de 24h |
| `GET /sectors/{id}/sensores` | Lecturas de sensores individuales dentro de una comuna |
| `GET /risk/{sector}` | Perfil histórico anual (promedio, peor/mejor mes, días sobre límite OMS) |
| `GET /education` | Contenido educativo estático |
| `POST /chatbot` | Asistente conversacional con function calling sobre datos reales |
| `GET /health` | Verificación de disponibilidad del servicio |
| Calibración de PM2.5 por humedad | Aplicada de forma centralizada antes de que cualquier router vea el dato |
| Resolución geográfica sensor → comuna | Point-in-polygon con `shapely` sobre GeoJSON oficial (IDESC), cacheado 1h |
| Caché en memoria con TTL | Absorbe el sondeo del frontend sin golpear ClickHouse en cada petición |
| CORS fail-closed | Sin origen configurado explícitamente, no se permite ninguno |
| Degradación del chatbot ante fallo de ClickHouse | El snapshot se marca como no disponible en vez de romper el endpoint |

### Pendiente

| Ítem | Evidencia en el código |
| --- | --- |
| Validar el factor de calibración de PM2.5 (`K_FACTOR = 0.24`) contra un equipo de referencia | Marcado explícitamente como valor empírico sin confirmar en `services/calibration.py` |
| Confirmar si el pipeline de Tángara ya aplica esta misma corrección de humedad aguas arriba | Riesgo documentado en `services/calibration.py`: si el pipeline ya calibra, EcoBytes estaría corrigiendo dos veces |

## Frontend

### Implementado

| Funcionalidad | Detalle |
| --- | --- |
| Landing (`/`) | Presentación del producto con métricas derivadas en vivo de `SectorsProvider`, sin datos de ejemplo fijos |
| Mapa por comunas (`/mapa`) | 22 polígonos coloreados por estado, sondeo cada 45s, selección de comuna |
| Detalle de comuna (`/mapa/:sectorId`) | Tres pestañas — Resumen (con gráfico de 24h), Historia, Sensores — cada una con su propio estado de carga |
| Contenido educativo (`/aprende`) | Conectado a `GET /education`, con respaldo local para uso sin conexión |
| Chatbot (`/chatbot`) | Conectado a `POST /chatbot`, historial de conversación en el cliente, tres estados de disponibilidad |
| Manejo de errores de red | Mensajes legibles en español, sin perder datos previos ante un fallo transitorio |

### Pendiente

No se encontraron marcadores de trabajo incompleto (`TODO`, `FIXME`), código muerto ni endpoints del backend sin consumidor en el frontend al recorrer `lib/`. Los seis endpoints del backend tienen un cliente real en la aplicación.

## Firmware — kiosko ESP32

### Implementado

| Funcionalidad | Detalle |
| --- | --- |
| Portal de configuración táctil | Selección de red WiFi, contraseña, URL del backend; persistencia en NVS; prueba de conexión antes de guardar |
| Calibración de touch de 4 puntos | Persistida por dispositivo, no se repite en arranques posteriores |
| Pantalla Landing | Lista de 22 comunas con agregados de ciudad calculados en el dispositivo |
| Pantalla Details | Pestañas Resumen (indicadores + gráfico de 24h) e Historia (perfil de riesgo anual) |
| Fetch filtrado de `/sectors` | Streaming con filtro de ArduinoJson para no exceder la SRAM disponible |
| Mitigación de picos de consumo | Potencia de transmisión WiFi reducida durante conexión/reintentos, backlight apagado durante el fetch inicial |

### Pendiente

| Ítem | Evidencia en el código |
| --- | --- |
| Sincronización de hora por NTP | `ui_details.cpp` muestra el timestamp crudo del backend sin relativizar ("hace X minutos"), con un comentario explícito de que la sincronización por NTP todavía no está implementada |
| Validación real de certificado TLS | `net_client.cpp` usa `WiFiClientSecure::setInsecure()` en dos puntos, cada uno con un comentario `TODO` explícito para reemplazarlo por `setCACert()` antes de un despliegue de producción |

### Riesgo conocido, sin resolver

El fetch completo de `/sectors` desde el kiosko tarda varias decenas de segundos, porque el dispositivo debe recibir el payload completo (incluido el campo `geometry`, que descarta recién al parsear) antes de aplicar el filtro. Reducir esto exigiría que el servidor ofreciera una variante de `/sectors` sin `geometry`, lo que ampliaría el contrato de seis endpoints — una decisión de producto pendiente, no solo técnica.

## Infraestructura y configuración

### Implementado

Ambos `secrets.h.example` (firmware) y los `.env.example` de backend y frontend existen y documentan cada variable con su propósito, así que no hay plantillas de configuración faltantes que bloqueen a un tercero replicando el proyecto.

### Pendiente

Ninguna brecha detectada en plantillas de configuración. Los tres archivos de ejemplo (`Backend/.env.example`, `Frontend/ecobytes/.env.example`, `Firmware/esp32-kiosko/secrets.h.example`) están presentes y actualizados respecto al código que configuran.
