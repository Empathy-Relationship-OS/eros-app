import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';

/// A horizontal row of the server's quick replies, above the input (RFC-006 §6.2).
///
/// The replies come from `GET /dates/{dateId}/chat`. The app hard-codes none (primer
/// rule 21). A tap sends straight away.
class QuickReplyChips extends StatelessWidget {
  final List<QuickReply> replies;
  final ValueChanged<QuickReply> onSelected;

  const QuickReplyChips({
    super.key,
    required this.replies,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (replies.isEmpty) return const SizedBox.shrink();

    return Semantics(
      container: true,
      label: ChatCopy.quickReplies,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: replies.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final reply = replies[index];
            return ActionChip(
              key: ValueKey('quick-reply-${reply.key}'),
              label: Text(reply.text),
              onPressed: () => onSelected(reply),
              backgroundColor: AppColors.background,
              side: const BorderSide(color: AppColors.primary),
              labelStyle: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            );
          },
        ),
      ),
    );
  }
}
