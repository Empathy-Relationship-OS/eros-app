import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';

/// One message: mine on the right on coral, the partner's on the left on white.
///
/// Under my messages it shows "Sending" while on the way, and "Not sent, tap to retry"
/// when it failed. [onRetry] is null when the chat can't send any more, and then the
/// failed line just says "Not sent". [seen] adds "Seen" under the time, on my newest
/// message the partner has read.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final bool seen;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.seen = false,
  });

  @override
  Widget build(BuildContext context) {
    final fromMe = message.fromMe;
    final failed = message.sendState == ChatSendState.failed;
    final textTheme = Theme.of(context).textTheme;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fromMe ? AppColors.primary : AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(fromMe ? 18 : 4),
          bottomRight: Radius.circular(fromMe ? 4 : 18),
        ),
        // A failed message is outlined in red. The partner's white bubble gets a hairline, so
        // it reads against the cream page without a shadow.
        border: failed
            ? Border.all(color: AppColors.error)
            : (fromMe ? null : Border.all(color: AppColors.divider)),
      ),
      child: Text(
        message.text,
        style: textTheme.bodyLarge?.copyWith(
          fontSize: 15,
          height: 1.35,
          color: fromMe ? AppColors.textOnPrimary : AppColors.textPrimary,
        ),
      ),
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: message.sendState == ChatSendState.sending ? 0.7 : 1,
            child: bubble,
          ),
          const SizedBox(height: 4),
          _buildCaption(textTheme),
          if (seen)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(ChatCopy.seen, style: textTheme.bodySmall),
            ),
        ],
      ),
    );

    if (failed && onRetry != null) {
      return Semantics(
        button: true,
        label: ChatCopy.notSentRetry,
        child: InkWell(onTap: onRetry, child: content),
      );
    }
    return content;
  }

  Widget _buildCaption(TextTheme textTheme) {
    final quiet = textTheme.bodySmall?.copyWith(color: AppColors.textTertiary, height: 1.3);
    switch (message.sendState) {
      case ChatSendState.sending:
        return Text(ChatCopy.sending, style: quiet);
      case ChatSendState.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              onRetry != null ? ChatCopy.notSentRetry : ChatCopy.notSent,
              style: quiet?.copyWith(color: AppColors.error),
            ),
          ],
        );
      case ChatSendState.sent:
        return Text(
          DateFormat('HH:mm').format(message.createdAt.toLocal()),
          style: quiet,
        );
    }
  }
}
