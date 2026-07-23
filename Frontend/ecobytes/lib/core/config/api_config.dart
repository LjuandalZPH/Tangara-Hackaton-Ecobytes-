/// Configuración de acceso al backend de EcoBytes.
///
/// La URL base se puede sobreescribir en tiempo de compilación con:
///   flutter run -d chrome --dart-define=API_BASE_URL=https://api.ecobytes.example
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
}
