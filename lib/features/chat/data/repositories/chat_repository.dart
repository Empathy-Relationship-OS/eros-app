import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';

// ====================
// RESULTS
// ====================

/// Outcome of fetching a page of messages.
sealed class MessagesResult {}

/// Outcome of sending a message.
sealed class SendResult {}

/// A page of messages.
final class MessagesLoaded implements MessagesResult {
  final ChatMessagesPage page;

  const MessagesLoaded(this.page);
}

/// The server stored the message, or already had it from an earlier try.
final class MessageSent implements SendResult {
  final ChatMessage message;

  const MessageSent(this.message);
}

/// 409: the chat isn't `OPEN` (or, for reading, isn't readable). Refetch the status.
final class ChatNotOpen implements MessagesResult, SendResult {
  const ChatNotOpen();
}

/// 422: the message failed the filter and wasn't stored (RFC-006 D-21).
final class MessageRejected implements SendResult {
  const MessageRejected();
}

/// 429: too many messages in the last minute (RFC-006 D-20).
final class RateLimited implements SendResult {
  final Duration? retryAfter;

  const RateLimited({this.retryAfter});
}

// ====================
// REPOSITORY
// ====================

/// Date chat API calls (RFC-006 §5 "Chat").
///
/// Never logs message text, at any level (primer rule 20). Logs ids, counts and statuses.
class ChatRepository {
  final ApiClient _apiClient;
  final Logger _logger;

  ChatRepository(this._apiClient, {Logger? logger}) : _logger = logger ?? Logger();

  /// Messages per page when the caller doesn't say. The server's default and ours agree.
  static const int pageSize = 50;

  /// `GET /dates/{dateId}/chat`
  ///
  /// Throws [ForbiddenException] if not a participant, and other [ApiException]s.
  Future<ChatState> getChat(String dateId) async {
    try {
      _logger.d('💬 Getting chat status: $dateId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.chat.getStatus(dateId),
      );

      final chat = ChatState.fromJson(response);
      _logger.d('✅ Chat $dateId: ${chat.status}, lastSeq ${chat.lastSeq}');
      return chat;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get chat status for $dateId (${e.statusCode})');
      rethrow;
    }
  }

  /// `GET /dates/{dateId}/chat/messages`
  ///
  /// Pass [afterSeq] for newer messages, [beforeSeq] for older ones, or neither for the
  /// latest page. Returns [ChatNotOpen] for a 409, and throws other [ApiException]s.
  Future<MessagesResult> getMessages(
    String dateId, {
    int? afterSeq,
    int? beforeSeq,
    int limit = pageSize,
  }) async {
    try {
      _logger.d('💬 Getting messages for $dateId (after: $afterSeq, before: $beforeSeq)');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.chat.getMessages(
          dateId,
          afterSeq: afterSeq,
          beforeSeq: beforeSeq,
          limit: limit,
        ),
      );

      final page = ChatMessagesPage.fromJson(response);
      _logger.d('✅ Got ${page.messages.length} messages for $dateId (hasMore: ${page.hasMore})');
      return MessagesLoaded(page);
    } on ConflictException {
      _logger.d('ℹ️  Chat $dateId is not readable');
      return const ChatNotOpen();
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get messages for $dateId (${e.statusCode})');
      rethrow;
    }
  }

  /// `POST /dates/{dateId}/chat/messages`, with exactly one of [text] and [quickReplyKey].
  ///
  /// Sending the same [clientMessageId] again returns the original message, so a retry
  /// can't duplicate it. Maps 409, 422 and 429 to results, and throws other
  /// [ApiException]s (network errors included).
  Future<SendResult> sendMessage(
    String dateId, {
    required String clientMessageId,
    String? text,
    String? quickReplyKey,
  }) async {
    assert((text == null) != (quickReplyKey == null), 'Send exactly one of text and quickReplyKey');
    try {
      _logger.d('📤 Sending message $clientMessageId to $dateId');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.chat.sendMessage(dateId),
        data: {
          'clientMessageId': clientMessageId,
          'text': ?text,
          'quickReplyKey': ?quickReplyKey,
        },
      );

      final message = ChatMessage.fromJson(response);
      _logger.d('✅ Sent message $clientMessageId as seq ${message.seq}');
      return MessageSent(message);
    } on ConflictException {
      _logger.d('ℹ️  Chat $dateId is not open, message $clientMessageId not sent');
      return const ChatNotOpen();
    } on RateLimitException catch (e) {
      _logger.w('⏳ Rate limited sending $clientMessageId (retry after ${e.retryAfter})');
      return RateLimited(retryAfter: e.retryAfter);
    } on ApiException catch (e) {
      if (e.statusCode == 422) {
        _logger.d('ℹ️  Message $clientMessageId rejected by the filter');
        return const MessageRejected();
      }
      _logger.e('🚨 Failed to send message $clientMessageId (${e.statusCode})');
      rethrow;
    }
  }

  /// `GET /dates/{dateId}/chat/stream`: the chat's live signals (RFC-006 §4.5).
  ///
  /// Connects when listened to and disconnects when cancelled. [onOpen] runs once the server
  /// has accepted it. Unknown events are skipped. Errors are [ApiException]s: a
  /// [ConflictException] when the chat isn't `OPEN`, a [ForbiddenException] for a
  /// non-participant, and a [NetworkException] when the connection drops.
  Stream<ChatSignal> signals(String dateId, {void Function()? onOpen}) {
    return _apiClient.stream(ApiEndpoints.chat.stream(dateId), onOpen: onOpen).expand((event) {
      final signal = ChatSignal.fromSse(event.event, event.data);
      return signal == null ? const <ChatSignal>[] : [signal];
    });
  }

  /// `POST /dates/{dateId}/chat/read`: everything up to [seq] has been read (204).
  ///
  /// A lower [seq] than the server holds is a no-op there. Allowed while `OPEN` or `CLOSED`.
  /// Throws [ApiException]s. Callers ignore them, as the next call catches up.
  Future<void> markRead(String dateId, int seq) async {
    try {
      _logger.d('👀 Marking chat $dateId read up to $seq');

      await _apiClient.post<void>(
        ApiEndpoints.chat.markRead(dateId),
        data: {'seq': seq},
      );
    } on ApiException catch (e) {
      _logger.w('⚠️  Failed to mark chat $dateId read up to $seq (${e.statusCode})');
      rethrow;
    }
  }
}
