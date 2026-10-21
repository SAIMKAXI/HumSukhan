import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/quick_reply_provider.dart';

/// Favourite or delete one quick reply. Opened by long-pressing its chip.
Future<void> showQuickReplyActions(BuildContext context, QuickReply reply) {
  final s = AppStrings.of(context);
  final replies = context.read<QuickReplyProvider>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(reply.text, style: Theme.of(sheetContext).textTheme.titleMedium, textAlign: TextAlign.center),
          ),
          ListTile(
            leading: Icon(reply.isFavorite ? Icons.star_border : Icons.star),
            title: Text(reply.isFavorite ? s.removeFromFavourites : s.addToFavourites),
            onTap: () {
              Navigator.pop(sheetContext);
              replies.toggleFavorite(reply.id);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(sheetContext).colorScheme.error),
            title: Text(s.deleteAction, style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
            onTap: () {
              Navigator.pop(sheetContext);
              replies.deleteReply(reply.id);
            },
          ),
        ],
      ),
    ),
  );
}

/// Add, favourite and delete quick replies. Opened from Settings.
Future<void> showQuickReplyManager(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const QuickReplyManager(),
    );

class QuickReplyManager extends StatefulWidget {
  const QuickReplyManager({super.key});

  @override
  State<QuickReplyManager> createState() => _QuickReplyManagerState();
}

class _QuickReplyManagerState extends State<QuickReplyManager> {
  final TextEditingController _newReply = TextEditingController();

  @override
  void dispose() {
    _newReply.dispose();
    super.dispose();
  }

  Future<void> _add(QuickReplyProvider replies) async {
    final text = _newReply.text.trim();
    if (text.isEmpty) return;
    _newReply.clear();
    await replies.addReply(text);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final replies = context.watch<QuickReplyProvider>();
    final items = replies.orderedReplies;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(s.manageQuickReplies, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(s.manageQuickRepliesDesc, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newReply,
                      decoration: InputDecoration(hintText: s.addQuickReplyHint),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(replies),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: () => _add(replies), icon: const Icon(Icons.add), label: Text(s.addAction)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? Center(child: Text(s.noQuickReplies))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final reply = items[i];
                        return ListTile(
                          title: Text(reply.text),
                          leading: IconButton(
                            icon: Icon(reply.isFavorite ? Icons.star : Icons.star_border,
                                color: reply.isFavorite ? Colors.amber.shade700 : null),
                            tooltip: reply.isFavorite ? s.removeFromFavourites : s.addToFavourites,
                            onPressed: () => replies.toggleFavorite(reply.id),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: s.deleteAction,
                            onPressed: () => replies.deleteReply(reply.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
