# 📱 Arquitectura Frontend — EcoBytes

**Stack:** Flutter (Dart) · Web como target principal, con soporte nativo (Android/iOS/desktop) conservado desde el mismo código fuente · Diseño responsive

> La navegación principal replica el [Figma del equipo](https://www.figma.com/design/DdGdcWdvPtcSdZ7mRRzXW9/EcoBytes-%E2%80%94-Landing-Page): Landing (`/`), Mapa (`/mapa`), Aprende (`/aprende`) y Chatbot (`/chatbot`). Desde el mapa, cada sector abre una pantalla de **detalle de sector** (pestañas Resumen / Historia / Sensores — pantalla "Detalle de Producto" del Figma) que no es parte de la navegación principal, sino un sub-flujo del mapa. **Actualización (2026-07-23): donde este documento y el Figma choquen, gana el Figma** — varias secciones de abajo asumían un alcance reducido (sin landing, sin chatbot, con una pantalla "Riesgo por Dirección" separada) que no coincide con el diseño real del equipo.

---

## 1. Principios de diseño

1. **Web como target principal.** `flutter build web` es el build que se despliega en producción. Las carpetas `android/`, `ios/`, `macos/`, `linux/`, `windows/` se mantienen versionadas en el repositorio para permitir compilar builds nativos (ej. un APK de Android) a demanda, aunque hoy no formen parte del pipeline de despliegue.
2. **Acceso abierto.** No hay pantalla de login ni estado de sesión que propagar por el árbol de widgets — cualquier persona entra y usa la app directamente.
3. **Polling para datos frescos.** El mapa se refresca llamando al backend cada 30-60 segundos con un `Timer.periodic`, sin conexión persistente.
4. **Gestión de estado simple.** `Provider` (o `ChangeNotifier` directo) es suficiente para el número de pantallas del producto — se evita la ceremonia de definir eventos y estados por feature que solo se justifica en apps más grandes.
5. **Módulos con pocas dependencias cruzadas.** Landing, mapa, aprende y chatbot pueden desarrollarse y probarse en paralelo por distintas personas del equipo. El detalle de sector depende del mapa (necesita un sector seleccionado), pero no de las demás.

---

## 2. Stack técnico

| Herramienta | Propósito |
| --- | --- |
| **Flutter (Dart)** | Un solo código fuente; se compila a web (target principal de despliegue) y opcionalmente a Android/iOS/desktop desde las mismas carpetas de plataforma |
| **`flutter_map`** | Mapa interactivo con polígonos GeoJSON, motor Leaflet + OpenStreetMap |
| **`http`** | Cliente HTTP hacia el backend FastAPI |
| **`provider`** | Gestión de estado ligera para loading/data/error por pantalla |
| **`intl`** | Formateo de fechas (última lectura, meses del perfil histórico) |

---

## 3. Estructura del proyecto

```scheme
frontend/
├── pubspec.yaml
├── web/
│   ├── index.html
│   └── manifest.json
├── lib/
│   ├── main.dart                         # Entrypoint real: MyApp + MultiProvider
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── app_spacing.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   ├── router/
│   │   │   └── app_router.dart           # AppRoutes + GoRouter: /, /mapa, /aprende, /chatbot
│   │   └── utils/
│   │       └── responsive.dart           # Breakpoints centralizados
│   ├── features/
│   │   ├── landing/
│   │   │   └── presentation/pages/landing_page.dart        # Ver Figma "Landing Page"
│   │   ├── dashboard/                    # El "Mapa" del Figma
│   │   │   ├── domain/models/sector.dart
│   │   │   ├── presentation/providers/sectors_provider.dart  # Fetch + polling de /sectors
│   │   │   └── presentation/pages/
│   │   │       ├── map_page.dart
│   │   │       └── sector_detail_page.dart   # Resumen / Historia / Sensores — Figma "Detalle de Producto"
│   │   ├── risk/
│   │   │   ├── domain/models/riesgo.dart
│   │   │   └── presentation/providers/risk_provider.dart   # Fetch de /risk/{sector}; alimenta la pestaña
│   │   │                                                    # "Historia" de sector_detail_page.dart — sin
│   │   │                                                    # pantalla ni ruta propia (ver §6)
│   │   ├── learn/
│   │   │   └── presentation/pages/learn_page.dart
│   │   └── chatbot/
│   │       └── presentation/pages/chatbot_page.dart   # Hoy stub visual, ver §6/§8
│   └── shared/
│       └── widgets/
│           ├── landing_header.dart       # Header global (todas las páginas)
│           ├── landing_footer.dart       # Footer global (todas las páginas)
│           ├── adaptive_scaffold.dart    # Navbar responsive (inferior en móvil, lateral en desktop)
│           ├── loading_state.dart
│           ├── error_state.dart
│           └── status_badge.dart
└── test/
```

**Lo que no existe en esta estructura, a propósito:** archivos de manejo de sesión, token o login (principio 2 — no hay pantalla de login).

Todo lo demás —landing, chatbot, plataformas nativas— se conserva; están respaldados por el Figma del equipo, no son scaffold heredado sin revisar.

---

## 4. Diseño responsive

No es una app separada para móvil — es la misma interfaz adaptada con layout condicional:

- **Breakpoints centralizados** en `core/utils/responsive.dart`, usados por todos los widgets que necesitan adaptar su layout.
- **Navegación:** `adaptive_scaffold.dart` decide entre barra inferior (pantallas angostas) o barra lateral (pantallas anchas) — un solo widget, sin duplicar lógica de navegación.
- **Mapa:** `flutter_map` es táctil por defecto (pinch-to-zoom, tap) sin configuración adicional — funciona igual de bien con mouse que con dedo.
- **Validación:** basta con abrir el navegador del teléfono apuntando a la URL de desarrollo, o usar las devtools de Chrome en modo responsive — no se necesita emulador ni dispositivo físico dedicado.

---

## 5. Módulo Mapa

**Patrón de polling:**

```dart
// sectors_provider.dart (esqueleto)
class SectorsProvider extends ChangeNotifier {
  List<Sector> sectores = [];
  bool isLoading = true;
  String? error;
  Timer? _pollingTimer;

  void startPolling() {
    _fetch();
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      sectores = await apiClient.getSectors();
      error = null;
    } catch (e) {
      error = 'No se pudo actualizar el mapa';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
```

`flutter_map` renderiza los polígonos del GeoJSON recibido, coloreados según el campo `estado` (`verde`/`amarillo`/`rojo`/`gris`) que ya llega calculado desde el backend — el frontend no calcula umbrales, solo pinta lo que recibe.

Al tocar "Ver detalle del sector" (o un sector en el mapa) se navega a `sector_detail_page.dart` — ver §6.

---

## 6. Módulo Detalle de Sector

**Reemplaza lo que este documento llamaba antes "Módulo Riesgo por Dirección".** No es una pantalla de navegación aparte con selector de barrio — es la página a la que se llega desde el mapa (botón "Ver detalle del sector" o tap en un sector), con tres pestañas (Figma "Detalle de Producto"):

1. **Resumen** — indicadores actuales (PM2.5, CO2, humedad) y evolución de las últimas 24h, desde `GET /sectors/{id}` bajo demanda (sin polling continuo para el detalle).
2. **Historia** — perfil histórico anual: promedio anual, peor/mejor mes, días sobre el límite OMS, desde `GET /risk/{sector}` (`risk_provider.dart`, fetch bajo demanda, sin polling — un perfil histórico no cambia en tiempo real). Si `historico_suficiente: false` en la respuesta, se muestra un aviso claro en vez de presentar el dato como si fuera confiable.
3. **Sensores** — ubicación y lista de sensores del sector en un mini-mapa.

Botones de acción: "Preguntar al chatbot" (navega a `/chatbot`) y "Ver el mapa" (vuelve a `/mapa`).

---

## 7. Módulo Educativo

La pantalla más simple del proyecto: contenido de `GET /education`, o empaquetado como asset local (`education_content.dart`) si se prefiere evitar hasta esa llamada de red. Sin navegación interna, sin estado más allá de loading/loaded.

---

## 8. Navegación

Nav global (header/footer compartidos, `shared/widgets/landing_header.dart` y `landing_footer.dart`), replicando el Figma:

```scheme
Inicio | Mapa | Aprende | Chatbot
```

El detalle de sector (§6) se alcanza únicamente desde el mapa — no aparece como ítem de navegación propio.

**Decisión (2026-07-23):** landing y chatbot se conservan como parte de la navegación principal — respaldados por el Figma del equipo, no son scaffold heredado. El chatbot mantiene su lugar en el producto (nav + pantalla propia), pero su implementación real (conexión a un backend/LLM) está en pausa hasta que un miembro del equipo la retome — no se está tocando ese alcance ni ese código por ahora. Ver `05-Discrepancias.md`.

---

## 9. Despliegue

```bash
flutter build web --release
```

Genera archivos estáticos desplegables en cualquier hosting simple (Vercel, Netlify, o un bucket con CDN) — sin necesidad de servidor Dart corriendo en producción. El único requisito operativo es que el backend tenga CORS configurado para el dominio donde se sirve este build.

---

## 10. Definition of Done (frontend)

- `flutter analyze` sin advertencias críticas.
- Cada pantalla maneja explícitamente sus tres estados: cargando, con datos, error — sin excepción.
- El polling del mapa se detiene correctamente al salir de la pantalla (`dispose()` cancela el `Timer`), para no gastar datos innecesariamente en móvil.
- Validado manualmente en al menos un viewport de escritorio y uno de teléfono (devtools o dispositivo real) antes del pitch.
- Cero referencias a sesión/token en el repositorio. (Plataformas nativas, landing y chatbot se conservan — ver §1, §3, §6 y §8.)
