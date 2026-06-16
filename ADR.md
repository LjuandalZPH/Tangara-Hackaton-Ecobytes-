# 📄 Documento de Arquitectura y Decisiones Técnicas (ADR)

## Proyecto: EcoBytes

**Equipo de Desarrollo:** Bit&Volt Labs
**Versión:** 1.2
**Fecha:** Junio 2026
**Estado:** Aprobado para Sprint 0

---

## 1. Introducción y Propósito

Este documento recopila las decisiones arquitectónicas y el stack tecnológico seleccionado para el proyecto **EcoBytes**. El objetivo es establecer una línea base sólida que permita al equipo (4 integrantes de Ingeniería de Sistemas + 1 de Ingeniería Electrónica) trabajar de manera coordinada bajo el marco **Scrum**. La asignación de tareas por persona se gestiona directamente en Taiga.

El sistema resuelve tres pilares fundamentales:

1. **Monitoreo e Ingesta:** Captura de datos de sensores (PM2.5, CO2, Humedad) con calibración matemática activa.
2. **Visualización e Interactividad:** Dashboard multiplataforma con mapas sectorizados, datos en tiempo real vía WebSocket y chatbot inteligente.
3. **Concientización:** Módulo de gamificación (videojuego 2D) con persistencia de puntaje por usuario autenticado.

---

## 2. Vista General de la Arquitectura

El sistema adopta una arquitectura desacoplada en capas especializadas:

```scheme
[ CAPA DE HARDWARE ]
  Sensores Físicos (PM2.5 crudo, CO2, Humedad)
         |
         v  HTTP POST / MQTT
[ CAPA DE BACKEND ]
  FastAPI (Python)
  ├── Algoritmo de Calibración (NumPy / Scikit-Learn)
  ├── REST Endpoints (Dio desde Flutter)
  ├── WebSocket Server (web_socket_channel desde Flutter)
  ├── Auth JWT (registro / login)
  └── LangChain SQL Agent <──> LLM API (OpenAI / Anthropic)
         |
         v
[ CAPA DE DATOS ]
  PostgreSQL 15+ + PostGIS
  (Consultas espaciales, historial de sensores, scores de usuarios)
         |
         v  REST / WebSocket / EventStream
[ CAPA DE CLIENTE ]
  Flutter 3.x (Dart) — Web + Android + iOS desde una sola base de código
  ├── Módulo Mapa        → flutter_map + GeoJSON
  ├── Módulo Tiempo Real → web_socket_channel + Riverpod
  ├── Módulo Chatbot     → Dio + EventStreams
  ├── Módulo Juego       → Flame Engine (widget nativo)
  └── Módulo Auth        → flutter_secure_storage + JWT
```

---

## 3. Stack Tecnológico Detallado

### 3.1. Frontend y Mobile — Flutter (Capa de Cliente Unificada)

Para cumplir con el requisito multiplataforma sin duplicar esfuerzos, se utiliza **Flutter** como tecnología núcleo única. Esto reemplaza cualquier referencia anterior a Next.js, React Native o Expo, que quedan descartados del proyecto.

| Librería | Versión | Propósito |
| --- | --- | --- |
| `flutter_riverpod` | ^2.5.1 | Gestión de estado reactivo; ideal para Streams de sensores en tiempo real |
| `flutter_map` | ^6.1.0 | Renderizado de mapas basado en Leaflet; soporta polígonos GeoJSON y marcadores |
| `flame` | ^1.18.0 | Motor de juego 2D nativo en Flutter; corre como widget dentro de la app sin puentes externos |
| `dio` | ^5.4.3 | Cliente HTTP para peticiones REST (chatbot, secciones informativas, auth) |
| `web_socket_channel` | ^2.4.5 | Conexión WebSocket persistente para datos de sensores en tiempo real |
| `flutter_secure_storage` | ^9.x | Almacenamiento seguro del JWT en el dispositivo |

> **Nota:** Phaser.js queda descartado. El módulo de juego se desarrolla exclusivamente con **Flame Engine**, que corre nativo en Dart y comparte el árbol de widgets de Flutter, eliminando la necesidad de puentes entre plataformas.

### 3.2. Backend — FastAPI (Python)

- **Framework:** FastAPI. Elegido por su rendimiento (Starlette + Pydantic), soporte nativo de WebSockets asíncronos, auto-documentación con Swagger y compatibilidad directa con las librerías científicas de Python requeridas por el módulo de calibración.
- **Calibración:** Pandas, NumPy, Scikit-Learn para el ajuste matemático de las métricas de PM2.5.
- **Autenticación:** JWT emitido y validado en FastAPI (librería `python-jose`). Scope reducido: registro y login por email/contraseña, sin OAuth social en esta iteración.

### 3.3. Base de Datos — PostgreSQL + PostGIS

- **PostgreSQL 15+** como motor principal.
- **PostGIS** para consultas espaciales: verificar si las coordenadas de un sensor pertenecen a un sector delimitado, promedios por zona geográfica, etc.
- Tabla de usuarios con score persistido, vinculada a las partidas del juego.

### 3.4. Inteligencia Artificial — LangChain + LLM

- **Orquestador:** LangChain integrado en el backend de FastAPI.
- **SQL Agent / RAG:** Traduce preguntas en lenguaje natural a queries sobre el esquema de PostGIS.
- **Modelo de Lenguaje:** A definir por el equipo entre **OpenAI API (GPT-4o-mini)** y **Anthropic API (Claude)**. La arquitectura es agnóstica al proveedor gracias a LangChain; el cambio se realiza modificando únicamente la variable de entorno `LLM_PROVIDER`.

---

## 4. Justificación de Decisiones Técnicas

| Desafío del Proyecto | Solución Tecnológica | Justificación |
| :--- | :--- | :--- |
| **Multiplataforma estricto (Web + Mobile)** | **Flutter (Dart)** | Evita desarrollar la app dos veces. El renderizado por pixel garantiza que el mapa y los Tooltips sean idénticos en desktop y celular. Reemplaza la combinación descartada de Next.js + React Native. |
| **Calibración de hardware por entorno** | **Python (FastAPI + NumPy)** | La Ing. Electrónica requiere librerías científicas para ajustar el PM2.5 por humedad. Python es el estándar y FastAPI expone estos cálculos como endpoints de alto rendimiento. |
| **Datos de sensores en tiempo real** | **WebSocket (FastAPI + web_socket_channel)** | REST polling introduce latencia perceptible. Un WebSocket persistente permite que Riverpod actualice el estado de la UI en Flutter instantáneamente al recibir nuevos datos. |
| **Mapa sectorizado por polígonos** | **PostGIS + GeoJSON + flutter_map** | PostGIS calcula la pertenencia espacial en el servidor. `flutter_map` renderiza los polígonos GeoJSON nativamente sin librerías JavaScript externas. |
| **Juego educativo integrado** | **Flame Engine** | Desarrollar el juego en una plataforma externa (Unity, Godot, Phaser.js) requeriría un puente complejo para compartir datos de sensores y estado de usuario. Flame corre nativo en Dart dentro del mismo árbol de widgets. |
| **Persistencia del score del juego** | **JWT + PostgreSQL** | Un sistema de auth mínimo (JWT) permite vincular el score a un usuario real sin la complejidad de OAuth. Es la dependencia bloqueante para HU-7, por eso se desarrolla en Sprint 3. |
| **Seguridad de API keys** | **Variables de entorno (.env)** | Ninguna clave de LLM ni credencial de base de datos puede estar en el repositorio. El archivo `.env` se excluye vía `.gitignore` y se documenta en la Wiki de Taiga con un `.env.example`. |

---

## 5. Configuración de Entornos — Sprint 0 (Spikes)

### 5.1. Monorepo en GitHub

Se utiliza un único repositorio `ecobytes` dentro de la organización Bit&Volt, con la siguiente estructura raíz:

```scheme
ecobytes/
├── frontend/   — Flutter (Dart)
└── backend/    — FastAPI (Python)
```

Esta estructura permite gestionar ambos proyectos desde un solo repositorio: un único tablero de issues, un solo conjunto de ramas `main` / `develop` y Pull Requests que pueden tocar ambas capas cuando una tarea lo requiera.

### 5.2. `pubspec.yaml` Base (Flutter)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  flutter_map: ^6.1.0
  flame: ^1.18.0
  dio: ^5.4.3
  web_socket_channel: ^2.4.5
  flutter_secure_storage: ^9.0.0
```

### 5.3. Estructura Base del Monorepo

```scheme
ecobytes/
├── .gitignore
├── README.md
├── frontend/                        — Flutter
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── features/
│   │   │   ├── map/
│   │   │   ├── chatbot/
│   │   │   ├── game/
│   │   │   ├── auth/
│   │   │   └── education/
│   │   └── shared/
│   └── test/
└── backend/                         — FastAPI (Python)
    ├── main.py                      # App con CORS habilitado
    ├── routers/
    │   ├── sensors.py               # POST /sensors/data + WS /ws/sectors
    │   ├── chatbot.py               # POST /api/chatbot
    │   ├── auth.py                  # POST /auth/register, /auth/login
    │   └── game.py                  # POST /game/score
    ├── services/
    │   └── calibration.py           # Función de corrección de PM2.5
    ├── models/                      # Esquemas Pydantic
    ├── db/                          # Configuración PostgreSQL + PostGIS
    ├── .env.example
    └── requirements.txt
```

### 5.4. Variables de Entorno Requeridas (`backend/.env`)

```scheme
DATABASE_URL=postgresql://user:password@localhost:5432/ecobytes
JWT_SECRET_KEY=...
LLM_PROVIDER=openai          # o "anthropic"
OPENAI_API_KEY=...           # si LLM_PROVIDER=openai
ANTHROPIC_API_KEY=...        # si LLM_PROVIDER=anthropic
```

---

## 6. Definition of Done (DoD)

Una Historia de Usuario se considera "Hecha" cuando cumple todos los siguientes criterios:

- **Flutter:** Código Dart formateado con `flutter format`, sin advertencias críticas del linter.
- **Backend:** Endpoints documentados automáticamente en Swagger (`/docs`).
- **Calibración:** Algoritmo documentado matemáticamente en la Wiki de Taiga con fórmula, parámetros y ejemplos de validación.
- **Base de Datos:** Migraciones creadas de forma limpia y reversible para PostgreSQL/PostGIS.
- **Seguridad:** Ninguna API key ni credencial expuesta en el código fuente.
- **Integración:** Pull Request aprobado por al menos un compañero de Ingeniería de Sistemas antes del merge a `develop`.
