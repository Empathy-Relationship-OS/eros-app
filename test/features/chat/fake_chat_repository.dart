import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';

dynamic chatFixture(String name) =>
    jsonDecode(File('test/fixtures/chat/$name.json').readAsStringSync());

ChatState chatState(ChatStatus status, {int unreadCount = 0, DateTime? closesAt}) => ChatState(
      dateId: 42,
      status: status,
      closesAt: closesAt ?? DateTime.utc(2026, 11, 7, 21),
      unreadCount: unreadCount,
      partnerName: 'Alex',
    );

/// An in-memory chat server behind the [ChatRepository] interface.
///
/// Sends store the message straight away, as the backend commits before answering, then
/// wait for [sendGate] when it's set, so a test can run a poll while a send is in flight.
/// Replaying a `clientMessageId` returns the stored message, like the backend.
class FakeChatRepository implements ChatRepository {
  FakeChatRepository({ChatStatus status = ChatStatus.open})
      : chat = chatState(status);

  ChatState chat;
  final List<ChatMessage> stored = [];
  final Map<String, int> _seqByClientId = {};

  /// Every call, e.g. `getChat`, `getMessages after:3`, `send <cid>`.
  final List<String> calls = [];
  final List<String> sentClientIds = [];

  /// When set, the next sends answer with this instead of storing anything.
  SendResult? sendResult;

  /// When set, the next sends throw this (after storing nothing).
  ApiException? sendError;

  /// When set, sends wait for it before answering.
  Completer<void>? sendGate;

  int _seq = 0;

  ChatMessage addPartnerMessage(String text) => _store(fromMe: false, text: text);

  ChatMessage _store({required bool fromMe, required String text}) {
    final message = ChatMessage(
      seq: ++_seq,
      fromMe: fromMe,
      text: text,
      createdAt: DateTime.utc(2026, 11, 7, 19).add(Duration(seconds: _seq)),
    );
    stored.add(message);
    return message;
  }

  @override
  Future<ChatState> getChat(String dateId) async {
    calls.add('getChat');
    return chat;
  }

  @override
  Future<MessagesResult> getMessages(
    String dateId, {
    int? afterSeq,
    int? beforeSeq,
    int limit = ChatRepository.pageSize,
  }) async {
    calls.add('getMessages${afterSeq != null ? ' after:$afterSeq' : ''}'
        '${beforeSeq != null ? ' before:$beforeSeq' : ''}');
    if (!chat.status.isReadable) return const ChatNotOpen();

    List<ChatMessage> page;
    bool hasMore;
    if (afterSeq != null) {
      final newer = stored.where((m) => m.seq! > afterSeq).toList();
      page = newer.take(limit).toList();
      hasMore = newer.length > limit;
    } else {
      final older = beforeSeq == null ? stored : stored.where((m) => m.seq! < beforeSeq).toList();
      page = older.length > limit ? older.sublist(older.length - limit) : older;
      hasMore = older.length > limit;
    }
    return MessagesLoaded(ChatMessagesPage(messages: page, hasMore: hasMore));
  }

  @override
  Future<SendResult> sendMessage(
    String dateId, {
    required String clientMessageId,
    String? text,
    String? quickReplyKey,
  }) async {
    calls.add('send $clientMessageId');
    sentClientIds.add(clientMessageId);

    final error = sendError;
    if (error != null) throw error;
    final forced = sendResult;
    if (forced != null) return forced;
    if (chat.status != ChatStatus.open) return const ChatNotOpen();

    final existing = _seqByClientId[clientMessageId];
    final message = existing != null
        ? stored.firstWhere((m) => m.seq == existing)
        : _store(fromMe: true, text: text!);
    _seqByClientId[clientMessageId] = message.seq!;

    final gate = sendGate;
    if (gate != null) await gate.future;
    return MessageSent(message);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
