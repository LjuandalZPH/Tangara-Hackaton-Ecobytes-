# 📄 Documento de Arquitectura y Decisiones Técnicas (ADR)

## Proyecto: EcoBytes

**Equipo de Desarrollo:** Bit&Volt  
**Versión:** 1.0  
**Fecha:** Junio 2026  
**Estado:** Aprobado para Sprint 0  

---

## 1. Introducción y Propósito del Documento

Este documento recopila las decisiones arquitectónicas, la selección del stack tecnológico y la distribución de responsabilidades técnicas para el desarrollo del proyecto **EcoBytes**. El objetivo principal es establecer una línea base técnica sólida que permita al equipo **Bit&Volt Labs** (compuesto por 4 integrantes de Ingeniería de Sistemas y 1 de Ingeniería Electrónica) trabajar de manera coordinada utilizando el marco de trabajo **Scrum**.

El sistema debe resolver tres pilares fundamentales:

1. **Monitoreo e Ingesta:** Captura de datos de sensores (PM2.5, CO2, Humedad) con calibración matemática activa.
2. **Visualización e Interactividad:** Un dashboard multiplataforma (Web/Mobile) con mapas sectorizados y respuestas en tiempo real mediante un Chatbot inteligente.
3. **Concientización:** Un módulo de gamificación (videojuego 2D) interactivo integrado para el ámbito académico.

---

## 2. Vista General de la Arquitectura (Diagrama Conceptual)

El sistema adopta una arquitectura desacoplada basada en microservicios/capas especializadas para optimizar la reutilización de código y garantizar el procesamiento de datos en tiempo real:

[ CAPA DE HARDWARE ]     -> Sensores Físicos (PM2.5 Crudo, CO2, Humedad)
         |
         v (HTTP POST / MQTT)
[ CAPA DE BACKEND ]      -> FastAPI (Python) <--> [ Algoritmo de Calibración ]
         |                                             (NumPy / Scikit-Learn)
         v
[ CAPA DE DATOS ]        -> PostgreSQL + PostGIS (Consultas Espaciales)
         |
         v (REST APIs / WebSockets)
[ CAPA DE CLIENTE ]      -> FLUTTER CORE (Dart)
         |
         +--> Módulo Mapa (flutter_map)
         +--> Módulo Juego (Flame Engine)
         +--> Chatbot Client (Dio / EventStreams) <-- [ LangChain / OpenAI API ]

---

## 3. Desglose Detallado del Stack Tecnológico (Ecosistema Flutter)

### 3.1. Frontend y Mobile (Capa de Cliente Unificada)

Para cumplir con el requisito de ser una plataforma web y móvil sin duplicar esfuerzos de desarrollo, se ha seleccionado **Flutter** como tecnología núcleo.

* **Framework Principal:** Flutter 3.x (Dart). Permite compilar de manera nativa para Web, Android e iOS desde una única base de código.
* **Gestión de Estado:** **Riverpod**. Elegido por su seguridad en tiempo de compilación, facilidad de testeo y excelente manejo de flujos de datos asíncronos (Streams), ideal para los datos de sensores en tiempo real.
* **Visualización de Mapas (Épica 3):** **`flutter_map`**. Librería basada en Leaflet, altamente optimizada para Flutter. Permite renderizar capas de OpenStreetMap/Mapbox y dibujar polígonos geográficos (sectores de la ciudad) mediante archivos GeoJSON.
* **Motor de Videojuegos (Épica 5):** **`Flame Engine`**. Un motor de juego 2D construido directamente sobre Flutter. Permite instanciar el juego como un widget nativo dentro de la aplicación, compartiendo el mismo estado de la app y los datos de los sensores sin puentes complejos.
* **Conectividad de Red:** **`Dio`** para peticiones REST tradicionales (Chatbot, secciones informativas) y **`web_socket_channel`** para la conexión dúplex persistente que pintará los sensores en tiempo real al pasar el mouse (*hover*).

### 3.2. Backend y Procesamiento Numérico

* **Framework de API:** **FastAPI (Python)**. Elegido por su alto rendimiento (basado en Starlette y Pydantic), soporte nativo de WebSockets asíncronos y auto-documentación con Swagger.
* **Procesamiento de Datos y Calibración:** **Pandas, NumPy y Scikit-Learn**. Indispensable para la limpieza y el ajuste matemático de las métricas de los sensores de menor calidad que sufren distorsiones por humedad y entorno.

### 3.3. Base de Datos y Almacenamiento

* **Motor de Base de Datos:** **PostgreSQL 15+**.
* **Extensión Espacial:** **PostGIS**. Crucial para la sectorización de la ciudad. Permite realizar consultas de georreferenciación avanzadas directamente en SQL (ej. verificar si una coordenada de un sensor cae dentro del polígono delimitado de un sector académico).

### 3.4. Inteligencia Artificial (Módulo Chatbot)

* **Orquestador:** **LangChain (Python)** integrado en el backend de FastAPI.
* **Modelo de Lenguaje:** **OpenAI API (GPT-4o-mini)**. Configurado como un agente SQL (SQL Agent / RAG) que traduce las preguntas del usuario en Flutter a queries de base de datos PostGIS, respondiendo con el estado del aire en lenguaje natural.

---

## 4. Justificación de Decisiones Técnicas (¿Por qué este Stack?)

| Desafío del Proyecto | Solución Tecnológica | Justificación Arquitectónica |
| :--- | :--- | :--- |
| **Multiplataforma estricto (Web + Mobile)** | **Flutter (Dart)** | Evita desarrollar la app dos veces. La fidelidad de renderizado por pixel asegura que el mapa y los Tooltips se vean idénticos en computadores y celulares. |
| **Calibración de hardware por entorno** | **Python (FastAPI)** | La ingeniera electrónica requiere librerías científicas para ajustar el PM2.5. Python es el estándar de facto y FastAPI expone estos scripts de forma ultra-rápida. |
| **Mapa sectorizado por polígonos** | **PostGIS + GeoJSON** | En lugar de procesar los límites de los barrios en el celular, PostGIS calcula la pertenencia espacial en microsegundos en el servidor. |
| **Juego educativo integrado** | **Flame Engine** | Desarrollar el juego en una plataforma externa (como Unity o Godot) requeriría construir un puente complejo para pasar los datos de los sensores. Flame corre nativo en Dart. |

---

## 5. Matriz de Roles y Responsabilidades Técnicas

Dado el perfil del equipo (**1 Electrónica, 4 Sistemas**), las responsabilidades del repositorio se dividen de forma simétrica:

* **Ing. Electrónica (Líder de Datos y Hardware):**
  * Definición del protocolo de comunicación de los sensores (IoT).
  * Diseño y codificación del algoritmo de corrección/calibración de PM2.5 en el backend (Python).
  * Validación de la consistencia de datos históricos de CO2 y Humedad.
* **Ing. de Sistemas 1 & 2 (Especialistas Frontend & Multimedia - Flutter):**
  * Diseño de la UI/UX en Flutter Web/Mobile.
  * Implementación de `flutter_map` y renderizado de sectores con GeoJSON.
  * Desarrollo de la lógica del videojuego 2D usando `Flame Engine`.
* **Ing. de Sistemas 3 & 4 (Especialistas Backend, Infraestructura e IA):**
  * Estructuración de la base de datos PostgreSQL + PostGIS.
  * Desarrollo de las rutas REST y WebSockets en FastAPI.
  * Integración de LangChain y OpenAI para el Chatbot conversacional.

---

## 6. Estrategia de Integración del Sprint 0

Para garantizar que el **Sprint 0** deje listos los cimientos técnicos sin generar código basura, el equipo ejecutará las siguientes configuraciones de entornos (Spikes):

1. **Configuración de Repositorio Monorepo:** Creación de una organización en GitHub con dos repositorios principales: `respiraciudad-frontend` (Flutter) y `respiraciudad-backend` (FastAPI/Python).

2. **Estructura del pubspec.yaml Base:** Configuración inicial de dependencias de Flutter para asegurar compatibilidad de versiones:

   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     flutter_riverpod: ^2.5.1
     flutter_map: ^6.1.0
     flame: ^1.18.0
     dio: ^5.4.3
     web_socket_channel: ^2.4.5
    ```

3. **Línea Base del Backend:** Archivo `main.py` inicial en FastAPI con CORS habilitado para permitir peticiones desde el cliente local de Flutter Web y endpoints de prueba para simulación de sensores.

---

## 7. Criterios de Calidad del Código (Definition of Done - DoD)

Para que una Historia de Usuario se considere "Hecha" en Taiga dentro de este stack, debe cumplir con:

* **Frontend:** Código Dart formateado con `flutter format` y sin advertencias críticas del Linter.
* **Backend:** Algoritmo de calibración documentado matemáticamente en la Wiki de Taiga.
* **Base de Datos:** Migraciones de base de datos creadas de forma limpia para PostGIS.
* **Seguridad:** Ninguna API key de OpenAI expuesta en el código (uso estricto de variables de entorno `.env`).
