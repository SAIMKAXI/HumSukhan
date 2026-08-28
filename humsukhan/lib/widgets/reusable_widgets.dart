import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

// ===================== STATUS INDICATOR =====================
class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final IconData icon;

  const StatusIndicator({
    super.key,
    required this.label,
    required this.color,
    this.isActive = false,
    this.icon = Icons.circle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: isActive ? color : Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          color: isActive ? color : Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        )),
      ],
    );
  }
}

// ===================== CAPTION BUBBLE =====================
class CaptionBubble extends StatelessWidget {
  final Caption caption;
  final double textSize;
  final bool isHighContrast;

  const CaptionBubble({
    super.key,
    required this.caption,
    this.textSize = 16.0,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = AppTheme.captionBubbleColor(
      isOwn: caption.isOwn,
      isDarkMode: isDark,
      isHighContrast: isHighContrast,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: caption.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  caption.speaker,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: caption.isOwn
                        ? Colors.blue[300]
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
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
              border: isHighContrast
                  ? Border.all(color: Colors.white, width: 1)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption.text,
                  style: TextStyle(
                    fontSize: textSize,
                    color: isHighContrast
                        ? Colors.white
                        : Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: caption.isPartial ? FontWeight.normal : FontWeight.w500,
                    fontStyle: caption.isPartial ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (caption.language.isNotEmpty && caption.language != 'English')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LanguageBadge(language: caption.language),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== LANGUAGE BADGE =====================
class LanguageBadge extends StatelessWidget {
  final String language;
  const LanguageBadge({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        language,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ===================== OFFLINE BADGE =====================
class OfflineBadge extends StatelessWidget {
  final bool isOnline;
  const OfflineBadge({super.key, this.isOnline = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? AppTheme.successLight.withValues(alpha: 0.15)
            : AppTheme.warningLight.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.wifi_off,
            size: 14,
            color: isOnline ? AppTheme.successLight : AppTheme.warningLight,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppTheme.successLight : AppTheme.warningLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== QUICK REPLY CHIP =====================
class QuickReplyChip extends StatelessWidget {
  final QuickReply reply;
  final VoidCallback onTap;
  final bool isHighContrast;

  const QuickReplyChip({
    super.key,
    required this.reply,
    required this.onTap,
    this.isHighContrast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        reply.text,
        style: TextStyle(
          color: isHighContrast ? Colors.white : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      avatar: reply.isFavorite
          ? Icon(Icons.star, size: 16, color: AppTheme.warningLight)
          : null,
      backgroundColor: isHighContrast ? Colors.grey[800] : null,
      side: isHighContrast ? const BorderSide(color: Colors.white, width: 1) : null,
      onPressed: onTap,
    );
  }
}

// ===================== RETENTION BADGE =====================
class RetentionBadge extends StatelessWidget {
  final int daysRemaining;
  const RetentionBadge({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String text;

    if (daysRemaining <= 2) {
      bgColor = AppTheme.errorLight.withValues(alpha: 0.15);
      textColor = AppTheme.errorLight;
      text = '$daysRemaining days left';
    } else if (daysRemaining <= 7) {
      bgColor = AppTheme.warningLight.withValues(alpha: 0.15);
      textColor = AppTheme.warningLight;
      text = '$daysRemaining days left';
    } else {
      bgColor = AppTheme.successLight.withValues(alpha: 0.15);
      textColor = AppTheme.successLight;
      text = '$daysRemaining days left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

// ===================== SESSION CARD =====================
class SessionCard extends StatelessWidget {
  final ProfessionalSession session;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final ProfessionalInsight? insight;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onDelete,
    this.insight,
  });

  IconData _typeIcon() {
    switch (session.type) {
      case SessionType.meeting:
        return Icons.meeting_room;
      case SessionType.lecture:
        return Icons.school;
      case SessionType.class_:
        return Icons.class_;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(), size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      session.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  RetentionBadge(daysRemaining: session.daysRemaining),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.subtitles, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${session.captions.length} captions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (insight != null && insight!.isAvailable) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.secondaryLight),
                    const SizedBox(width: 4),
                    Text('Insights', style: TextStyle(fontSize: 12, color: AppTheme.secondaryLight)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== INSIGHT CARD =====================
class InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? iconColor;

  const InsightCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor ?? Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text('No items available', style: Theme.of(context).textTheme.bodySmall)
            else
              ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(item, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}

// ===================== ALERT CARD =====================
class AlertCard extends StatelessWidget {
  final SoundEvent event;
  final VoidCallback? onDismiss;

  const AlertCard({super.key, required this.event, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.alertColor(event.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: severityColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          ),
          child: Icon(_alertIcon(event.type), color: severityColor, size: 24),
        ),
        title: Text(event.type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${(event.confidence * 100).toInt()}% confidence • ${_formatTime(event.timestamp)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: event.dismissed
            ? Icon(Icons.check_circle, color: AppTheme.successLight, size: 20)
            : IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: onDismiss,
              ),
      ),
    );
  }

  IconData _alertIcon(String type) {
    switch (type) {
      case 'Fire Alarm':
      case 'Smoke Alarm':
        return Icons.local_fire_department;
      case 'Siren':
        return Icons.emergency;
      case 'Doorbell':
        return Icons.doorbell;
      case 'Knock':
        return Icons.back_hand;
      case 'Phone':
        return Icons.phone;
      case 'Alarm Clock':
        return Icons.alarm;
      case 'Baby Cry':
        return Icons.child_care;
      default:
        return Icons.volume_up;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ===================== EMPTY STATE =====================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add),
                label: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== ERROR STATE =====================
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.buttonText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorLight),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            if (buttonText != null && onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(buttonText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== AI DISCLAIMER =====================
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warningLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: AppTheme.warningLight.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 16, color: AppTheme.warningLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI-generated — may contain errors',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.warningLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== PRIVACY NOTICE =====================
class PrivacyNotice extends StatelessWidget {
  final String text;
  const PrivacyNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== PRIMARY ACTION BUTTON =====================
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isExpanded;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(isExpanded ? double.infinity : 0, 52),
      ),
    );
    return isExpanded ? button : button;
  }
}

// ===================== SECONDARY ACTION BUTTON =====================
class SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const SecondaryActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
