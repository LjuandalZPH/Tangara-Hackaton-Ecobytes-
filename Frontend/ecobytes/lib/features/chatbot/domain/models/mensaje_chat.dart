/// Un turno de la conversación con el asistente ambiental.
///
/// El servidor no guarda estado: el historial vive aquí, en el cliente, y
/// viaja completo en cada petición a `POST /chatbot` (ver
/// 03-Arquitectura-Backend.md §3).
class MensajeChat {
  const MensajeChat({
    required this.texto,
    required this.esUsuario,
    this.acciones = const [],
  });

  final String texto;
  final bool esUsuario;

  /// Botones sugeridos por el asistente. Llegan de una lista cerrada que
  /// el backend valida (`ACCIONES_CHATBOT`), así que la UI siempre sabe
  /// qué hacer con cada uno — nunca son texto libre del modelo.
  final List<String> acciones;

  /// Formato que espera el backend en el campo `historial`.
  Map<String, String> toJson() => {
        'rol': esUsuario ? 'usuario' : 'asistente',
        'texto': texto,
      };
}

/// Respuesta de `POST /chatbot`.
class RespuestaChatbot {
  const RespuestaChatbot({required this.respuesta, required this.acciones});

  final String respuesta;
  final List<String> acciones;

  factory RespuestaChatbot.fromJson(Map<String, dynamic> json) {
    return RespuestaChatbot(
      respuesta: (json['respuesta'] as String?) ?? '',
      acciones: ((json['acciones'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
