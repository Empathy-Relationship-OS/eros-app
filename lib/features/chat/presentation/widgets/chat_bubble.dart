import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';

/// One message: mine on the right in orange, the partner's on the left in white.
///
/// Under my messages it shows "Sending" while on the way, and "Not sent, tap to retry"
/// when it failed. [onRetry] is null when the chat can't send any more, and then the
/// failed line just says "Not sent".
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final fromMe = message.fromMe;
    final failed = message.sendState == ChatSendState.failed;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fromMe ? AppColors.primary : AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(fromMe ? 16 : 4),
          bottomRight: Radius.circular(fromMe ? 4 : 16),
        ),
        border: failed ? Border.all(color: AppColors.error) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        message.text,
        style: TextStyle(
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
          _buildCaption(),
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

  Widget _buildCaption() {
    switch (message.sendState) {
      case ChatSendState.sending:
        return const Text(
          ChatCopy.sending,
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        );
      case ChatSendState.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              onRetry != null ? ChatCopy.notSentRetry : ChatCopy.notSent,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        );
      case ChatSendState.sent:
        return Text(
          DateFormat('HH:mm').format(message.createdAt.toLocal()),
          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
        );
    }
  }
}
