import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/status_badge.dart'; // Contiene EcoCard y SectionLabel
import '../../../landing/presentation/widgets/landing_footer.dart';
import '../../../landing/presentation/widgets/landing_header.dart';

// Modelo local temporal para pintar el flujo visual del chat
class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String>? actionButtons;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.actionButtons,
  });
}

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  bool _menuOpen = false;
  final TextEditingController _textController = TextEditingController();

  // Historial de mensajes idéntico a tu captura de pantalla
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: '¡Hola! Soy tu asistente ambiental. Hoy el AQI promedio en Cali es 52 (Moderado). ¿En qué puedo ayudarte?',
      isUser: false,
    ),
    const _ChatMessage(
      text: '¿Es seguro salir a trotar por el barrio San Fernando ahora?',
      isUser: true,
    ),
    const _ChatMessage(
      text: 'El sensor de San Fernando registra actualmente AQI 18 (Bueno), uno de los más limpios de la ciudad. Es un excelente momento para trotar. Te recomiendo evitar la Av. Roosevelt por el tráfico.',
      isUser: false,
      actionButtons: ['Ver mapa de Cali', 'Recomendación de hoy', 'Comparar sensores'],
    ),
    const _ChatMessage(
      text: 'Gracias, ¿y mañana cómo estará?',
      isUser: true,
    ),
  ];

  final List<String> _preguntasFrecuentes = [
    '¿Puedo hacer ejercicio hoy?',
    'Explícame qué es PM2.5',
    '¿Cuál es el sensor más cercano?',
  ];

  @override
  Widget build(BuildContext context) {
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
                    const _AsistenteHeaderSection(),
                    
                    // Container central para que el chat mantenga el ancho max web de tu diseño
                    ContentContainer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            const Center(
                              child: Text(
                                'Hoy - 10:42 AM',
                                style: TextStyle(color: Colors.grey, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // 2. Lista de burbujas de mensajes
                            ..._messages.map((msg) => _ChatBubble(message: msg)),

                            // 3. Indicador visual de "escribiendo..." (...)
                            const _TypingIndicator(),
                            const SizedBox(height: AppSpacing.xl),

                            // 4. Preguntas frecuentes sugeridas
                            const SectionLabel(text: 'PREGUNTAS FRECUENTES'),
                            const SizedBox(height: AppSpacing.sm),
                            _buildPreguntasSugeridas(),
                            const SizedBox(height: AppSpacing.xl),

                            // 5. Input Bar (Caja de Texto y Botón Enviar)
                            _buildInputBar(),
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
  Widget _buildPreguntasSugeridas() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: _preguntasFrecuentes.map((text) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        );
      }).toList(),
    );
  }

  // Widget: Chat/InputBar (Diseño encapsulado en EcoCard según tu captura)
  Widget _buildInputBar() {
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
                  decoration: InputDecoration(
                    hintText: 'Escribe tu pregunta sobre la calidad del aire...',
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
                onPressed: () {
                  if (_textController.text.isNotEmpty) {
                    setState(() {
                      _messages.add(_ChatMessage(text: _textController.text, isUser: true));
                      _textController.clear();
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: const Text('Enviar', style: TextStyle(fontWeight: FontWeight.bold)),
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
  const _AsistenteHeaderSection();

  @override
  Widget build(BuildContext context) {
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
                // Cambiamos el fondo del ícono a un tono grisáceo suave
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.spa, color: Colors.grey, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
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
                      decoration: const BoxDecoration(
                        color: Colors.grey, // ◄─ Cambiamos el círculo a gris (Offline)
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Fuera de línea · Modo de demostración visual', // ◄─ Texto honesto para el usuario
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = message.isUser ? AppColors.primaryGreen : const Color(0xFFF3F4F6);
    final textColor = message.isUser ? Colors.white : Colors.black87;

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
                bottomLeft: message.isUser ? null : const Radius.circular(0),
                bottomRight: message.isUser ? const Radius.circular(0) : null,
              ),
            ),
            child: Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
            ),
          ),
          if (message.actionButtons != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: message.actionButtons!.map((btnText) {
                return OutlinedButton(
                  onPressed: () {},
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