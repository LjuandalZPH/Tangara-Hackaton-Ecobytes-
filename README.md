# EcoBytes

Plataforma de monitoreo de calidad del aire para Cali, Colombia. Convierte los datos que la red de sensores ciudadanos Tángara recolecta minuto a minuto en un mapa legible, un perfil histórico por comuna y un asistente que responde preguntas sobre el aire en lenguaje corriente.

Desarrollado por el equipo **Bit&Volt Labs** para la Tángara Hackathon 2026.

## El problema

Cali cuenta con una red de más de veinte sensores ciudadanos de calidad del aire operando desde 2021, con mediciones reales de material particulado fino (PM2.5), CO2 y humedad. Esos datos existen y son técnicamente sólidos, pero viven en una infraestructura pensada para análisis de datos, no para consulta directa: sin agregación por zona de la ciudad, sin clasificación en términos que un no especialista pueda interpretar de un vistazo, y sin un canal para hacer una pregunta en español y recibir una respuesta concreta.

EcoBytes no instala sensores nuevos ni construye un pipeline de datos propio. Toma exactamente lo que la red Tángara ya mide y lo convierte en tres formas de acceso que no exigen entender ClickHouse, SQL, ni qué es un percentil:

- **Un mapa** de las 22 comunas de Cali, coloreado en verde, amarillo, rojo o gris según qué tan segura de respirar es el aire ahora mismo.
- **Un perfil histórico** por comuna: cómo ha estado el aire en el último año, qué tan seguido se superó el límite recomendado por la Organización Mundial de la Salud, y en qué meses fue mejor o peor.
- **Un asistente conversacional** que responde en lenguaje natural — "¿cómo está el aire en la comuna 17 hoy?" — usando siempre las cifras reales del momento, nunca una estimación inventada.

El mismo contenido está disponible también desde un kiosko físico con pantalla táctil, para quienes no tienen o no quieren usar un navegador — pensado como punto de consulta en un espacio público.

## Por qué importa

El material particulado fino (PM2.5) es el contaminante del aire con mayor evidencia de daño a la salud humana: penetra hasta el torrente sanguíneo, agrava enfermedades respiratorias y cardiovasculares, y su exposición prolongada se asocia con menor esperanza de vida. La Organización Mundial de la Salud fija umbrales de referencia — y EcoBytes clasifica cada comuna exactamente contra esos umbrales, sin inventar una escala propia.

Que un dato exista en una base de datos no significa que esté al alcance de quien lo necesita. Un padre decidiendo si su hijo puede jugar afuera, un ciclista planeando su ruta, un docente explicando el tema en clase, o un funcionario público preparando un reporte, no necesitan una consulta SQL: necesitan una respuesta directa, honesta sobre lo que no se sabe (una comuna sin sensores cercanos se muestra explícitamente como "sin datos", nunca como "aire limpio"), y en su idioma. Esa es la brecha que este proyecto cierra: no la de recolectar datos, sino la de hacerlos legibles y accionables.

## Para quién es

- Personas que quieren saber si el aire de su comuna es seguro hoy.
- Padres, cuidadores y personas con condiciones respiratorias que necesitan un perfil de riesgo por zona.
- Docentes y estudiantes que buscan una referencia clara sobre calidad del aire y salud.
- Periodistas e investigadores que necesitan datos locales verificables, con su fuente y su metodología a la vista.
- Funcionarios públicos y organizaciones de la sociedad civil que necesitan comunicar el estado del aire sin depender de un intermediario técnico.

## Cómo está compuesto

| Componente | Qué es | Documentación |
| --- | --- | --- |
| Backend | Servicio FastAPI, sin base de datos propia, que consulta ClickHouse (capa Plata de Tángara) en modo lectura y expone seis endpoints | [`docs/backend.md`](./docs/backend.md) |
| Frontend | Aplicación Flutter compilada a web: landing, mapa, detalle de comuna, contenido educativo y chatbot | [`docs/frontend.md`](./docs/frontend.md) |
| Kiosko ESP32 | Firmware embebido para un dispositivo con pantalla táctil, cliente del mismo backend | [`docs/firmware-esp32-kiosko.md`](./docs/firmware-esp32-kiosko.md) |
| Arquitectura general | Visión de conjunto, diagramas y decisiones de diseño | [`docs/arquitectura.md`](./docs/arquitectura.md) |
| Backlog | Estado real de cada funcionalidad, reconstruido desde el código | [`docs/backlog.md`](./docs/backlog.md) |

## Arquitectura de despliegue, en resumen

El backend es autoalojado y se publica a internet mediante **Tailscale Funnel** (una URL HTTPS pública sin necesidad de abrir puertos ni gestionar certificados manualmente). El frontend se despliega como sitio estático en **Vercel**, compilado apuntando a esa misma URL. El kiosko ESP32 es un tercer cliente HTTP independiente, que consume el backend por la misma vía. Ningún componente mantiene una base de datos propia de sensores: toda la telemetría se lee, en tiempo real y en modo exclusivamente lectura, de la capa Plata del pipeline de Tángara en ClickHouse. Detalle completo en [`docs/arquitectura.md`](./docs/arquitectura.md).

## Cómo instalarlo y correrlo

### Requisitos

- Docker y Docker Compose, para levantar backend y frontend sin instalar Python ni Flutter localmente.
- Credenciales de acceso a ClickHouse (capa `tangara_plata` del pipeline de Tángara).
- Opcional: una API key de OpenAI, solo si se quiere el chatbot activo.

### Configuración mínima

```bash
# Backend
cp Backend/.env.example Backend/.env
# completar CLICKHOUSE_HOST / CLICKHOUSE_USER / CLICKHOUSE_PASSWORD / CORS_ORIGINS

# Frontend
cp Frontend/ecobytes/.env.example Frontend/ecobytes/.env
# completar API_BASE_URL (por defecto http://localhost:8000)
```

Ninguno de los dos `.env` se versiona (están en `.gitignore`); cada variable está documentada con su propósito en `docs/backend.md` y `docs/frontend.md`, sin valores reales.

### Levantar el proyecto

El repositorio incluye tres archivos `docker-compose`, en la raíz:

```bash
# Aplicación completa (backend + frontend)
docker compose --env-file Frontend/ecobytes/.env up

# Solo backend
docker compose -f docker-compose.backend.yml up

# Solo frontend, contra un backend que ya corre en otro lugar
docker compose --env-file Frontend/ecobytes/.env -f docker-compose.frontend.yml up
```

Backend disponible en `http://localhost:8000` (documentación interactiva en `/docs`), frontend en `http://localhost:8080`.

### Kiosko ESP32 (opcional)

Requiere el hardware físico (ESP32-2432S028R con pantalla táctil) y Arduino IDE. Antes de compilar:

```bash
cp Firmware/esp32-kiosko/secrets.h.example Firmware/esp32-kiosko/secrets.h
# completar kBackendBaseUrl con la URL pública del backend
```

Pasos completos de compilación y flasheo en [`docs/firmware-esp32-kiosko.md`](./docs/firmware-esp32-kiosko.md).

## Equipo

**Bit&Volt Labs** — equipo de cinco estudiantes de ingeniería de la Universidad del Valle (Cali, Colombia), con perfiles en Ingeniería de Sistemas e Ingeniería Electrónica. Proyecto presentado en la Tángara Hackathon 2026, "Habla y Crea con los Datos de Calidad del Aire de Cali".
