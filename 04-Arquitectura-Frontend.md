# 📱 Arquitectura Frontend — EcoBytes

**Stack:** Flutter (Dart) · Compilado exclusivamente a web · Diseño responsive

> Tres pantallas, pensadas para verse bien tanto en desktop como en teléfono desde el navegador. No hay build nativo de Android/iOS — el acceso móvil se resuelve con diseño responsive dentro de la misma app web.

---

## 1. Principios de diseño

1. **Solo web.** Un único target de compilación (`flutter build web`). Sin carpetas `android/`, `ios/`, `macos/`, `linux/`, `windows/` en el repositorio — si existen, se eliminan.
2. **Acceso abierto.** No hay pantalla de login ni estado de sesión que propagar por el árbol de widgets — cualquier persona entra y usa la app directamente.
3. **Polling para datos frescos.** El mapa se refresca llamando al backend cada 30-60 segundos con un `Timer.periodic`, sin conexión persistente.
4. **Gestión de estado simple.** `Provider` (o `ChangeNotifier` directo) es suficiente para tres pantallas sin lógica de negocio compleja — se evita la ceremonia de definir eventos y estados por feature que solo se justifica en apps más grandes.
5. **Tres módulos, cero dependencias cruzadas obligatorias.** Cada módulo puede desarrollarse y probarse en paralelo por distintas personas del equipo, igual que en el backlog.

---

## 2. Stack técnico

| Herramienta | Propósito |
| --- | --- |
| **Flutter (Dart)** | Un solo código fuente, compilado únicamente a web |
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
│   ├── main.dart
│   ├── app.dart                          # Rutas: /map, /risk, /learn — nada más
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── app_spacing.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       └── responsive.dart           # Breakpoints centralizados
│   ├── services/
│   │   └── api_client.dart               # Cliente HTTP centralizado hacia el backend
│   ├── features/
│   │   ├── map/
│   │   │   ├── models/
│   │   │   │   └── sector.dart
│   │   │   ├── providers/
│   │   │   │   └── sectors_provider.dart # Fetch + polling de /sectors
│   │   │   ├── map_page.dart
│   │   │   └── widgets/
│   │   │       ├── map_area.dart
│   │   │       └── sector_detail_card.dart
│   │   ├── risk/
│   │   │   ├── models/
│   │   │   │   └── risk_profile.dart
│   │   │   ├── providers/
│   │   │   │   └── risk_provider.dart    # Fetch de /risk/{sector}
│   │   │   ├── risk_page.dart
│   │   │   └── widgets/
│   │   │       ├── sector_selector.dart
│   │   │       └── risk_profile_card.dart
│   │   └── learn/
│   │       ├── models/
│   │       │   └── education_content.dart
│   │       └── learn_page.dart
│   └── shared/
│       └── widgets/
│           ├── adaptive_scaffold.dart    # Navbar responsive (inferior en móvil, lateral en desktop)
│           ├── loading_state.dart
│           ├── error_state.dart
│           └── status_badge.dart
└── test/
```

**Lo que no existe en esta estructura, a propósito:**
- Ninguna carpeta de plataforma nativa (`android/`, `ios/`, etc.).
- `features/landing/` y `features/chatbot/` — no forman parte del alcance del producto.
- Cualquier archivo de manejo de sesión, token o login.

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

Al tocar un sector aparece `sector_detail_card.dart` con los valores exactos, consumiendo `GET /sectors/{id}` bajo demanda (sin polling continuo para el detalle).

---

## 6. Módulo Riesgo por Dirección

**Flujo:**
1. Usuario selecciona un barrio/comuna con `sector_selector.dart` (dropdown, sin input de texto libre ni geocoding).
2. `risk_provider.dart` llama `GET /risk/{sector}` una sola vez (sin polling — un perfil histórico no cambia en tiempo real).
3. `risk_profile_card.dart` muestra promedio anual, peor/mejor mes y días sobre límite OMS.
4. Si `historico_suficiente: false` en la respuesta, se muestra un aviso claro en vez de presentar el dato como si fuera confiable.

---

## 7. Módulo Educativo

La pantalla más simple del proyecto: contenido de `GET /education`, o empaquetado como asset local (`education_content.dart`) si se prefiere evitar hasta esa llamada de red. Sin navegación interna, sin estado más allá de loading/loaded.

---

## 8. Navegación

Tres secciones, adaptadas por breakpoint mediante `adaptive_scaffold.dart`:

```scheme
Mapa | Riesgo por Dirección | Aprender
```

Sin rutas de landing ni de chatbot — el usuario entra directo al mapa.

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
- Cero carpetas de plataforma nativa, cero referencias a sesión/token, cero rutas de landing o chatbot en el repositorio.
