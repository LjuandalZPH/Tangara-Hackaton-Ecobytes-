# ⚠️ Discrepancias — Documentación vs. Estado Real del Código

**Última actualización:** 2026-07-23

> Este documento existe porque el proyecto arrancó con una base de código Flutter/FastAPI ya construida por otro equipo/sprint anterior, y la arquitectura descrita en `01-Arquitectura.md` a `04-Arquitectura-Frontend.md` es la que **el equipo decidió como objetivo**, con las razones y decisiones ya documentadas ahí. Ese documento manda: es el diseño correcto y acordado. El código heredado que no coincide con él no es una alternativa válida — es trabajo pendiente de corregir, deuda técnica de una implementación que se hizo antes de (o sin seguir) la decisión de arquitectura.
>
> Regla general: **la documentación de arquitectura es la fuente de verdad.** Este archivo no existe para justificar el código actual, sino para que quede explícito qué le falta al código para alinearse con lo documentado, y así poder priorizar cerrar esas brechas. Si vas a tocar una parte del sistema listada aquí, el trabajo por defecto es acercar el código al objetivo documentado, no perpetuar la desviación — salvo que el equipo indique explícitamente lo contrario para esa tarea puntual.

---

## 0. Bug de seguridad encontrado y corregido en esta revisión

`Backend/.gitignore` tenía la regla `backend/.env` (minúscula) para ignorar el archivo de variables de entorno. Como ese `.gitignore` vive *dentro* de `Backend/`, sus patrones con `/` son relativos a esa misma carpeta — la regla en realidad buscaba `Backend/backend/.env` (una subcarpeta que no existe), **no** `Backend/.env` (el archivo real). Se verificó con `git check-ignore -v Backend/.env`: no coincidía, es decir, **`Backend/.env` con secretos reales (`JWT_SECRET_KEY`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, credenciales de `DATABASE_URL`) no estaba protegido contra un `git add` accidental** en este filesystem case-sensitive (Linux). El mismo problema afectaba a la regla `backend/data/`.

**Corregido en esta revisión:** la regla de `.env` se cambió a `.env` (sin el prefijo `backend/`), verificado con `git check-ignore`. La regla de datos pesados pasó primero a `data/` y **luego se ajustó otra vez a solo `*.csv`/`*.csv.gz`**, porque un `data/` a secas ignoraba la carpeta completa — justo cuando se agregó ahí `sectores.geojson` (ver §1, el GeoJSON de sectores que sostiene la sectorización del backend), que sí debe versionarse. Si alguien ya tiene un `.env` con secretos reales y en algún momento corrió `git add -A` o `git add .` antes de esta corrección, vale la pena revisar el historial de commits para confirmar que nunca se coló (`git log --all --full-history -- Backend/.env`); a la fecha de esta revisión no aparece commiteado ningún `.env`.

---

## 1. Backend

✅ **Sin discrepancias pendientes (verificado 2026-07-23).** El backend implementa exactamente el contrato de `03-Arquitectura-Backend.md`: los cuatro endpoints (`GET /sectors`, `GET /sectors/{id}`, `GET /risk/{sector}`, `GET /education`, más `/health`), sectorización real vía `services/geo.py` (`SectorIndex` + `shapely` sobre `data/sectores.geojson`), fuente única de datos en `services/clickhouse_client.py` (ClickHouse, capa Plata, con `services/calibration.py` aplicando la corrección de PM2.5 por humedad) y caché en `services/cache.py`. No hay BD propia ni routers `sensors`/`auth`/`chatbot`/`game` — `db/`, `models/` y `scripts/` quedaron vacíos tras la migración. Verificación end-to-end contra ClickHouse real y detalle técnico completo (decisiones, queries, hallazgos) en `06-Plan-de-Accion.md` §1-2.

---

## 2. Frontend

| Área | Objetivo — lo que manda (`04-Arquitectura-Frontend.md`) | Código real — pendiente de alinear (`Frontend/ecobytes/`) |
| --- | --- | --- |
| Gestión de estado | `Provider` / `ChangeNotifier` simple | `flutter_bloc` + `equatable` (patrón Bloc completo: `sensor_bloc.dart`, `sensor_event.dart`, `sensor_state.dart`) |
| Plataformas | Solo web (`flutter build web`), sin carpetas nativas en el repo | Carpetas nativas presentes: `android/`, `ios/`, `macos/`, `linux/`, `windows/` — no se ha ejecutado la limpieza (tarea `T-00.1` del backlog) |
| Pantallas / rutas | Exactamente tres: `/map`, `/risk`, `/learn` (sin login, sin landing, sin chatbot) | Cuatro rutas reales (`lib/app.dart` → `AppRoutes`): `/` (landing), `/mapa`, `/aprende`, `/chatbot`. **No existe todavía** la pantalla de Riesgo por Dirección (`/risk`) — es la única feature completamente nueva según el backlog (EPI-04) y aún no se ha construido |
| Feature `landing/` | No debe existir — "cero rutas de landing... en el repositorio" | Existe completa: hero, features, stats, CTA, footer (`features/landing/presentation/widgets/`) |
| Feature `chatbot/` | No debe existir — fuera del alcance del producto | Existe como página stub (`features/chatbot/presentation/pages/chatbot_page.dart`), en paralelo al router de chatbot del backend |
| Datos del mapa | Vienen de `GET /sectors` (polígonos GeoJSON + estado ya calculado) | ✅ **Cerrado (2026-07-23).** `SectorsProvider` consume `GET /sectors` cada 45 s y `MapArea` pinta los 22 polígonos reales. Los sensores ficticios ("Parque del Amor", "Zona Industrial", "La Flora") fueron eliminados. `MockSensorRepository` solo sobrevive en `features/landing/`, marcada para eliminación. Ver [`07-Integracion-Backend-Frontend.md`](./07-Integracion-Backend-Frontend.md) |
| Módulo Riesgo (`risk/`) | Selector de barrio → perfil histórico (`risk_provider.dart`, `risk_profile_card.dart`) | No existe ninguna carpeta `features/risk/` todavía |
| Módulo Educativo (`learn/`) | Contenido de `GET /education` o asset local | Existe (`features/learn/`), pero no se ha confirmado si su contenido viene de un asset local o si se conectará a un endpoint — pendiente de decisión (tarea `T-05.2`) |
| Estructura de carpetas por feature | `models/`, `providers/`, página, `widgets/` | Usa `data/`, `domain/`, `presentation/{bloc,pages,widgets}` — nomenclatura tipo Clean Architecture, no la propuesta en el doc |
| Arranque de la app | Un único widget raíz (`EcoBytesApp` implícito) | Hay **dos** definiciones de app raíz: `lib/main.dart` (`MyApp`, es el entrypoint real usado en `main()`) y `lib/app.dart` (`EcoBytesApp`, define su propio `MaterialApp.router` pero no se usa) — código muerto o refactor a medias, hay que confirmar cuál se queda antes de tocar el arranque |

**Por qué está desalineado:** el proyecto Flutter heredado ya traía landing page, chatbot y navegación completa construidos por otro sprint/equipo, antes de que el equipo decidiera reducir el alcance del producto a las tres pantallas núcleo documentadas. Esa decisión ya está tomada y documentada (`04-Arquitectura-Frontend.md` §3: "si existen, se eliminan") — lo que falta es ejecutarla. La limpieza (EPI-01 del backlog, tareas `T-00.1` a `T-00.6`) es trabajo pendiente y bloqueante en el orden del backlog, no una opción a evaluar: el propio `02-Backlog.md` marca EPI-02 (capa de datos) como dependiente de EPI-01 precisamente para no seguir construyendo sobre una base sin limpiar.

### 2.1 Deuda adicional encontrada dentro del propio frontend

Estos hallazgos no son "doc dice X, código tiene Y" directo, pero salieron al comparar el código contra la arquitectura objetivo y son bloqueantes para ejecutar limpiamente EPI-01/EPI-02 del backlog — hay que resolverlos como parte de la migración, no ignorarlos:

- ✅ **La ruta `/mapa` ya muestra el mapa real (2026-07-23).** `MapaPage` dejó de pintar el `Container` con `GridPaper` y el texto `"[ Espacio reservado para mapa interactivo ]"`; ahora consume `SectorsProvider` y renderiza `MapArea`, que pasó de marcadores a `PolygonLayer` con los 22 polígonos de comuna coloreados por estado. Se eliminaron sus cifras hardcodeadas (los 5 sectores ficticios, la grilla decorativa y el "AQI promedio: 32"). **Queda abierto:** `_SidePanelSection` dentro de `map_page.dart` conserva datos inventados ("AQI promedio ciudad: 52", métricas fijas) y debería alimentarse de `GET /sectors/{id}`.
- ✅ **`SensorBloc` eliminado (2026-07-23).** Era andamiaje muerto: ningún `BlocProvider`/`BlocBuilder` en toda la app lo usaba. Se borró `presentation/bloc/` completo y `flutter_bloc` salió de `pubspec.yaml` al migrar a `Provider`.
- **El único test existente no prueba la app real.** `test/widget_test.dart` monta `EcoBytesApp` (definido en `lib/app.dart`), pero el entrypoint real de la app es `MyApp` en `lib/main.dart` (ver fila "Arranque de la app" arriba). El test pasa, pero no valida el árbol de widgets que corre en producción.
- **`landing/` no se puede borrar de forma aislada tal como está hoy.** `map_page.dart`, `learn_page.dart` y `chatbot_page.dart` importan directamente `LandingHeader`, `LandingFooter` y `LandingMobileNav` desde `features/landing/presentation/widgets/` para su cabecera y pie de página globales. Ejecutar la tarea `T-00.4` (eliminar landing) tal cual está en el backlog rompe la compilación de las otras tres páginas — antes de borrar `landing/`, `LandingHeader`/`LandingFooter`/`LandingMobileNav` deben moverse a `shared/widgets/` (son en realidad el header/footer global de toda la app, no widgets exclusivos de la landing).
- **El chatbot del frontend es una maqueta visual sin backend, y lo dice explícitamente en su propia UI:** el badge de estado en `chatbot_page.dart` muestra "Fuera de línea · Modo de demostración visual" — confirma que ni siquiera intenta llamar al router `chatbot.py` del backend (que de todas formas es un stub). Es puramente decorativo hoy.
- **Estadísticas inventadas presentadas como reales en la landing.** `StatsBar` (`features/landing/presentation/widgets/stats_bar.dart`) muestra "47 sensores activos", "22 comunas cubiertas" y "2.4M ciudadanos informados" como texto hardcodeado — el mismo patrón de dato falso disfrazado de real que el mapa de `MapaPage`, solo que aquí es contenido de marketing. Baja prioridad porque `landing/` está marcada para eliminación, pero si se decide conservar alguna sección de landing, estos números deben salir o marcarse explícitamente como ilustrativos.
- **Error tipográfico del nombre del equipo en el footer.** `landing_footer.dart` muestra "BitAVIT Labs" dos veces; el nombre correcto en toda la documentación (README, `01-Arquitectura.md`) es **Bit&Volt Labs**. Cosmético, pero visible en producción.

---

## 3. Contrato de API

✅ El backend ya implementa el contrato completo de `03-Arquitectura-Backend.md` §3 (`/sectors`, `/sectors/{id}`, `/risk/{sector}`, `/education`), con agregación por sector (mapeo sensor→sector, cálculo de `estado` verde/amarillo/rojo/gris, umbral de "sin datos recientes"), verificado end-to-end contra ClickHouse real — ver `06-Plan-de-Accion.md` §2.4.

Lo único que queda pendiente es del lado del **frontend**: `dashboard` sigue corriendo 100% sobre `MockSensorRepository` y no consume ningún endpoint real todavía. Conectarlo es la siguiente tarea del proyecto (ver sección 2 arriba y `06-Plan-de-Accion.md` §3-4).

---

## 4. Cómo mantener este documento

- Cerrar una fila significa **corregir el código para que cumpla lo documentado**, no reinterpretar el documento a la luz del código. Cuando se ejecute una tarea del backlog que cierre una brecha (ej. `T-00.1` elimina carpetas nativas), **borra la fila correspondiente de este documento** en vez de dejarla como histórico — para eso está el historial de git.
- Si aparece una discrepancia nueva no listada aquí, agrégala con: qué dice el doc (el objetivo), qué hay en el código (la desviación), y por qué existe la desviación (si se conoce la razón) — nunca como justificación para no corregirla.
- La única forma legítima de eliminar una fila sin haber tocado el código es que el **equipo** decida explícitamente cambiar el objetivo (ej. quedarse con Postgres en vez de migrar a ClickHouse). En ese caso, la corrección correcta es actualizar primero `01-Arquitectura.md`/`03-Arquitectura-Backend.md` — porque esos documentos son la fuente de verdad — y solo después eliminar la fila de aquí. Nunca al revés: el código nunca redefine el objetivo por sí solo, ni por omisión ni porque "ya está así".
