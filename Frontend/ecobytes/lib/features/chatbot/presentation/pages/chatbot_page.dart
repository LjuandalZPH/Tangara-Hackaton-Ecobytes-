import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/status_badge.dart'; // Contiene EcoCard y SectionLabel
import '../../../../shared/widgets/landing_footer.dart';
import '../../../../shared/widgets/landing_header.dart';
import '../../domain/models/mensaje_chat.dart';
import '../providers/chatbot_provider.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  bool _menuOpen = false;
  final TextEditingController _textController = TextEditingController();

  // Atajos para arrancar la conversación. Son preguntas, no datos: el
  // contenido de la respuesta siempre viene del backend.
  static const _preguntasFrecuentes = [
    '¿Puedo hacer ejercicio hoy?',
    'Explícame qué es PM2.5',
    '¿Cuál es la comuna con mejor aire hoy?',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _enviar(String texto) {
    if (texto.trim().isEmpty) return;
    context.read<ChatbotProvider>().enviar(texto);
    _textController.clear();
  }

  /// Los botones que sugiere el asistente vienen de una lista cerrada
  /// (`ACCIONES_CHATBOT` en el backend), así que cada uno tiene un destino
  /// conocido: unos navegan, y los que en realidad son preguntas se envían
  /// como un mensaje más.
  void _ejecutarAccion(String accion) {
    switch (accion) {
      case 'Ver mapa de Cali':
        context.go(AppRoutes.dashboard);
        break;
      case 'Aprender sobre PM2.5':
        context.go(AppRoutes.learn);
        break;
      default:
        // "Recomendación de hoy" y "Comparar comunas" no son destinos, son
        // preguntas: se mandan al asistente como un turno más.
        _enviar(accion);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatbotProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera global de EcoBytes
            LandingHeader(
              menuOpen: _menuOpen,
              onMenuToggle: () => setState(() => _menuOpen = !_menuOpen),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_menuOpen) const LandingMobileNav(),

                    // 1. Info del Asistente
                    _AsistenteHeaderSection(disponibilidad: provider.disponibilidad),

                    // Container central para que el chat mantenga el ancho max web de tu diseño
                    ContentContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),

                            // 2. Lista de burbujas de mensajes
                            ...provider.mensajes.map(
                              (msg) => _ChatBubble(
                                message: msg,
                                onAccion: _ejecutarAccion,
                              ),
                            ),

                            // 3. Indicador de "escribiendo...", solo mientras
                            //    hay una respuesta realmente en vuelo.
                            if (provider.enviando) const _TypingIndicator(),

                            if (provider.mensajeError != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _MensajeDeError(
                                mensaje: provider.mensajeError!,
                                // Reintentar no sirve de nada si el servidor
                                // no tiene el asistente configurado.
                                onReintentar: provider.disponibilidad ==
                                        DisponibilidadChatbot.noDisponible
                                    ? null
                                    : provider.reintentar,
                              ),
                            ],

                            const SizedBox(height: AppSpacing.xl),

                            // 4. Preguntas frecuentes sugeridas
                            const SectionLabel(text: 'PREGUNTAS FRECUENTES'),
                            const SizedBox(height: AppSpacing.sm),
                            _buildPreguntasSugeridas(provider),
                            const SizedBox(height: AppSpacing.xl),

                            // 5. Input Bar (Caja de Texto y Botón Enviar)
                            _buildInputBar(provider),
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),

                    const LandingFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget: Píldoras de preguntas sugeridas
  Widget _buildPreguntasSugeridas(ChatbotProvider provider) {
    final habilitado = !provider.enviando &&
        provider.disponibilidad != DisponibilidadChatbot.noDisponible;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _preguntasFrecuentes.map((text) {
        return InkWell(
          onTap: habilitado ? () => _enviar(text) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: habilitado ? Colors.black87 : AppColors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Widget: Chat/InputBar (Diseño encapsulado en EcoCard según tu captura)
  Widget _buildInputBar(ChatbotProvider provider) {
    final noDisponible =
        provider.disponibilidad == DisponibilidadChatbot.noDisponible;
    final habilitado = !provider.enviando && !noDisponible;

    return EcoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const Text(
            'EcoBytes responde con base en los sensores de la red ciudadana. Ante emergencias respiratorias, contacta a un profesional de salud.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  enabled: habilitado,
                  onSubmitted: habilitado ? _enviar : null,
                  // Mismo límite que valida el backend: mejor cortar aquí
                  // que recibir un 422 después de escribir de más.
                  maxLength: 1000,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: noDisponible
                        ? 'El asistente no está disponible en este momento'
                        : 'Escribe tu pregunta sobre la calidad del aire...',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    fillColor: const Color(0xFFF3F4F6),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ElevatedButton(
                onPressed: habilitado ? () => _enviar(_textController.text) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: provider.enviando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Enviar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ========================================================
// SUB-COMPONENTES INTERNOS PRIVADOS PARA EL FLUJO DEL CHAT
// ========================================================

class _AsistenteHeaderSection extends StatelessWidget {
  const _AsistenteHeaderSection({required this.disponibilidad});

  final DisponibilidadChatbot disponibilidad;

  @override
  Widget build(BuildContext context) {
    // El badge refleja lo que el backend ha dicho realmente, no un valor
    // fijo: hasta el primer mensaje no se sabe si el asistente está
    // configurado en el servidor, y decir "en línea" antes sería inventar.
    final (Color color, String texto) = switch (disponibilidad) {
      DisponibilidadChatbot.disponible => (
          AppColors.primaryGreen,
          'En línea · Responde con datos reales de los sensores',
        ),
      DisponibilidadChatbot.noDisponible => (
          Colors.grey,
          'Fuera de línea · El asistente no está configurado en el servidor',
        ),
      DisponibilidadChatbot.desconocida => (
          Colors.grey,
          'Escribe tu primera pregunta para empezar',
        ),
    };

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFC),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: ContentContainer(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.spa, color: color, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Asistente ambiental EcoBytes',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          texto,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final MensajeChat message;
  final ValueChanged<String> onAccion;

  const _ChatBubble({required this.message, required this.onAccion});

  @override
  Widget build(BuildContext context) {
    final alignment = message.esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.esUsuario ? AppColors.primaryGreen : const Color(0xFFF3F4F6);
    final textColor = message.esUsuario ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomLeft: message.esUsuario ? null : const Radius.circular(0),
                bottomRight: message.esUsuario ? const Radius.circular(0) : null,
              ),
            ),
            child: Text(
              message.texto,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
            ),
          ),
          if (message.acciones.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: message.acciones.map((btnText) {
                return OutlinedButton(
                  onPressed: () => onAccion(btnText),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                    foregroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  ),
                  child: Text(btnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ]
        ],
      ),
    );
  }
}

class _MensajeDeError extends StatelessWidget {
  const _MensajeDeError({required this.mensaje, this.onReintentar});

  final String mensaje;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                mensaje,
                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
              ),
            ),
            if (onReintentar != null) ...[
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: onReintentar,
                child: const Text('Reintentar', style: TextStyle(fontSize: 13)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
        ),
        child: const Text('• • •', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
