# 📋 Product Backlog — EcoBytes

**Equipo:** Bit&Volt Labs | **Marco:** Scrum | **Versión:** 1.0 | **Fecha:** Junio 2026

---

## Leyenda

| Campo | Descripción |
| --- | --- |
| **ID** | Identificador único del ítem |
| **Tipo** | `Historia` / `Tarea Técnica` / `Spike` / `Bug` |
| **Épica** | Épica a la que pertenece |
| **Prioridad** | `Crítica` › `Alta` › `Media` › `Baja` |
| **Estimación** | Story Points (escala Fibonacci: 1, 2, 3, 5, 8, 13) |
| **Sprint** | Sprint asignado (0–5) |
| **Estado** | `Por hacer` / `En progreso` / `Hecho` / `Bloqueado` |
| **Dependencias** | IDs de ítems que deben completarse antes |

---

## Épicas

| Código | Nombre |
| --- | --- |
| EPI-01 | Infraestructura y Arquitectura Base |
| EPI-02 | Procesamiento y Calibración de Datos |
| EPI-03 | Dashboard y Mapa Interactivo |
| EPI-04 | Chatbot de Consultas Ambientales |
| EPI-05 | Módulo de Gamificación |
| EPI-06 | Autenticación y Persistencia de Usuario |

---

## Backlog Ordenado por Prioridad

### 🏗️ EPI-01 — Infraestructura y Arquitectura Base

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| SP-01 | Spike | Inicializar monorepo `ecobytes` en GitHub con estructura `frontend/` + `backend/`, ramas `main` y `develop`, `.gitignore` y `README.md`. | Crítica | 2 | 0 | Por hacer | — |
| SP-03 | Spike | Configurar PostgreSQL 15 + extensión PostGIS en entorno de desarrollo local. | Crítica | 2 | 0 | Por hacer | SP-01 |
| SP-04 | Spike | Configurar `backend/.env.example` con plantilla de variables de entorno (BD, JWT, LLM). Verificar que `.env` esté en `.gitignore`. | Crítica | 1 | 0 | Por hacer | SP-01 |
| SP-05 | Spike | Definir `pubspec.yaml` base con dependencias fijadas (`riverpod`, `flutter_map`, `flame`, `dio`, `web_socket_channel`, `flutter_secure_storage`). | Crítica | 1 | 0 | Por hacer | SP-01 |
| SP-06 | Spike | Crear `main.py` en FastAPI con CORS habilitado y endpoints de prueba para simulación de sensores. | Crítica | 2 | 0 | Por hacer | SP-01, SP-03 |
| SP-07 | Spike | Diseñar wireframes del Dashboard, pantalla de autenticación y pantalla del juego (Figma o similar). | Alta | 3 | 0 | Por hacer | — |

---

### 📡 EPI-02 — Procesamiento y Calibración de Datos

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HU-01 | Historia | **Algoritmo de Corrección de PM2.5:** Como analista de datos, quiero que el sistema aplique una fórmula de calibración al dato crudo de PM2.5 antes de almacenarlo, para que las mediciones sean confiables bajo condiciones de alta humedad. | Crítica | 8 | 1 | Por hacer | SP-01, SP-03 |
| T-01.1 | Tarea | Analizar el patrón de error de los sensores y documentar la fórmula matemática de calibración en la Wiki. *(Electrónica)* | Crítica | 3 | 1 | Por hacer | HU-01 |
| T-01.2 | Tarea | Crear endpoint `POST /sensors/data` en FastAPI para recibir datos de sensores en tiempo real. *(Backend)* | Crítica | 2 | 1 | Por hacer | SP-06, T-01.1 |
| T-01.3 | Tarea | Codificar la función de calibración en Python usando NumPy. *(Backend/Datos)* | Crítica | 3 | 1 | Por hacer | T-01.1 |
| T-01.4 | Tarea | Modificar el esquema de PostgreSQL para almacenar `pm25_raw` y `pm25_calibrated`. *(Backend)* | Crítica | 2 | 1 | Por hacer | SP-03, T-01.1 |
| T-01.5 | Tarea | Crear pruebas unitarias con datos simulados para validar la función de calibración. *(Sistemas/QA)* | Alta | 2 | 1 | Por hacer | T-01.3 |

---

### 🗺️ EPI-03 — Dashboard y Mapa Interactivo

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HU-02 | Historia | **Mapa Sectorizado por Zonas:** Como ciudadano o investigador, quiero ver un mapa de la ciudad dividido por sectores con la ubicación de los sensores, para identificar la distribución geográfica de los puntos de monitoreo. | Crítica | 8 | 1 | Por hacer | SP-01, SP-03 |
| T-02.1 | Tarea | Diseñar la interfaz del mapa base y definir la paleta de colores de las zonas. *(Frontend/UX)* | Alta | 2 | 1 | Por hacer | SP-07 |
| T-02.2 | Tarea | Configurar PostGIS y cargar el archivo GeoJSON con los sectores de la ciudad. *(Backend/GIS)* | Crítica | 3 | 1 | Por hacer | SP-03 |
| T-02.3 | Tarea | Integrar `flutter_map` en Flutter y renderizar los polígonos geográficos desde el GeoJSON. *(Frontend)* | Crítica | 3 | 1 | Por hacer | SP-05, T-02.2 |
| T-02.4 | Tarea | Mapear las coordenadas reales de los sensores como marcadores en el mapa. *(Electrónica/Frontend)* | Alta | 2 | 1 | Por hacer | T-02.3, T-01.4 |
| T-02.5 | Tarea | Validar el renderizado responsivo del mapa en pantallas móviles. *(Sistemas)* | Media | 1 | 1 | Por hacer | T-02.3 |
| HU-03 | Historia | **Datos en Tiempo Real (Hover/Tap):** Como usuario del dashboard, quiero pasar el cursor sobre un sector del mapa (o presionar en móvil) para ver un tooltip con los datos de PM2.5, CO2 y humedad en tiempo real. | Crítica | 8 | 2 | Por hacer | HU-02, HU-01 |
| T-03.1 | Tarea | Diseñar el componente UI del Tooltip / Tarjeta emergente en Flutter. *(Frontend/UX)* | Alta | 2 | 2 | Por hacer | SP-07 |
| T-03.2 | Tarea | Programar los eventos de interacción del mapa (`onTap` / `onHover`) usando `flutter_map`. *(Frontend)* | Crítica | 2 | 2 | Por hacer | HU-02 |
| T-03.3 | Tarea | Implementar el endpoint WebSocket en FastAPI que emite promedios por sector en tiempo real. *(Backend)* | Crítica | 3 | 2 | Por hacer | HU-01 |
| T-03.4 | Tarea | Conectar Flutter al WebSocket con `web_socket_channel` e inyectar datos al Tooltip via Riverpod. *(Frontend/Backend)* | Crítica | 3 | 2 | Por hacer | T-03.2, T-03.3 |
| T-03.5 | Tarea | Validar manejo de excepciones visuales para sensores fuera de línea. *(Sistemas/QA)* | Alta | 1 | 2 | Por hacer | T-03.4 |
| HU-04 | Historia | **Sección Educativa:** Como estudiante o usuario curioso, quiero acceder a una sección informativa sobre el impacto del PM2.5 y CO2 en mi salud, presentada de forma didáctica e interactiva. | Media | 5 | 2 | Por hacer | SP-01 |
| T-04.1 | Tarea | Investigar y redactar el contenido académico (definiciones, causas, alertas de salud). *(Todo el equipo)* | Media | 2 | 2 | Por hacer | — |
| T-04.2 | Tarea | Diseñar la estructura visual interactiva de la sección dentro del layout del dashboard Flutter. *(Frontend/UX)* | Media | 2 | 2 | Por hacer | SP-07, T-04.1 |
| T-04.3 | Tarea | Maquetar textos, gráficos explicativos e infografías usando widgets de Flutter. *(Frontend)* | Media | 2 | 2 | Por hacer | T-04.2 |
| T-04.4 | Tarea | Realizar pruebas de legibilidad y adaptabilidad en dispositivos móviles. *(Sistemas)* | Baja | 1 | 2 | Por hacer | T-04.3 |

---

### 🔐 EPI-06 — Autenticación y Persistencia de Usuario

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HU-06 | Historia | **Registro y Login:** Como usuario, quiero crear una cuenta con email y contraseña y hacer login, para que mi puntaje en el juego quede guardado entre sesiones. | Alta | 5 | 3 | Por hacer | SP-01, SP-03 |
| T-06.1 | Tarea | Crear endpoints `POST /auth/register` y `POST /auth/login` en FastAPI con emisión de JWT. *(Backend)* | Alta | 3 | 3 | Por hacer | SP-06, SP-04 |
| T-06.2 | Tarea | Diseñar las pantallas de registro e inicio de sesión en Flutter. *(Frontend/UX)* | Alta | 2 | 3 | Por hacer | SP-07 |
| T-06.3 | Tarea | Implementar gestión del token JWT en Flutter con `flutter_secure_storage`. *(Frontend)* | Alta | 2 | 3 | Por hacer | T-06.1, T-06.2 |
| T-06.4 | Tarea | Proteger los endpoints de score con middleware de autenticación en FastAPI. *(Backend)* | Alta | 1 | 3 | Por hacer | T-06.1 |

---

### 🤖 EPI-04 — Chatbot de Consultas Ambientales

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HU-05 | Historia | **Chatbot Ambiental:** Como usuario, quiero interactuar con un chatbot integrado para preguntarle el estado del aire en zonas específicas en lenguaje natural, sin necesidad de buscar gráficos. | Alta | 13 | 3 | Por hacer | HU-01, HU-02 |
| T-05.1 | Tarea | Configurar LangChain en el backend y conectarlo con la API del LLM seleccionado (OpenAI o Anthropic). *(Backend/IA)* | Alta | 3 | 3 | Por hacer | SP-04 |
| T-05.2 | Tarea | Desarrollar la lógica del SQL Agent para que la IA interactúe con el esquema de PostGIS. *(Backend/IA)* | Alta | 5 | 3 | Por hacer | T-05.1, T-01.4 |
| T-05.3 | Tarea | Crear el endpoint `POST /api/chatbot` en FastAPI con soporte de streaming. *(Backend)* | Alta | 2 | 3 | Por hacer | T-05.1 |
| T-05.4 | Tarea | Diseñar e implementar la burbuja de chat flotante en Flutter usando `Dio` y EventStreams. *(Frontend)* | Alta | 3 | 3 | Por hacer | SP-05, T-05.3 |
| T-05.5 | Tarea | Configurar e iterar el System Prompt para bloquear preguntas fuera del contexto ambiental. *(Sistemas/QA)* | Media | 2 | 3 | Por hacer | T-05.2 |
| T-05.6 | Tarea | Verificar que las API keys del LLM estén aisladas en variables de entorno y documentadas en `.env.example`. *(Backend)* | Alta | 1 | 3 | Por hacer | SP-04 |

---

### 🎮 EPI-05 — Módulo de Gamificación

| ID | Tipo | Descripción | Prioridad | SP | Sprint | Estado | Dependencias |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HU-07 | Historia | **Juego Interactivo Ambiental:** Como estudiante o usuario de la comunidad, quiero participar en un juego integrado a la plataforma para aprender cómo mis decisiones diarias reducen la contaminación, con un puntaje final guardado en mi cuenta. | Alta | 13 | 4 | Por hacer | HU-06 |
| T-07.1 | Tarea | Definir mecánicas y flujo lógico del juego (simulador de decisiones urbanas o quiz contra reloj). *(Todo el equipo)* | Alta | 2 | 4 | Por hacer | SP-07 |
| T-07.2 | Tarea | Configurar Flame Engine dentro del proyecto Flutter como widget nativo en la pestaña del juego. *(Frontend)* | Alta | 2 | 4 | Por hacer | SP-05, T-07.1 |
| T-07.3 | Tarea | Programar la lógica del sistema de puntuación ecológica y el temporizador en Flame. *(Sistemas)* | Alta | 3 | 4 | Por hacer | T-07.2 |
| T-07.4 | Tarea | Diseñar assets visuales: sprites, fondos, pantallas de inicio y fin de juego. *(Frontend/UX)* | Media | 3 | 4 | Por hacer | T-07.1 |
| T-07.5 | Tarea | Crear endpoint `POST /game/score` en FastAPI para persistir el puntaje del usuario autenticado. *(Backend)* | Alta | 2 | 4 | Por hacer | T-06.4 |
| T-07.6 | Tarea | Integrar la llamada al endpoint de score al finalizar la partida desde Flutter. *(Frontend/Backend)* | Alta | 2 | 4 | Por hacer | T-07.3, T-07.5 |

---

## 📊 Resumen por Sprint

| Sprint | Foco | Historias | SP Totales (aprox.) |
| --- | --- | --- | --- |
| Sprint 0 | Infraestructura, entornos y wireframes | SP-01, SP-03 → SP-07 | 10 |
| Sprint 1 | Ingesta de datos y mapa base | HU-01, HU-02 | 16 |
| Sprint 2 | Dashboard en tiempo real y sección educativa | HU-03, HU-04 | 13 |
| Sprint 3 | Autenticación y chatbot de IA | HU-06, HU-05 | 18 |
| Sprint 4 | Módulo de gamificación | HU-07 | 13 |
| Sprint 5 | QA final, despliegue y pitch | Bugs / limpieza | — |
| **Total** | | **7 historias + 7 spikes** | **~71 SP** |

---

## 🔗 Mapa de Dependencias Críticas

```scheme
SP-01 ──► SP-03 ──► T-01.4 ──► HU-02 ──► HU-03
       │                              └──► HU-05
       ├──► SP-04 ──► T-05.6
       │         └──► T-06.1 ──► T-06.3
       │                     └──► T-06.4 ──► T-07.5 ──► T-07.6
       ├──► SP-05 ──► T-02.3 ──► T-02.4
       └──► SP-06 ──► T-01.2
T-01.1 ──► T-01.3 ──► T-01.5
HU-06  ──► HU-07
```
