import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/data/repositories/chat_repository.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_messages.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_repository_provider.dart';

// ====================
// STATE MODEL
// ====================

/// A short line shown above the input after a send didn't go through.
enum ChatNotice {
  /// 422: the filter refused the message. Its text goes back in the box.
  rejected,

  /// 429: too many messages. The bubble shows as failed and can be retried.
  rateLimited,
}

/// What became of one send or retry. The screen uses [rejected] to put the text back in
/// the box.
enum SendOutcome {
  sent,
  failed,
  rejected,
  rateLimited,
  notOpen,

  /// Nothing was sent: empty, too long, or the chat isn't open.
  invalid,
}

/// State for the chat screen.
class ChatViewState {
  final ChatState? chat;
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;
  final bool hasMoreOlder;
  final bool isLoadingOlder;
  final ChatNotice? notice;

  const ChatViewState({
    this.chat,
    this.messages = const [],
    this.isLoading = false,
    this.errorMessage,
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
    this.notice,
  });

  /// [ChatStatus.notOpen] until the status has loaded.
  ChatStatus get status => chat?.status ?? ChatStatus.notOpen;

  bool get canSend => status == ChatStatus.open;

  bool get hasError => errorMessage != null;

  /// Highest seq held, the cursor for newer messages.
  int? get highestSeq {
    int? highest;
    for (final m in messages) {
      if (m.seq != null && (highest == null || m.seq! > highest)) highest = m.seq;
    }
    return highest;
  }

  /// Seq of my newest message the partner has read, where "Seen" shows. Null when they
  /// haven't read any of mine.
  int? get seenSeq {
    final partnerLastReadSeq = chat?.partnerLastReadSeq ?? 0;
    for (final m in messages.reversed) {
      if (m.fromMe && m.seq != null && m.seq! <= partnerLastReadSeq) return m.seq;
    }
    return null;
  }

  /// Lowest seq held, the cursor for scrolling back.
  int? get lowestSeq {
    int? lowest;
    for (final m in messages) {
      if (m.seq != null && (lowest == null || m.seq! < lowest)) lowest = m.seq;
    }
    return lowest;
  }

  ChatViewState copyWith({
    ChatState? chat,
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool? hasMoreOlder,
    bool? isLoadingOlder,
    ChatNotice? notice,
    bool clearNotice = false,
  }) {
    return ChatViewState(
      chat: chat ?? this.chat,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

// ====================
// STATE NOTIFIER
// ====================

/// Holds one date's chat in memory (RFC-006 §6.3). There is no local message database.
///
/// - [load] fetches the status, then the latest page.
/// - While the chat is `OPEN`, it polls every [pollInterval]: newer messages by cursor,
///   then the status. It stops as soon as the status isn't `OPEN`.
/// - [send] shows the message at once and confirms it by `clientMessageId`. [retry] sends
///   a failed one again with the same id, so the server can't store it twice.
/// - Messages merge by `seq` ([ChatMessages]), so overlapping fetches never duplicate one.
/// - While the app is in the foreground ([setForeground]), it marks the highest seq held as
///   read, at most once per [readDebounce]. It never posts a lower seq than one already
///   posted or than the server holds, and it does this while `CLOSED` too, so the unread
///   dot clears.
///
/// Logs ids and counts only, never message text (primer rule 20).
class ChatNotifier extends StateNotifier<ChatViewState> {
  final ChatRepository _repository;
  final String _dateId;
  final ServerClock _clock;
  final String Function() _newClientMessageId;
  final Duration pollInterval;
  final Duration readDebounce;
  final Logger _logger;

  /// Default poll interval while the chat is open (RFC-006 §6.3).
  static const Duration defaultPollInterval = Duration(seconds: 3);

  /// Most newer pages fetched in one poll before leaving the rest to the next.
  static const int _maxPagesPerPoll = 5;

  /// Shortest gap between two `POST .../chat/read` calls (CH-F3).
  static const Duration defaultReadDebounce = Duration(seconds: 1);

  Timer? _pollTimer;
  bool _polling = false;

  /// Waits [readDebounce] before posting the read position. Null when nothing is due.
  Timer? _readTimer;

  /// Highest seq posted as read. Only moves forward, except back to its old value when
  /// that post failed.
  int _postedReadSeq = 0;

  bool _inForeground = true;

  ChatNotifier(
    this._repository,
    this._dateId, {
    required ServerClock clock,
    String Function()? newClientMessageId,
    this.pollInterval = defaultPollInterval,
    this.readDebounce = defaultReadDebounce,
    Logger? logger,
    bool autoLoad = true,
  })  : _clock = clock,
        _newClientMessageId = newClientMessageId ?? const Uuid().v4,
        _logger = logger ?? Logger(),
        super(const ChatViewState()) {
    addListener((_) => _scheduleRead(), fireImmediately: false);
    if (autoLoad) load();
  }

  /// True while the poll timer runs.
  bool get isPolling => _pollTimer != null;

  /// Fetches the status, then the latest page if the chat is readable.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final chat = await _repository.getChat(_dateId);
      if (!mounted) return;
      state = state.copyWith(chat: chat);

      if (chat.status.isReadable) {
        final result = await _repository.getMessages(_dateId);
        if (!mounted) return;
        switch (result) {
          case MessagesLoaded(:final page):
            state = state.copyWith(
              messages: ChatMessages.merge(state.messages, page.messages),
              hasMoreOlder: page.hasMore,
            );
          case ChatNotOpen():
            await _refreshStatus();
            if (!mounted) return;
        }
      }

      state = state.copyWith(isLoading: false);
      _logger.d('✅ Loaded chat $_dateId (${state.status}, ${state.messages.length} messages)');
    } catch (e) {
      if (!mounted) return;
      _logger.e('🚨 Failed to load chat $_dateId');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
    _syncPolling();
  }

  /// One poll: newer messages, then the status. Skipped while one is already running.
  Future<void> poll() async {
    if (_polling || !mounted) return;
    _polling = true;
    try {
      final wasOpen = state.status == ChatStatus.open;
      await _fetchNewer();
      if (!mounted) return;
      await _refreshStatus();
      if (!mounted) return;
      // A message sent between the two calls would otherwise be missed when it closes.
      if (wasOpen && state.status == ChatStatus.closed) await _fetchNewer();
    } catch (e) {
      // The next tick tries again.
      _logger.w('⚠️  Chat poll failed for $_dateId');
    } finally {
      _polling = false;
    }
  }

  /// Fetches older messages, when the user reaches the top and there are more.
  Future<void> loadOlder() async {
    final before = state.lowestSeq;
    if (!state.hasMoreOlder || state.isLoadingOlder || before == null) return;

    state = state.copyWith(isLoadingOlder: true);
    try {
      final result = await _repository.getMessages(_dateId, beforeSeq: before);
      if (!mounted) return;
      switch (result) {
        case MessagesLoaded(:final page):
          state = state.copyWith(
            messages: ChatMessages.merge(state.messages, page.messages),
            hasMoreOlder: page.hasMore,
            isLoadingOlder: false,
          );
        case ChatNotOpen():
          state = state.copyWith(isLoadingOlder: false, hasMoreOlder: false);
          await _refreshStatus();
      }
    } catch (e) {
      if (!mounted) return;
      _logger.w('⚠️  Failed to load older messages for $_dateId');
      state = state.copyWith(isLoadingOlder: false);
    }
  }

  /// Sends [raw] as a text message. The bubble shows straight away as sending.
  Future<SendOutcome> send(String raw) async {
    final text = UserText.clean(raw, multiline: true);
    if (!state.canSend || text.isEmpty || UserText.length(text) > UserTextLimits.chatMessage) {
      return SendOutcome.invalid;
    }

    final local = ChatMessage.local(
      clientMessageId: _newClientMessageId(),
      text: text,
      createdAt: _clock.now(),
    );
    state = state.copyWith(messages: [...state.messages, local], clearNotice: true);
    return _post(local);
  }

  /// Sends a server-defined quick reply by its key. The bubble shows its text straight away.
  Future<SendOutcome> sendQuickReply(QuickReply reply) async {
    if (!state.canSend) return SendOutcome.invalid;

    final local = ChatMessage.local(
      clientMessageId: _newClientMessageId(),
      text: reply.text,
      createdAt: _clock.now(),
      kind: ChatMessageKind.quickReply,
      quickReplyKey: reply.key,
    );
    state = state.copyWith(messages: [...state.messages, local], clearNotice: true);
    return _post(local);
  }

  /// Sends a failed message again with the same `clientMessageId`.
  Future<SendOutcome> retry(String clientMessageId) async {
    final failed = state.messages.where(
      (m) => m.seq == null && m.clientMessageId == clientMessageId && m.sendState == ChatSendState.failed,
    );
    if (failed.isEmpty || !state.canSend) return SendOutcome.invalid;

    state = state.copyWith(
      messages: ChatMessages.markSendState(state.messages, clientMessageId, ChatSendState.sending),
      clearNotice: true,
    );
    return _post(failed.first);
  }

  /// Whether the app is in the foreground with the chat screen showing. Reads are only
  /// marked while it is.
  void setForeground(bool inForeground) {
    if (_inForeground == inForeground) return;
    _inForeground = inForeground;
    if (!inForeground) {
      _readTimer?.cancel();
      _readTimer = null;
    } else {
      _scheduleRead();
    }
  }

  /// Hides the notice line.
  void clearNotice() {
    if (state.notice != null) state = state.copyWith(clearNotice: true);
  }

  Future<SendOutcome> _post(ChatMessage local) async {
    final clientMessageId = local.clientMessageId!;
    try {
      final result = await _repository.sendMessage(
        _dateId,
        clientMessageId: clientMessageId,
        text: local.kind == ChatMessageKind.text ? local.text : null,
        quickReplyKey: local.kind == ChatMessageKind.quickReply ? local.quickReplyKey : null,
      );
      if (!mounted) return SendOutcome.failed;

      switch (result) {
        case MessageSent(:final message):
          state = state.copyWith(
            messages: ChatMessages.confirm(state.messages, clientMessageId, message),
          );
          return SendOutcome.sent;
        case MessageRejected():
          state = state.copyWith(
            messages: ChatMessages.remove(state.messages, clientMessageId),
            notice: ChatNotice.rejected,
          );
          return SendOutcome.rejected;
        case RateLimited():
          _markFailed(clientMessageId);
          state = state.copyWith(notice: ChatNotice.rateLimited);
          return SendOutcome.rateLimited;
        case ChatNotOpen():
          _markFailed(clientMessageId);
          await _refreshStatus();
          return SendOutcome.notOpen;
      }
    } catch (e) {
      if (!mounted) return SendOutcome.failed;
      _logger.w('⚠️  Message $clientMessageId not sent');
      _markFailed(clientMessageId);
      return SendOutcome.failed;
    }
  }

  void _markFailed(String clientMessageId) {
    state = state.copyWith(
      messages: ChatMessages.markSendState(state.messages, clientMessageId, ChatSendState.failed),
    );
  }

  Future<void> _fetchNewer() async {
    for (var i = 0; i < _maxPagesPerPoll; i++) {
      final result = await _repository.getMessages(_dateId, afterSeq: state.highestSeq ?? 0);
      if (!mounted) return;
      switch (result) {
        case MessagesLoaded(:final page):
          state = state.copyWith(messages: ChatMessages.merge(state.messages, page.messages));
          if (!page.hasMore || page.messages.isEmpty) return;
        case ChatNotOpen():
          await _refreshStatus();
          return;
      }
    }
  }

  Future<void> _refreshStatus() async {
    final chat = await _repository.getChat(_dateId);
    if (!mounted) return;
    if (chat.status != state.status) {
      _logger.d('💬 Chat $_dateId is now ${chat.status}');
    }
    state = state.copyWith(chat: chat);
    _syncPolling();
  }

  /// The seq to post as read, or null when the server already has it.
  int? get _unpostedReadSeq {
    if (!state.status.isReadable) return null;
    final highest = state.highestSeq;
    if (highest == null) return null;
    final serverHas = state.chat?.yourLastReadSeq ?? 0;
    return highest > _postedReadSeq && highest > serverHas ? highest : null;
  }

  /// Starts the wait before posting the read position, unless one is running already. A
  /// timer that's already running isn't restarted, so steady polling can't hold it off.
  void _scheduleRead() {
    if (!mounted || !_inForeground || _readTimer != null) return;
    if (_unpostedReadSeq == null) return;
    _readTimer = Timer(readDebounce, () {
      _readTimer = null;
      _postRead();
    });
  }

  Future<void> _postRead() async {
    if (!_inForeground) return;
    final seq = _unpostedReadSeq;
    if (seq == null) return;

    final previous = _postedReadSeq;
    _postedReadSeq = seq;
    try {
      await _repository.markRead(_dateId, seq);
    } catch (e) {
      // Ignored: the next change posts again. Only undo if nothing newer was posted since.
      if (_postedReadSeq == seq) _postedReadSeq = previous;
    }
  }

  /// Posts a read position still waiting, so leaving the screen straight after a new
  /// message still clears the unread dot. Nothing is waited for.
  void _flushRead() {
    if (_readTimer == null) return;
    _readTimer!.cancel();
    _readTimer = null;
    final seq = _unpostedReadSeq;
    if (seq == null || !_inForeground) return;
    _postedReadSeq = seq;
    _repository.markRead(_dateId, seq).catchError((Object _) {});
  }

  /// Polls while the chat is `OPEN`, and stops otherwise.
  void _syncPolling() {
    if (!mounted) return;
    if (state.status == ChatStatus.open) {
      _pollTimer ??= Timer.periodic(pollInterval, (_) => poll());
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _flushRead();
    super.dispose();
  }
}

// ====================
// PROVIDERS
// ====================

/// One date's chat, by date id. Disposed when the chat screen closes, which stops polling.
final chatProvider = StateNotifierProvider.autoDispose.family<ChatNotifier, ChatViewState, String>(
  (ref, dateId) => ChatNotifier(
    ref.watch(chatRepositoryProvider),
    dateId,
    clock: ref.watch(serverClockProvider),
  ),
);

/// `GET /dates/{dateId}/chat` on its own, for the unread dot on date detail.
final chatStatusProvider = FutureProvider.autoDispose.family<ChatState, String>(
  (ref, dateId) => ref.watch(chatRepositoryProvider).getChat(dateId),
);
