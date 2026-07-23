# 🌿 EcoBytes

> *Porque el aire que respiras también merece ser visible.*

EcoBytes es una plataforma de monitoreo de calidad del aire diseñada para hacer que los datos ambientales urbanos sean accesibles, comprensibles y accionables para cualquier persona — no solo para científicos o funcionarios públicos.

Desarrollado por el equipo **Bit&Volt Labs** para la **Tángara Hackathon**.

---

## ¿Qué problema resuelve?

En Cali los datos de calidad del aire existen — la red Tángara lleva años midiendo minuto a minuto en barrios, colegios y comunidades donde ninguna entidad oficial tiene presencia. Pero esa información vive en una base de datos técnica, difícil de interpretar para alguien que no es científico de datos.

EcoBytes cierra esa brecha apoyándose directamente en el pipeline analítico que ya existe detrás de Tángara (InfluxDB → ClickHouse, arquitectura Medallón), en vez de reconstruirlo desde cero.

---

## ¿Qué hace?

### 🗺️ Mapa por sectores

Un mapa de Cali donde cada sector se colorea según su calidad del aire actual — verde, amarillo o rojo — con datos que se refrescan automáticamente. Tocar un sector muestra sus valores exactos de PM2.5, CO2 y humedad.

### 📍 El riesgo en tu dirección

Eliges tu barrio y recibes un perfil histórico de calidad del aire para ese punto: peor mes, mejor mes, promedio anual y cuántos días al año se supera la norma OMS. Pensado para padres, pacientes con condiciones respiratorias y cualquiera que quiera saber qué tan seguro es el aire donde vive.

### 📚 Entiende lo que respiras

Una pantalla clara que explica qué son el PM2.5 y el CO2, cómo afectan la salud y qué acciones concretas se pueden tomar — sin tecnicismos innecesarios.

---

## ¿Para quién es?

- **Ciudadanos** que quieren saber si el aire de su barrio es seguro hoy.
- **Padres, cuidadores y pacientes vulnerables** que necesitan un perfil de riesgo por dirección.
- **Estudiantes** que aprenden sobre medio ambiente de forma clara.
- **Investigadores y periodistas** que necesitan datos locales confiables y accesibles.
- **Ciclistas y deportistas** que planifican sus rutas según la calidad del aire.

---

## Cómo está construido

EcoBytes se diseñó con un principio simple: **velocidad de desarrollo sobre completitud de features.** Eso se traduce en un alcance enfocado en el valor central del producto:

- **Acceso abierto** — cualquier persona entra y usa la app sin crear una cuenta ni iniciar sesión.
- **Geometría simple** — los sectores de Cali son un conjunto fijo de polígonos; se resuelven con un archivo GeoJSON estático más una librería de geometría (`shapely`).
- **Datos frescos por refresco periódico** — el mapa se actualiza automáticamente cada 30-60 segundos.
- **Una sola aplicación Flutter, compilada exclusivamente a web** — accesible desde el navegador tanto en desktop como en teléfono, sin apps que instalar.
- **ClickHouse como única fuente de datos de sensores** — se reutiliza directamente la capa Plata del pipeline Tángara (normalizada, aunque no agregada — la agregación la resuelve el propio backend de EcoBytes), sin duplicar ingesta ni almacenamiento propio.

**Stack:**

| Capa | Tecnología |
| --- | --- |
| Datos históricos | InfluxDB → ClickHouse (pipeline Tángara, arquitectura Medallón) |
| Backend | FastAPI (Python), un único servicio sin estado propio |
| Frontend | Flutter (Dart), compilado solo a web |

Documentación técnica completa:

1. [`01-Arquitectura.md`](./01-Arquitectura.md) — visión general del sistema y decisiones de diseño.
2. [`02-Backlog.md`](./02-Backlog.md) — épicas e historias de usuario.
3. [`03-Arquitectura-Backend.md`](./03-Arquitectura-Backend.md) — diseño detallado del servicio FastAPI.
4. [`04-Arquitectura-Frontend.md`](./04-Arquitectura-Frontend.md) — diseño detallado de la app Flutter.
5. [`05-Discrepancias.md`](./05-Discrepancias.md) — diferencias entre esta arquitectura objetivo y el estado real del código.
6. [`06-Plan-de-Accion.md`](./06-Plan-de-Accion.md) — plan concreto, con dependencias y prioridades, para cerrar esas diferencias.

---

## El equipo

**Bit&Volt Labs** es un equipo de cinco estudiantes de ingeniería de la Universidad del Valle (Cali, Colombia), con perfiles en Ingeniería de Sistemas e Ingeniería Electrónica.

---

*Hecho con 💚 en Cali, Colombia.*
