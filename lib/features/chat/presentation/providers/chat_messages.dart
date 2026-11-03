import 'package:eros_app/features/chat/data/models/chat_models.dart';

/// Pure list operations for the messages a chat screen holds (primer rule 18).
///
/// The list is always the server's messages ascending by `seq`, followed by this device's
/// unconfirmed messages (sending or failed) in the order they were written. No two entries
/// share a `seq`, and no two share a `clientMessageId`, so refetching never duplicates a
/// bubble.
class ChatMessages {
  ChatMessages._();

  /// Merges [incoming] server messages into [current] by `seq`.
  ///
  /// A message already held keeps its place and its `clientMessageId`. A message from me
  /// that isn't held yet first looks for one of this device's unconfirmed messages with the
  /// same content, oldest first, and takes its place. That covers a poll that returns a
  /// message before its own send has answered, and a send that timed out on the way back
  /// after the server stored it.
  static List<ChatMessage> merge(List<ChatMessage> current, Iterable<ChatMessage> incoming) {
    final bySeq = <int, ChatMessage>{
      for (final m in current)
        if (m.seq != null) m.seq!: m,
    };
    final unconfirmed = [
      for (final m in current)
        if (m.seq == null) m,
    ];

    final sorted = incoming.where((m) => m.seq != null).toList()
      ..sort((a, b) => a.seq!.compareTo(b.seq!));
    for (final message in sorted) {
      final held = bySeq[message.seq!];
      if (held != null) {
        bySeq[message.seq!] = message.copyWith(clientMessageId: held.clientMessageId);
        continue;
      }
      final paired = unconfirmed.indexWhere(message.sameContentAs);
      if (paired >= 0) {
        final local = unconfirmed.removeAt(paired);
        bySeq[message.seq!] = message.copyWith(clientMessageId: local.clientMessageId);
      } else {
        bySeq[message.seq!] = message;
      }
    }

    return _assemble(bySeq, unconfirmed);
  }

  /// Applies the server's answer to sending [clientMessageId]: the unconfirmed message
  /// becomes [sent].
  ///
  /// If a poll already brought [sent] in, the unconfirmed copy is simply dropped.
  static List<ChatMessage> confirm(
    List<ChatMessage> current,
    String clientMessageId,
    ChatMessage sent,
  ) {
    final alreadyPaired = current.any((m) => m.seq != null && m.clientMessageId == clientMessageId);
    final remaining = [
      for (final m in current)
        if (!(m.seq == null && m.clientMessageId == clientMessageId)) m,
    ];
    if (alreadyPaired) {
      // Paired by a poll, possibly with an identical message's seq. Make sure the seq the
      // server just gave is held too, then the list is complete.
      return merge(remaining, [sent]);
    }
    return merge(remaining, [sent.copyWith(clientMessageId: clientMessageId)]);
  }

  /// Sets the send state of the unconfirmed message [clientMessageId]. A message the
  /// server already confirmed is left alone.
  static List<ChatMessage> markSendState(
    List<ChatMessage> current,
    String clientMessageId,
    ChatSendState sendState,
  ) =>
      [
        for (final m in current)
          if (m.seq == null && m.clientMessageId == clientMessageId)
            m.copyWith(sendState: sendState)
          else
            m,
      ];

  /// Removes the unconfirmed message [clientMessageId] (the server refused it for good).
  static List<ChatMessage> remove(List<ChatMessage> current, String clientMessageId) => [
        for (final m in current)
          if (!(m.seq == null && m.clientMessageId == clientMessageId)) m,
      ];

  static List<ChatMessage> _assemble(Map<int, ChatMessage> bySeq, List<ChatMessage> unconfirmed) {
    final confirmed = bySeq.values.toList()..sort((a, b) => a.seq!.compareTo(b.seq!));
    return [...confirmed, ...unconfirmed];
  }
}
