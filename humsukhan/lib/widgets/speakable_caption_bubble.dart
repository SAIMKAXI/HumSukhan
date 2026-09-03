import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'mixed_script_caption_text.dart';

class SpeakableCaptionBubble extends StatelessWidget {
  final Caption caption;
  final double textSize;
  final bool isHighContrast;

  const SpeakableCaptionBubble({
    super.key,
    required this.caption,
    this.textSize = 16,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bubbleColor = isHighContrast
        ? Colors.black
        : AppTheme.captionBubbleColor(isOwn: caption.isOwn, isDarkMode: isDark);
    final textColor = isHighContrast ? Colors.white : theme.colorScheme.onSurface;
    final canSpeak = caption.text.trim().isNotEmpty;
    final isThisMessageSpeaking = speech.isSpeaking && speech.lastSpokenText == caption.text;
    final captionStyle = TextStyle(
      fontSize: textSize,
      color: textColor,
      fontWeight: caption.isPartial ? FontWeight.normal : FontWeight.w500,
      fontStyle: caption.isPartial ? FontStyle.italic : FontStyle.normal,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: Column(
        crossAxisAlignment: caption.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '${caption.speaker} · ${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Row(
            mainAxisAlignment: caption.isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .68,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(caption.isOwn ? 16 : 4),
                      bottomRight: Radius.circular(caption.isOwn ? 4 : 16),
                    ),
                    border: isHighContrast ? Border.all(color: Colors.white) : null,
                  ),
                  child: MixedScriptCaptionText(
                    caption.text,
                    style: captionStyle,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                tooltip: isThisMessageSpeaking ? 'Stop speaking' : 'Speak this message',
                icon: Icon(
                  isThisMessageSpeaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  color: canSpeak ? theme.colorScheme.primary : theme.colorScheme.outline,
                  size: 22,
                ),
                onPressed: !canSpeak
                    ? null
                    : () async {
                        if (isThisMessageSpeaking) {
                          await speech.stopSpeaking();
                        } else {
                          await speech.speak(caption.text, language: caption.language);
                        }
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
