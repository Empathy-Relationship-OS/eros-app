import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:eros_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';

/// The way into the chat from date detail (RFC-006 §6.1).
///
/// Driven by `chat.status` alone, so it stays through a venue change that moves the date
/// back to `VENUE_ASSIGNED`:
///
/// | Status     | Shown                                                         |
/// |------------|---------------------------------------------------------------|
/// | `NOT_OPEN` | Nothing, or the "once you've both confirmed" line while the   |
/// |            | date awaits presence confirmation                             |
/// | `OPEN`     | "Message {name}" button, with an unread dot                   |
/// | `CLOSED`   | A quiet "View messages" link                                  |
/// | `ARCHIVED` | Nothing                                                       |
///
/// Renders nothing at all when there's nothing to show, so it sits above the CTA content
/// without adding space.
class DateChatEntry extends ConsumerWidget {
  final DateDetail dateDetail;

  const DateChatEntry({super.key, required this.dateDetail});

  /// Extra height the entry takes in the CTA panel, for the scroll spacer above it.
  static double reservedHeight(ChatSummary chat) {
    switch (chat.status) {
      case ChatStatus.open:
        return 64;
      case ChatStatus.closed:
        return 48;
      case ChatStatus.notOpen:
      case ChatStatus.archived:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (dateDetail.chat.status) {
      case ChatStatus.open:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _MessageButton(dateDetail: dateDetail),
        );
      case ChatStatus.closed:
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: TextButton(
            onPressed: () => openChat(context, ref, dateDetail),
            child: const Text(ChatCopy.viewMessages),
          ),
        );
      case ChatStatus.notOpen:
        if (dateDetail.state != DateState.awaitingPresenceConfirmation) {
          return const SizedBox.shrink();
        }
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            ChatCopy.opensAfterConfirming,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        );
      case ChatStatus.archived:
        return const SizedBox.shrink();
    }
  }

  /// Opens the chat screen, then refreshes the date and the unread count on the way back.
  static Future<void> openChat(BuildContext context, WidgetRef ref, DateDetail dateDetail) async {
    final dateId = dateDetail.dateId.toString();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: ChatScreen.routeName, arguments: dateId),
        builder: (context) => ChatScreen(dateId: dateId),
      ),
    );
    if (!context.mounted) return;
    ref.invalidate(chatStatusProvider(dateId));
    ref.read(dateDetailProvider(dateId).notifier).refresh();
  }
}

class _MessageButton extends ConsumerWidget {
  final DateDetail dateDetail;

  const _MessageButton({required this.dateDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateId = dateDetail.dateId.toString();
    final unread = ref.watch(chatStatusProvider(dateId)).valueOrNull?.unreadCount ?? 0;

    return ElevatedButton(
      onPressed: () => DateChatEntry.openChat(context, ref, dateDetail),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              ChatCopy.messagePartner(dateDetail.partnerName),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Semantics(
              label: ChatCopy.unreadMessages,
              child: Container(
                key: const ValueKey('chat-unread-dot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryOrangeDark, width: 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
