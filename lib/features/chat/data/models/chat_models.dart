/// Chat models for the date chat (RFC-006 §5 "Chat")
///
/// Wire conventions match the dates models: enums are UPPER_SNAKE strings, instants are
/// ISO-8601 UTC strings, and nullable fields are present as null.
///
/// Message text is private (RFC-006 §4.11). Nothing in this file has a `toString` that
/// includes it, so a model printed by accident never leaks a message.
library;

// ====================
// ENUMS
// ====================

/// Whether the chat can be read and written (RFC-006 §4.1).
///
/// The backend decides this. The app never works it out from `DateState` (primer rule 17).
enum ChatStatus {
  notOpen,
  open,
  closed,
  archived;

  /// Reads the wire value. An unknown or missing value from a newer backend reads as
  /// [closed]: read-only is the safe guess, and it never crashes.
  static ChatStatus fromWire(Object? wire) {
    switch (wire) {
      case 'NOT_OPEN':
        return ChatStatus.notOpen;
      case 'OPEN':
        return ChatStatus.open;
      case 'CLOSED':
        return ChatStatus.closed;
      case 'ARCHIVED':
        return ChatStatus.archived;
      default:
        return ChatStatus.closed;
    }
  }

  /// Messages can be fetched (`OPEN` and `CLOSED`).
  bool get isReadable => this == ChatStatus.open || this == ChatStatus.closed;
}

/// How a message was written. An unknown kind from a newer backend shows as [text].
enum ChatMessageKind {
  text,
  quickReply;

  static ChatMessageKind fromWire(Object? wire) =>
      wire == 'QUICK_REPLY' ? ChatMessageKind.quickReply : ChatMessageKind.text;
}

/// Where a message the user wrote is on its way to the server.
///
/// Messages from the server are always [sent].
enum ChatSendState {
  sending,
  sent,
  failed,
}

DateTime? _instant(Object? v) => v == null ? null : DateTime.parse(v as String);

// ====================
// MODELS
// ====================

/// The chat part of `DateDetailDTO` (RFC-006 §5 "Dates").
class ChatSummary {
  final ChatStatus status;
  final DateTime? closesAt;
  final DateTime? readableUntil;

  const ChatSummary({
    required this.status,
    this.closesAt,
    this.readableUntil,
  });

  /// Used when the backend doesn't send `chat` yet (before CH-B1 is deployed).
  static const ChatSummary notOpen = ChatSummary(status: ChatStatus.notOpen);

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
        status: ChatStatus.fromWire(json['status']),
        closesAt: _instant(json['closesAt']),
        readableUntil: _instant(json['readableUntil']),
      );
}

/// A server-defined quick reply (RFC-006 §4.4). The app hard-codes none (primer rule 21).
class QuickReply {
  final String key;
  final String text;

  const QuickReply({required this.key, required this.text});

  factory QuickReply.fromJson(Map<String, dynamic> json) => QuickReply(
        key: json['key'] as String,
        text: json['text'] as String,
      );
}

/// `GET /dates/{dateId}/chat`
class ChatState {
  final int dateId;
  final ChatStatus status;
  final DateTime? closesAt; // Null while NOT_OPEN
  final DateTime? readableUntil; // Null while NOT_OPEN
  final int lastSeq;
  final int unreadCount;
  final int yourLastReadSeq;
  final int partnerLastReadSeq;
  final String partnerName;
  final String? partnerThumbnailUrl;
  final List<QuickReply> quickReplies;

  const ChatState({
    required this.dateId,
    required this.status,
    this.closesAt,
    this.readableUntil,
    this.lastSeq = 0,
    this.unreadCount = 0,
    this.yourLastReadSeq = 0,
    this.partnerLastReadSeq = 0,
    required this.partnerName,
    this.partnerThumbnailUrl,
    this.quickReplies = const [],
  });

  factory ChatState.fromJson(Map<String, dynamic> json) => ChatState(
        dateId: json['dateId'] as int,
        status: ChatStatus.fromWire(json['status']),
        closesAt: _instant(json['closesAt']),
        readableUntil: _instant(json['readableUntil']),
        lastSeq: json['lastSeq'] as int? ?? 0,
        unreadCount: json['unreadCount'] as int? ?? 0,
        yourLastReadSeq: json['yourLastReadSeq'] as int? ?? 0,
        partnerLastReadSeq: json['partnerLastReadSeq'] as int? ?? 0,
        partnerName: json['partnerName'] as String,
        partnerThumbnailUrl: json['partnerThumbnailUrl'] as String?,
        quickReplies: (json['quickReplies'] as List? ?? const [])
            .map((e) => QuickReply.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// One message, from the server or written here and not yet confirmed.
///
/// A message from the server has a [seq]. One written here starts with only a
/// [clientMessageId], and gets its [seq] once the server confirms it. Retries reuse the
/// [clientMessageId], so the server never stores a message twice (primer rule 18).
class ChatMessage {
  final int? seq;
  final String? clientMessageId; // Set on messages written on this device
  final bool fromMe;
  final ChatMessageKind kind;
  final String? quickReplyKey;
  final String text;
  final bool contactDetected;
  final DateTime createdAt;
  final ChatSendState sendState;

  const ChatMessage({
    this.seq,
    this.clientMessageId,
    required this.fromMe,
    this.kind = ChatMessageKind.text,
    this.quickReplyKey,
    required this.text,
    this.contactDetected = false,
    required this.createdAt,
    this.sendState = ChatSendState.sent,
  });

  /// A message the user just wrote, before the server has it.
  factory ChatMessage.local({
    required String clientMessageId,
    required String text,
    required DateTime createdAt,
    ChatMessageKind kind = ChatMessageKind.text,
    String? quickReplyKey,
  }) =>
      ChatMessage(
        clientMessageId: clientMessageId,
        fromMe: true,
        kind: kind,
        quickReplyKey: quickReplyKey,
        text: text,
        createdAt: createdAt,
        sendState: ChatSendState.sending,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        seq: json['seq'] as int,
        fromMe: json['fromMe'] as bool,
        kind: ChatMessageKind.fromWire(json['kind']),
        quickReplyKey: json['quickReplyKey'] as String?,
        text: json['text'] as String? ?? '',
        contactDetected: json['contactDetected'] as bool? ?? false,
        createdAt: _instant(json['createdAt'])!,
      );

  /// True for the server's copy of the message this device wrote as [local]: same kind
  /// and same content. Used to pair a polled message with a send still in flight.
  bool sameContentAs(ChatMessage local) =>
      fromMe &&
      local.fromMe &&
      kind == local.kind &&
      (kind == ChatMessageKind.quickReply
          ? quickReplyKey == local.quickReplyKey
          : text == local.text);

  ChatMessage copyWith({
    String? clientMessageId,
    ChatSendState? sendState,
  }) =>
      ChatMessage(
        seq: seq,
        clientMessageId: clientMessageId ?? this.clientMessageId,
        fromMe: fromMe,
        kind: kind,
        quickReplyKey: quickReplyKey,
        text: text,
        contactDetected: contactDetected,
        createdAt: createdAt,
        sendState: sendState ?? this.sendState,
      );

  /// Never includes [text] (RFC-006 §4.11).
  @override
  String toString() =>
      'ChatMessage(seq: $seq, clientMessageId: $clientMessageId, fromMe: $fromMe, '
      'kind: $kind, sendState: $sendState)';
}

/// `GET /dates/{dateId}/chat/messages`
class ChatMessagesPage {
  final List<ChatMessage> messages; // Ascending by seq
  final bool hasMore;

  const ChatMessagesPage({required this.messages, required this.hasMore});

  factory ChatMessagesPage.fromJson(Map<String, dynamic> json) => ChatMessagesPage(
        messages: (json['messages'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: json['hasMore'] as bool? ?? false,
      );
}
