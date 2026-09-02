import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/mixed_transcript_parser.dart';
import '../theme/app_theme.dart';

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

  TextSpan _captionSpan(List<CaptionSegment> segments, Color color) {
    final children = <TextSpan>[];
    for (final segment in segments) {
      final mark = segment.isRtl ? '\u200F' : '\u200E';
      children.add(TextSpan(text: '$mark${segment.text}$mark '));
    }
    return TextSpan(
      style: TextStyle(
        fontSize: textSize,
        color: color,
        fontWeight: caption.isPartial ? FontWeight.normal : FontWeight.w500,
        fontStyle: caption.isPartial ? FontStyle.italic : FontStyle.normal,
      ),
      children: children,
    );
  }

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
    final segments = caption.segments.isNotEmpty
        ? caption.segments
        : MixedTranscriptParser.parse(caption.text, fallbackLanguage: caption.language);

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
                  child: Text.rich(
                    _captionSpan(segments, textColor),
                    textDirection: TextDirection.ltr,
                    softWrap: true,
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
