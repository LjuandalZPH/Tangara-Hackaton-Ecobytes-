# 🏛️ Arquitectura General — EcoBytes

**Equipo:** Bit&Volt Labs

> El principio central del diseño es la **velocidad de desarrollo por encima de la completitud de features**. EcoBytes es una aplicación web responsive construida en Flutter.

---

## 1. Qué construye EcoBytes

- Un mapa de Cali coloreado por sector según calidad del aire actual.
- Un perfil histórico de calidad del aire por dirección/barrio.
- Una sección educativa breve sobre PM2.5 y CO2.

El alcance está pensado para demostrar el valor central del producto con el menor tiempo de desarrollo posible: acceso abierto sin cuentas de usuario, geometría de sectores resuelta con un archivo estático, datos que se refrescan por sondeo periódico, y una sola interfaz responsive que funciona igual en desktop y en teléfono, sin necesidad de instalar nada.

---

## 2. Diagrama de Arquitectura

```scheme
[ RED TÁNGARA — fuera del alcance de EcoBytes ]
  Sensores ciudadanos → InfluxDB → Pipeline ClickHouse (Bronce/Plata/Oro)
         |
         v  Cliente ClickHouse (solo lectura, capa Gold)
[ BACKEND — FastAPI (Python), un único servicio ]
  ├── GET /sectors                 → estado actual por sector (para colorear el mapa)
  ├── GET /sectors/{id}            → detalle de un sector específico
  ├── GET /risk/{sector}           → perfil histórico por dirección/barrio
  └── GET /education               → contenido educativo estático
         |
         │  point-in-polygon con GeoJSON estático (shapely)
         v
[ FRONTEND — Flutter, compilado exclusivamente a web ]
  ├── Módulo Mapa       → flutter_map + GeoJSON, refresco por polling
  ├── Módulo Riesgo      → selector de barrio → perfil histórico
  └── Módulo Educativo   → contenido estático
```

**Principio de diseño:** un solo servicio backend sin estado propio (stateless), sin base de datos propia más allá del GeoJSON estático que vive en el repositorio. Toda la persistencia real de series de tiempo ya existe en ClickHouse — EcoBytes es una capa de consulta y presentación sobre ella, no un sistema nuevo de almacenamiento. El frontend, por su parte, es una única aplicación web: no hay builds nativos de Android ni iOS.

---

## 3. Decisiones clave y justificación

| Decisión | Por qué esta gana en velocidad |
| --- | --- |
| ClickHouse (capa Gold) como única fuente de datos de sensores | Cero ingesta propia que construir; el pipeline ya calcula, calibra y agrega. |
| GeoJSON estático + `shapely` para sectores | Sin servidor de base de datos adicional, sin migraciones geoespaciales, sin ORM espacial. Un archivo + una librería. |
| Polling REST (`GET /sectors` cada 30-60s) | Sin servidor con estado ni lógica de reconexión que mantener. |
| Acceso abierto, sin cuentas de usuario | Cero superficie de seguridad que mantener; ningún feature del producto la necesita. |
| Un solo servicio FastAPI, sin microservicios | Menos infraestructura que desplegar y menos puntos de falla. |
| Flutter compilado únicamente a web | Reutiliza la base de código Flutter ya construida; un navegador en el teléfono es suficiente, sin builds ni firmas de apps nativas. |
| Gestión de estado simple (`Provider`, no BLoC completo) | Tres pantallas sin lógica de negocio compleja no justifican la ceremonia de eventos/estados por feature; menos código repetitivo para el mismo resultado. |

---

## 4. Stack tecnológico (resumen)

| Capa | Tecnología |
| --- | --- |
| Sensores → almacenamiento histórico | InfluxDB → ClickHouse (arquitectura Medallón, ya existente) |
| Backend | FastAPI (Python), cliente ClickHouse async, `shapely` para geometría |
| Frontend | Flutter (Dart), compilado solo a web: `flutter_map`, `http`, `provider` |

El acceso desde teléfono se resuelve con diseño responsive dentro de la misma app web, no con una app nativa instalada.

---

## 5. Documentos relacionados

- **02-Backlog.md** — Épicas e Historias de Usuario detalladas sobre esta arquitectura.
- **03-Arquitectura-Backend.md** — Diseño detallado de endpoints, consultas ClickHouse y estructura del servicio FastAPI.
- **04-Arquitectura-Frontend.md** — Diseño detallado de módulos Flutter, navegación y manejo de estado.
