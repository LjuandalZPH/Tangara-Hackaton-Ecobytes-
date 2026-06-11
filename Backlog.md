# 🌍 Informe de Proyecto: RespiraCiudad

**Evento:** Tangara Hackaton

**Equipo:** Bit&Volt Labs (5 integrantes: 1 Ingeniería Electrónica, 4 Ingeniería de Sistemas)

**Marco de Trabajo:** Scrum (Sprints semanales de 1 semana - Duración total: 6 semanas)

---

## 🚀 1. Descripción General del Proyecto

**EcoBytes** es una solución tecnológica multiplataforma (Web y Móvil) diseñada para el monitoreo interactivo de la calidad del aire (PM2.5, CO2 y Humedad) en tiempo real. Combina la captura de datos desde sensores urbanos, algoritmos de calibración avanzada en Python para corregir desviaciones por factores ambientales, visualización geográfica sectorizada, inteligencia artificial para consultas en lenguaje natural mediante un chatbot y un módulo de gamificación orientado a la educación ambiental.

### 🛠️ Stack Tecnológico Seleccionado

* **Frontend / Mobile:** Next.js (Configurado como PWA) / React Native (Expo) + Tailwind CSS.
* **Mapas y GIS:** Mapbox GL JS o Leaflet.js.
* **Backend & APIs:** FastAPI (Python).
* **Base de Datos:** PostgreSQL + PostGIS (Soporte Geográfico).
* **Inteligencia Artificial:** OpenAI API / Anthropic API + LangChain (SQL Agent / RAG).
* **Módulo de Juego:** Phaser.js.

---

## 🗺️ 2. Estructura de Épicas (Product Backlog)

| Código | Épica | Descripción |
| --- | --- | --- |
| **EPI-01** | Infraestructura y Arquitectura Base | Configuración de servidores, repositorios, despliegue de bases de datos y tuberías de datos iniciales. |
| **EPI-02** | Procesamiento y Calibración de Datos | Ingesta de métricas de hardware y aplicación del algoritmo matemático de corrección de PM2.5. |
| **EPI-03** | Dashboard y Mapa Interactivo | Visualización web/mobile, delimitación espacial de zonas, interacción dinámica (hover) y sección educativa. |
| **EPI-04** | Chatbot de Consultas Ambientales | Orquestación de IA y lenguaje natural conectado a la base de datos de sensores para consultas de usuarios. |
| **EPI-05** | Módulo de Gamificación | Desarrollo e integración del videojuego interactivo orientado a concientizar sobre la calidad del aire. |

---

## 📋 3. Especificación de Historias de Usuario e Historial de Tareas

### 📦 HISTORIA DE USUARIO 1: Algoritmo de Corrección de PM2.5 (Épica: EPI-02)

> **Como** Analista de Datos del proyecto,
> **Quiero** aplicar un factor de ajuste automatizado a los sensores de menor calidad,
> **Para** que las mediciones de PM2.5 mostradas en la web sean confiables a pesar de las condiciones del entorno (ej. alta humedad).

* **Criterios de Aceptación:**
* *Dado* que el sistema recibe datos en tiempo real de un sensor sensible, *cuando* el dato de PM2.5 ingresa, *entonces* se le aplica la fórmula de calibración definida antes de almacenarlo.
* El sistema debe almacenar tanto el dato crudo (`pm25_raw`) como el corregido (`pm25_calibrated`).


* **Tareas Técnicas:**
* [ ] T1.1: Analizar el patrón de error de los sensores y definir la fórmula matemática de calibración. *(Responsable: Electrónica)*
* [ ] T1.2: Crear el endpoint en FastAPI para recibir los datos de los sensores en tiempo real. *(Responsable: Backend)*
* [ ] T1.3: Codificar la función de calibración en Python. *(Responsable: Backend/Datos)*
* [ ] T1.4: Modificar el esquema de la base de datos PostgreSQL para almacenar ambos valores de PM2.5. *(Responsable: Backend)*
* [ ] T1.5: Crear pruebas unitarias con datos simulados para validar la calibración. *(Responsable: Sistemas/QA)*



### 📦 HISTORIA DE USUARIO 2: Mapa Sectorizado por Zonas (Épica: EPI-03)

> **Como** Ciudadano o Investigador,
> **Quiero** ver un mapa de la ciudad dividido por sectores con la ubicación de los sensores,
> **Para** identificar rápidamente la distribución geográfica de los puntos de monitoreo.

* **Criterios de Aceptación:**
* El mapa debe ser multiplataforma (adaptable a web de escritorio y pantallas móviles).
* Los sectores de la ciudad deben estar claramente delimitados mediante polígonos visuales.


* **Tareas Técnicas:**
* [ ] T2.1: Diseñar la interfaz del mapa base y definir la paleta de colores de las zonas. *(Responsable: Frontend/UX)*
* [ ] T2.2: Configurar la extensión PostGIS y cargar el archivo geográfico (GeoJSON) con los sectores. *(Responsable: Backend/GIS)*
* [ ] T2.3: Integrar Mapbox/Leaflet en el frontend y renderizar los polígonos geográficos. *(Responsable: Frontend)*
* [ ] T2.4: Mapear e ingresar las coordenadas reales de los sensores como marcadores físicos en el mapa. *(Responsable: Electrónica/Frontend)*
* [ ] T2.5: Optimizar el renderizado adaptivo (responsive) del mapa para dispositivos móviles. *(Responsable: Sistemas)*



### 📦 HISTORIA DE USUARIO 3: Información en Tiempo Real al Pasar el Mouse (Épica: EPI-03)

> **Como** Usuario del Dashboard,
> **Quiero** pasar el mouse por encima de un sector en el mapa (o presionar en móvil),
> **Para** ver un resumen emergente (Tooltip) con los datos de PM2.5, CO2 y humedad en tiempo real.

* **Criterios de Aceptación:**
* *Dado* que navego en el mapa, *cuando* coloco el cursor sobre una zona, *entonces* aparece un modal flotante sin retraso perceptible con los promedios actuales de las métricas.
* Si los sensores de la zona están desconectados, el tooltip debe indicar explícitamente "Sensor fuera de línea".


* **Tareas Técnicas:**
* [ ] T3.1: Diseñar el componente UI del Tooltip / Tarjeta emergente. *(Responsable: Frontend/UX)*
* [ ] T3.2: Programar los eventos de interacción del mapa (`onMouseEnter` / `onMouseLeave` o tap). *(Responsable: Frontend)*
* [ ] T3.3: Crear una consulta optimizada en FastAPI que devuelva los promedios en tiempo real por sector. *(Responsable: Backend)*
* [ ] T3.4: Conectar el frontend con las respuestas dinámicas del backend para inyectar datos al Tooltip. *(Responsable: Frontend/Backend)*
* [ ] T3.5: Validar el manejo de excepciones visuales para sensores fuera de línea. *(Responsable: Sistemas/QA)*



### 📦 HISTORIA DE USUARIO 4: Sección Educativa e Informativa (Épica: EPI-03)

> **Como** Estudiante o Usuario Curioso,
> **Quiero** acceder a una sección informativa dentro de la plataforma,
> **Para** entender el impacto del PM2.5 y CO2 en mi salud y conocer formas de ayudar a la comunidad.

* **Criterios de Aceptación:**
* La sección debe ser de fácil acceso y presentar el contenido académico de forma ligera, interactiva y didáctica.


* **Tareas Técnicas:**
* [ ] T4.1: Investigar y redactar el contenido académico (definiciones, causas, alertas de salud). *(Responsable: Todo el equipo)*
* [ ] T4.2: Diseñar la estructura visual interactiva de la sección dentro del layout del dashboard. *(Responsable: Frontend/UX)*
* [ ] T4.3: Maquetar los textos, gráficos explicativos e infografías utilizando Tailwind CSS. *(Responsable: Frontend)*
* [ ] T4.4: Realizar pruebas de lectura y adaptabilidad responsiva en celulares. *(Responsable: Sistemas)*



### 📦 HISTORIA DE USUARIO 5: Consulta de Datos mediante Chatbot (Épica: EPI-04)

> **Como** Usuario de la plataforma,
> **Quiero** interactuar con un chatbot integrado,
> **Para** preguntarle directamente el estado del aire en zonas específicas sin necesidad de buscar gráficos.

* **Criterios de Aceptación:**
* *Dado* que interactúo con el chatbot, *cuando* pregunto *"¿Cómo está la calidad del aire en el Sector Centro?"*, *entonces* el chatbot consulta la base de datos y responde de manera amigable con los niveles reales detectados.


* **Tareas Técnicas:**
* [ ] T5.1: Configurar el entorno de LangChain y conectarlo con la API del modelo de lenguaje (LLM). *(Responsable: Backend/IA)*
* [ ] T5.2: Desarrollar la lógica del *SQL Agent* para que la IA entienda e interactúe con el esquema de PostGIS. *(Responsable: Backend/IA)*
* [ ] T5.3: Crear el endpoint `/api/chatbot` en FastAPI para la comunicación con la interfaz de usuario. *(Responsable: Backend)*
* [ ] T5.4: Diseñar e implementar la ventana flotante (burbuja de chat) en el frontend web y móvil. *(Responsable: Frontend)*
* [ ] T5.5: Configurar e iterar el Prompt de Sistema para bloquear preguntas fuera de contexto. *(Responsable: Sistemas/QA)*



### 📦 HISTORIA DE USUARIO 6: Módulo de Juego Interactivo Ambiental (Épica: EPI-05)

> **Como** Estudiante o Usuario de la comunidad,
> **Quiero** participar en un juego interactivo dentro de la plataforma,
> **Para** aprender a través de desafíos lúdicos cómo mis decisiones diarias reducen la contaminación por CO2 y PM2.5.

* **Criterios de Aceptación:**
* El juego debe integrarse estéticamente como una pestaña dedicada del dashboard y contar con estados claros (Inicio, Jugando, Fin de juego).
* Debe entregar una puntuación final (Score) basada en el impacto ecológico de las decisiones del jugador.


* **Tareas Técnicas:**
* [ ] T6.1: Definir las mecánicas y flujo lógico del juego (ej. simulador de decisiones urbanas o quiz contra reloj). *(Responsable: Todo el equipo)*
* [ ] T6.2: Configurar el entorno del lienzo de juego (Phaser.js) dentro de la arquitectura frontend. *(Responsable: Frontend)*
* [ ] T6.3: Programar la lógica del sistema de puntuación ecológica y el temporizador. *(Responsable: Sistemas)*
* [ ] T6.4: Diseñar los elementos gráficos, activos (assets) visuales y las pantallas del juego. *(Responsable: Frontend/UX)*
* [ ] T6.5: Integrar el módulo final del juego dentro del contenedor multiplataforma principal. *(Responsable: Frontend)*



---

## 📅 4. Plan de Sprints (Roadmap de 6 Semanas)

### 🚀 Sprint 0 (Semana 1): Cimientos y Arquitectura Base

* **Meta:** Configurar entornos de desarrollo y formalizar el modelo matemático de calibración.
* **Historias/Entregables:**
* Repositorios de GitHub inicializados. Esquema base de datos espacial configurado.
* Documentación técnica de la fórmula de calibración por hardware en la Wiki de Taiga.
* Diseño de prototipos visuales (Wireframes) del Dashboard y del juego.



### 🗺️ Sprint 1 (Semana 2): Ingesta, Calibración y Mapa Base

* **Meta:** Lograr el flujo real de datos desde los sensores y renderizar el mapa geográfico.
* **Historias/Entregables:**
* **HU 1** (Algoritmo de Corrección de PM2.5) completa al 100%.
* **HU 2** (Mapa Sectorizado por Zonas) completa al 100%.



### 📊 Sprint 2 (Semana 3): Dashboard Interactivo y Sección Educativa

* **Meta:** Entregar valor directo en pantalla al usuario mediante la interacción de datos y teoría.
* **Historias/Entregables:**
* **HU 3** (Información en Tiempo Real al Pasar el Mouse) completa al 100%.
* **HU 4** (Sección Educativa e Informativa) completa al 100%.



### 🤖 Sprint 3 (Semana 4): Integración del Chatbot de IA

* **Meta:** Desplegar el procesamiento de lenguaje natural conectado a las métricas del sistema.
* **Historias/Entregables:**
* **HU 5** (Consulta de Datos mediante Chatbot) completa al 100%.



### 🎮 Sprint 4 (Semana 5): Módulo de Gamificación (El Juego)

* **Meta:** Programar, pulir e integrar el videojuego de concientización dentro de la plataforma.
* **Historias/Entregables:**
* **HU 6** (Módulo de Juego Interactivo Ambiental) completa al 100%.



### 🏁 Sprint 5 (Semana 6): Pruebas Finales, Despliegue y Cierre

* **Meta:** Cero errores críticos de software, optimización móvil y despliegue del MVP para los jurados.
* **Historias/Entregables:**
* Limpieza del panel de incidencias (Issues/Bugs) en Taiga.
* Plataforma desplegada de forma pública (Vercel / Render / Heroku / Servidores universitarios).
* Preparación del Pitch y la Demo académica en vivo.



---

## 🛠️ 5. Gobierno de Código: Estrategia de Ramas en Git

Se implementará un enfoque **Gitflow Simplificado** enfocado en el aislamiento de componentes:

* **`main`:** Producción. Solo contiene software estable, probado y listo para la entrega.
* **`develop`:** Integración. Rama base del Sprint donde confluyen los desarrollos del equipo.
* **Ramas temporales (`feature/`)**: Creadas a partir de `develop` por cada tarea (ej: `feature/data-calibracion-pm25`, `feature/front-mapa-base`).

### 🛡️ Políticas de Calidad

1. **Revisión de Código (Code Review):** Todo Pull Request hacia la rama `develop` requiere la aprobación obligatoria de al menos otro ingeniero de sistemas para validar la calidad del código.
2. **Cierre de Sprint:** Los viernes durante la sesión de Review, si las historias pasan los criterios de aceptación, se realiza un Merge consolidado de `develop` a `main` para actualización del MVP.