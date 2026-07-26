import 'package:flutter/foundation.dart';

import '../../../../core/data/api_client.dart';
import '../../domain/models/mensaje_chat.dart';

/// Disponibilidad del asistente, derivada de las respuestas del backend.
///
/// Arranca en [desconocida] a propósito: hasta que no se envía el primer
/// mensaje no hay forma de saber si el servidor tiene `OPENAI_API_KEY`
/// configurada, y afirmar "en línea" o "fuera de línea" antes de eso sería
/// inventar. El badge de la UI refleja los tres estados.
enum DisponibilidadChatbot { desconocida, disponible, noDisponible }

/// Conversación con el asistente ambiental (`POST /chatbot`).
///
/// El historial vive aquí y viaja completo en cada petición: el backend no
/// guarda estado de conversación. No hay polling — a diferencia del mapa,
/// aquí solo se habla cuando el usuario escribe.
class ChatbotProvider extends ChangeNotifier {
  ChatbotProvider({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// Saludo inicial. No afirma ningún dato de calidad del aire a propósito:
  /// las cifras solo pueden salir del backend, nunca de texto fijo del
  /// cliente (fue justamente el problema de la maqueta anterior).
  static const _saludo = MensajeChat(
    texto: '¡Hola! Soy tu asistente ambiental. Puedo contarte cómo está la '
        'calidad del aire en las comunas de Cali y explicarte qué significan '
        'las mediciones. ¿En qué te ayudo?',
    esUsuario: false,
  );

  final List<MensajeChat> _mensajes = [_saludo];
  bool _enviando = false;
  String? _mensajeError;
  DisponibilidadChatbot _disponibilidad = DisponibilidadChatbot.desconocida;
  bool _destruido = false;

  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  bool get enviando => _enviando;
  String? get mensajeError => _mensajeError;
  DisponibilidadChatbot get disponibilidad => _disponibilidad;

  /// Envía un mensaje del usuario y agrega la respuesta del asistente.
  ///
  /// El turno del usuario se pinta de inmediato (antes de la respuesta) para
  /// que la conversación no se sienta congelada mientras el modelo piensa.
  /// Si la petición falla, ese turno **se conserva**: borrarlo haría parecer
  /// que el usuario nunca escribió.
  Future<void> enviar(String texto) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty || _enviando) return;
    if (_disponibilidad == DisponibilidadChatbot.noDisponible) return;

    // El historial es la conversación *previa* a este mensaje: el mensaje
    // nuevo va aparte, en su propio campo de la petición.
    final historial = List<MensajeChat>.from(_mensajes);

    _mensajes.add(MensajeChat(texto: mensaje, esUsuario: true));
    _enviando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      final respuesta = await _apiClient.postChatbot(
        mensaje: mensaje,
        historial: historial,
      );
      _mensajes.add(
        MensajeChat(
          texto: respuesta.respuesta,
          esUsuario: false,
          acciones: respuesta.acciones,
        ),
      );
      _disponibilidad = DisponibilidadChatbot.disponible;
    } on ChatbotNoDisponibleException catch (e) {
      _disponibilidad = DisponibilidadChatbot.noDisponible;
      _mensajeError = e.mensaje;
    } on ApiException catch (e) {
      _mensajeError = e.mensaje;
    } catch (_) {
      _mensajeError = 'Ocurrió un error inesperado al consultar al asistente.';
    } finally {
      _enviando = false;
    }

    if (_destruido) return;
    notifyListeners();
  }

  /// Reintenta el último mensaje del usuario tras un error transitorio.
  Future<void> reintentar() async {
    if (_enviando) return;
    if (_disponibilidad == DisponibilidadChatbot.noDisponible) return;

    // Solo tiene sentido si el último turno es del usuario, que es como
    // queda la conversación tras un fallo (no se agregó respuesta). Se
    // comprueba antes de quitarlo: si `enviar()` se negara a reenviarlo,
    // quitarlo primero borraría el mensaje del usuario de la pantalla.
    if (_mensajes.isEmpty || !_mensajes.last.esUsuario) return;

    // Se quita el turno fallido para no duplicarlo: `enviar()` lo vuelve a
    // agregar, y así el historial que viaja al backend queda igual que en
    // el primer intento.
    final ultimo = _mensajes.removeLast();
    await enviar(ultimo.texto);
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }
}
