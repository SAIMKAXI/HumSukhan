import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../l10n/app_strings.dart';

// ===== STATUS INDICATOR =====
class StatusIndicator extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;
  final IconData icon;
  const StatusIndicator({super.key, required this.label, required this.color, this.isActive = false, this.icon = Icons.circle});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: isActive ? color : AppTokens.mutedSageGray),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isActive ? color : AppTokens.mutedSageGray)),
    ]);
  }
}

// ===== LANGUAGE BADGE =====
class LanguageBadge extends StatelessWidget {
  final String language;
  const LanguageBadge({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTokens.deepSage.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Text(language, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTokens.deepSage)),
    );
  }
}

// ===== OFFLINE BADGE =====
class OfflineBadge extends StatelessWidget {
  final bool isOnline;
  const OfflineBadge({super.key, this.isOnline = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline ? AppTokens.deepSage.withValues(alpha: 0.1) : AppTokens.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 14,
            color: isOnline ? AppTokens.deepSage : AppTokens.warning),
        const SizedBox(width: 4),
        Text(isOnline ? 'Online' : 'Offline',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: isOnline ? AppTokens.deepSage : AppTokens.warning)),
      ]),
    );
  }
}

// ===== QUICK REPLY CHIP =====
class QuickReplyChip extends StatelessWidget {
  final QuickReply reply;
  final VoidCallback onTap;
  final bool isHighContrast;
  const QuickReplyChip({super.key, required this.reply, required this.onTap, this.isHighContrast = false});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(reply.text, style: TextStyle(color: isHighContrast ? AppTokens.warmIvory : AppTokens.textDeepForest, fontWeight: FontWeight.w500)),
      avatar: reply.isFavorite ? const Icon(Icons.star, size: 16, color: AppTokens.warning) : null,
      backgroundColor: isHighContrast ? AppTokens.darkForest : AppTokens.softCream,
      side: BorderSide(color: isHighContrast ? AppTokens.softSage : AppTokens.borderSage),
      onPressed: onTap,
    );
  }
}

// ===== RETENTION BADGE =====
class RetentionBadge extends StatelessWidget {
  final int daysRemaining;
  const RetentionBadge({super.key, required this.daysRemaining});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    Color bgColor; Color textColor; String text;
    if (daysRemaining <= 2) { bgColor = AppTokens.error.withValues(alpha: 0.1); textColor = AppTokens.error; text = '$daysRemaining ${s.daysLeft}'; }
    else if (daysRemaining <= 7) { bgColor = AppTokens.warning.withValues(alpha: 0.1); textColor = AppTokens.warning; text = '$daysRemaining ${s.daysLeft}'; }
    else { bgColor = AppTokens.deepSage.withValues(alpha: 0.1); textColor = AppTokens.deepSage; text = '$daysRemaining ${s.daysLeft}'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(AppTokens.radiusFull)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ===== SESSION CARD =====
class SessionCard extends StatelessWidget {
  final ProfessionalSession session;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final ProfessionalInsight? insight;
  const SessionCard({super.key, required this.session, required this.onTap, this.onDelete, this.insight});

  IconData _typeIcon() => switch (session.type) {
    SessionType.meeting => Icons.meeting_room,
    SessionType.lecture => Icons.school,
    SessionType.class_ => Icons.class_,
  };

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(_typeIcon(), size: 20, color: AppTokens.deepSage),
              const SizedBox(width: 8),
              Expanded(child: Text(session.title, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppTokens.textDeepForest,
              ), maxLines: 1, overflow: TextOverflow.ellipsis)),
              RetentionBadge(daysRemaining: session.daysRemaining),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 14, color: AppTokens.textMuted),
              const SizedBox(width: 4),
              Text('${session.createdAt.day}/${session.createdAt.month}/${session.createdAt.year}',
                  style: const TextStyle(fontSize: 12, color: AppTokens.textMuted)),
              const SizedBox(width: 16),
              Icon(Icons.subtitles, size: 14, color: AppTokens.textMuted),
              const SizedBox(width: 4),
              Text('${session.captions.length} ${s.captionsLabel}',
                  style: const TextStyle(fontSize: 12, color: AppTokens.textMuted)),
              if (insight != null && insight!.isAvailable) ...[
                const SizedBox(width: 16),
                const Icon(Icons.auto_awesome, size: 14, color: AppTokens.deepSage),
                const SizedBox(width: 4),
                Text(s.aiInsights, style: const TextStyle(fontSize: 12, color: AppTokens.deepSage)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}

// ===== INSIGHT CARD =====
class InsightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color? iconColor;
  const InsightCard({super.key, required this.title, required this.icon, required this.items, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: iconColor ?? AppTokens.deepSage),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTokens.textDeepForest)),
          ]),
          const SizedBox(height: 12),
          if (items.isEmpty) Text(s.noItemsAvailable, style: const TextStyle(color: AppTokens.textMuted, fontSize: 13))
          else ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('• ', style: TextStyle(fontSize: 16, color: AppTokens.deepSage)),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 14, color: AppTokens.textDeepForest))),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ===== ALERT CARD =====
class AlertCard extends StatelessWidget {
  final SoundEvent event;
  final VoidCallback? onDismiss;
  const AlertCard({super.key, required this.event, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final severityColor = AppTheme.alertColor(event.severity);
    return Card(
      child: ListTile(
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: severityColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
          child: Icon(_alertIcon(event.type), color: severityColor, size: 24),
        ),
        title: Text(event.type, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTokens.textDeepForest)),
        subtitle: Text('${(event.confidence * 100).toInt()}% confidence • ${_formatTime(event.timestamp)}',
            style: const TextStyle(fontSize: 12, color: AppTokens.textMuted)),
        trailing: event.dismissed
            ? const Icon(Icons.check_circle, color: AppTokens.deepSage, size: 20)
            : IconButton(icon: const Icon(Icons.close, size: 20, color: AppTokens.mutedSageGray), onPressed: onDismiss),
      ),
    );
  }

  IconData _alertIcon(String type) => switch (type) {
    'Fire Alarm' || 'Smoke Alarm' => Icons.local_fire_department,
    'Siren' => Icons.emergency,
    'Doorbell' => Icons.doorbell,
    'Knock' => Icons.back_hand,
    'Phone' => Icons.phone,
    'Alarm Clock' => Icons.alarm,
    'Baby Cry' => Icons.child_care,
    _ => Icons.volume_up,
  };

  String _formatTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ===== EMPTY STATE =====
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle, this.buttonText, this.onButtonPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: AppTokens.mutedSageGray),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTokens.textDeepForest), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppTokens.textMuted), textAlign: TextAlign.center),
          if (buttonText != null && onButtonPressed != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onButtonPressed,
              icon: const Icon(Icons.add),
              label: Text(buttonText!),
              style: ElevatedButton.styleFrom(backgroundColor: AppTokens.deepSage, foregroundColor: AppTokens.warmIvory),
            ),
          ],
        ]),
      ),
    );
  }
}

// ===== AI DISCLAIMER =====
class AiDisclaimer extends StatelessWidget {
  const AiDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        border: Border.all(color: AppTokens.warning.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.auto_awesome, size: 16, color: AppTokens.warning),
        const SizedBox(width: 8),
        Expanded(child: Text(s.aiDisclaimer,
            style: const TextStyle(fontSize: 12, color: AppTokens.warning, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ===== PRIVACY NOTICE =====
class PrivacyNotice extends StatelessWidget {
  final String text;
  const PrivacyNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.deepSage.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(children: [
        const Icon(Icons.shield, size: 16, color: AppTokens.deepSage),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: AppTokens.deepSage))),
      ]),
    );
  }
}

// ===== PRIMARY BUTTON =====
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isExpanded;
  const PrimaryActionButton({super.key, required this.label, required this.onPressed, this.icon, this.isExpanded = true});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.deepSage,
        foregroundColor: AppTokens.warmIvory,
        minimumSize: Size(isExpanded ? double.infinity : 0, 52),
      ),
    );
  }
}

// ===== SECONDARY BUTTON =====
class SecondaryActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  const SecondaryActionButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppTokens.deepSage),
      label: Text(label, style: const TextStyle(color: AppTokens.deepSage)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        side: const BorderSide(color: AppTokens.deepSage),
      ),
    );
  }
}

// ===== CAPTION BUBBLE =====
class CaptionBubble extends StatelessWidget {
  final Caption caption;
  final double textSize;
  final bool isHighContrast;
  const CaptionBubble({super.key, required this.caption, this.textSize = 16.0, this.isHighContrast = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = AppTheme.captionBubbleColor(isOwn: caption.isOwn, isDarkMode: isDark);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: caption.isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(caption.speaker, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.deepSage)),
              const SizedBox(width: 8),
              Text('${caption.timestamp.hour.toString().padLeft(2, '0')}:${caption.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: AppTokens.textMuted)),
            ]),
          ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(caption.isOwn ? 16 : 4),
                bottomRight: Radius.circular(caption.isOwn ? 4 : 16),
              ),
              border: isHighContrast ? Border.all(color: AppTokens.pureWhite, width: 1) : null,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(caption.text, style: TextStyle(
                fontSize: textSize,
                color: isHighContrast ? AppTokens.pureWhite : AppTokens.textDeepForest,
                fontWeight: caption.isPartial ? FontWeight.normal : FontWeight.w500,
                fontStyle: caption.isPartial ? FontStyle.italic : FontStyle.normal,
              )),
              if (caption.language.isNotEmpty && caption.language != 'English')
                Padding(padding: const EdgeInsets.only(top: 4), child: LanguageBadge(language: caption.language)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ===== ERROR STATE =====
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onRetry;
  const ErrorState({super.key, required this.title, required this.message, this.buttonText, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 64, color: AppTokens.error),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTokens.textDeepForest), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 14, color: AppTokens.textMuted), textAlign: TextAlign.center),
          if (buttonText != null && onRetry != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(buttonText!),),
          ],
        ]),
      ),
    );
  }
}
