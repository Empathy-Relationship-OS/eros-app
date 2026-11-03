import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/notifications/active_chat_provider.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/time/server_clock_provider.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/chat/data/models/chat_models.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:eros_app/features/chat/presentation/providers/chat_screen_providers.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_bubble.dart';
import 'package:eros_app/features/chat/presentation/widgets/chat_copy.dart';
import 'package:eros_app/features/chat/presentation/widgets/contact_tip_sheet.dart';
import 'package:eros_app/features/chat/presentation/widgets/quick_reply_chips.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/safety/presentation/report_flow.dart';
import 'package:eros_app/features/settings/presentation/providers/app_settings_provider.dart';

/// The date chat (RFC-006 §6.2).
///
/// Everything it shows comes from `chat.status` and the messages the server returns. It
/// never works out whether the chat is open from `DateState` (primer rule 17). The date's
/// state only picks which "closed" line to show.
class ChatScreen extends ConsumerStatefulWidget {
  /// Named route, with the date id (a String) as its argument. Push notifications open it.
  static const String routeName = '/date-chat';

  final String dateId;

  const ChatScreen({super.key, required this.dateId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final StateController<String?> _activeChat;

  /// Starts true when this user hasn't seen the intro line for this chat.
  bool _showIntro = false;
  bool _introRecorded = false;

  /// Set once the contact tip has been shown on this screen, so it never shows twice.
  bool _contactTipShown = false;

  /// Starts loading older messages this close to the top.
  static const double _loadOlderThreshold = 200;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _input.addListener(_onInputChanged);

    // Riverpod doesn't allow changing a provider while the tree builds, so it's set just after.
    _activeChat = ref.read(activeChatDateIdProvider.notifier);
    Future.microtask(() {
      if (_activeChat.mounted) _activeChat.state = widget.dateId;
    });

    final uid = _uid;
    if (uid != null) {
      _showIntro = !ref.read(chatIntroStoreProvider).hasSeen(uid, widget.dateId);
    }

    // Reads are only marked while the app is in the foreground. Opening from a push can
    // happen before the app has resumed.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) _notifier.setForeground(false);

    ref.listenManual<bool>(
      chatProvider(widget.dateId).select((s) => s.messages.any((m) => m.contactDetected)),
      (previous, flagged) {
        if (flagged) _maybeShowContactTip();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final activeChat = _activeChat;
    final dateId = widget.dateId;
    Future.microtask(() {
      if (activeChat.mounted && activeChat.state == dateId) activeChat.state = null;
    });
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _notifier.setForeground(state == AppLifecycleState.resumed);
    // The live stream closes in the background and catches up on return (RFC-006 §6.3).
    if (state == AppLifecycleState.paused) _notifier.pause();
    if (state == AppLifecycleState.resumed) _notifier.resume();
    // They may have turned notifications on in system settings.
    if (state == AppLifecycleState.resumed) ref.invalidate(chatNotificationsEnabledProvider);
  }

  String? get _uid => ref.read(authServiceProvider).currentUser?.uid;

  ChatNotifier get _notifier => ref.read(chatProvider(widget.dateId).notifier);

  void _onScroll() {
    // The list is reversed, so the oldest messages are at the far end.
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - _loadOlderThreshold) {
      _notifier.loadOlder();
    }
  }

  /// Rebuilds the send button.
  void _onInputChanged() => setState(() {});

  Future<void> _send() async {
    final raw = _input.text;
    if (UserText.clean(raw, multiline: true).isEmpty) return;

    _input.clear();
    _scrollToNewest();

    final outcome = await _notifier.send(raw);
    if (!mounted) return;
    // A refused message goes back in the box, unless they've already started a new one.
    if ((outcome == SendOutcome.rejected || outcome == SendOutcome.invalid) && _input.text.isEmpty) {
      _input.value = TextEditingValue(
        text: raw,
        selection: TextSelection.collapsed(offset: raw.length),
      );
    }
  }

  Future<void> _sendQuickReply(QuickReply reply) async {
    _scrollToNewest();
    await _notifier.sendQuickReply(reply);
  }

  void _scrollToNewest() {
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut));
    }
  }

  /// Shows the contact tip the first time this user sees a flagged message, in any chat. It
  /// counts as seen once shown, and a dismissal is all it asks for.
  void _maybeShowContactTip() {
    if (_contactTipShown) return;
    final uid = _uid;
    if (uid == null) return;
    final store = ref.read(contactTipStoreProvider);
    if (store.hasSeen(uid)) return;

    _contactTipShown = true;
    unawaited(store.markSeen(uid));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.white,
        builder: (context) => const ContactTipSheet(),
      );
    });
  }

  /// Opens CH-F5's report flow (origin `REPORT`) for this date, loading the date first if this
  /// screen was opened from a push before date detail had fetched it.
  Future<void> _openReportAndBlock() async {
    final dates = ref.read(dateDetailProvider(widget.dateId).notifier);
    var dateDetail = ref.read(dateDetailProvider(widget.dateId)).dateDetail;
    if (dateDetail == null) {
      await dates.refresh();
      dateDetail = ref.read(dateDetailProvider(widget.dateId)).dateDetail;
    }
    if (dateDetail == null || !mounted) return;
    await openReportFlow(context, ref, dateDetail: dateDetail);
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.dateId));

    // When the chat closes while open here, refetch the date so the footer reads right.
    ref.listen(chatProvider(widget.dateId).select((s) => s.status), (previous, next) {
      if (previous == ChatStatus.open && next != ChatStatus.open) {
        ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(chatState),
      body: SafeArea(
        top: false,
        child: _buildBody(chatState),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ChatViewState chatState) {
    final chat = chatState.chat;
    final subtitle = _headerSubtitle(chat);

    return AppBar(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0.5,
      titleSpacing: 0,
      title: chat == null
          ? null
          : Row(
              children: [
                _PartnerAvatar(name: chat.partnerName, url: chat.partnerThumbnailUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        chat.partnerName,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz),
          tooltip: ChatCopy.moreOptions,
          onSelected: (value) {
            if (value == 'report') _openReportAndBlock();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'report', child: Text(ChatCopy.reportAndBlock)),
          ],
        ),
      ],
    );
  }

  /// "Chat closes at 21:00", with the weekday when it isn't today by the server's clock.
  String? _headerSubtitle(ChatState? chat) {
    if (chat == null) return null;
    switch (chat.status) {
      case ChatStatus.open:
        final closesAt = chat.closesAt?.toLocal();
        if (closesAt == null) return null;
        final now = ref.read(serverClockProvider).now().toLocal();
        final sameDay = closesAt.year == now.year && closesAt.month == now.month && closesAt.day == now.day;
        final time = DateFormat(sameDay ? 'HH:mm' : 'EEE HH:mm').format(closesAt);
        return ChatCopy.closesAt(time);
      case ChatStatus.closed:
        return ChatCopy.chatClosed;
      case ChatStatus.notOpen:
      case ChatStatus.archived:
        return null;
    }
  }

  Widget _buildBody(ChatViewState chatState) {
    if (chatState.chat == null) {
      if (chatState.hasError) return _buildLoadError();
      return const Center(child: CircularProgressIndicator());
    }

    switch (chatState.status) {
      case ChatStatus.notOpen:
        return _buildCentredMessage(ChatCopy.opensAfterConfirming);
      case ChatStatus.archived:
        return _buildCentredMessage(ChatCopy.archived);
      case ChatStatus.open:
      case ChatStatus.closed:
        return Column(
          children: [
            if (chatState.status == ChatStatus.open) _NotificationsOffBanner(partnerName: chatState.chat!.partnerName),
            Expanded(child: _buildConversation(chatState)),
            if (chatState.status == ChatStatus.open) _buildComposer(chatState) else _buildClosedFooter(),
          ],
        );
    }
  }

  Widget _buildConversation(ChatViewState chatState) {
    if (chatState.isLoading && chatState.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final messages = chatState.messages;
    final seenSeq = chatState.seenSeq;
    final showIntro = _showIntro && !chatState.hasMoreOlder;
    if (showIntro) _recordIntroShown();

    final showEmpty = messages.isEmpty && chatState.canSend;
    final extras = [
      if (chatState.isLoadingOlder) const _ListSpinner(),
      if (showEmpty) _buildCentredMessage(ChatCopy.emptyConversation(chatState.chat!.partnerName)),
      if (showIntro) const _IntroLine(),
    ];

    // Reversed, so index 0 is the newest message and the list opens at the bottom.
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: messages.length + extras.length,
      itemBuilder: (context, index) {
        if (index >= messages.length) return extras[index - messages.length];
        final message = messages[messages.length - 1 - index];
        return ChatBubble(
          key: ValueKey(message.clientMessageId ?? message.seq),
          message: message,
          seen: seenSeq != null && message.seq == seenSeq,
          onRetry: chatState.canSend && message.clientMessageId != null
              ? () => _notifier.retry(message.clientMessageId!)
              : null,
        );
      },
    );
  }

  /// The intro shows on this visit, then never again for this chat.
  void _recordIntroShown() {
    if (_introRecorded) return;
    _introRecorded = true;
    final uid = _uid;
    if (uid == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatIntroStoreProvider).markSeen(uid, widget.dateId);
    });
  }

  Widget _buildComposer(ChatViewState chatState) {
    final notice = switch (chatState.notice) {
      ChatNotice.rejected => ChatCopy.rejected,
      ChatNotice.rateLimited => ChatCopy.rateLimited,
      null => null,
    };
    final canSend = UserText.clean(_input.text, multiline: true).isNotEmpty;
    final quickReplies = chatState.canSend ? chatState.chat!.quickReplies : const <QuickReply>[];

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (quickReplies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 8),
              child: QuickReplyChips(replies: quickReplies, onSelected: _sendQuickReply),
            ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 8),
              child: Text(
                notice,
                style: const TextStyle(fontSize: 13, color: AppColors.error),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: UserTextLimits.chatMessage,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  // Only typing clears a notice, not the text a rejection puts back.
                  onChanged: (_) => _notifier.clearNotice(),
                  // The counter only shows near the limit.
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                      maxLength != null && currentLength > maxLength - 100
                          ? Text('$currentLength/$maxLength')
                          : null,
                  decoration: InputDecoration(
                    hintText: ChatCopy.inputHint,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: canSend ? _send : null,
                tooltip: ChatCopy.send,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(Icons.send, color: canSend ? AppColors.primary : AppColors.disabledText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosedFooter() {
    final dateState = ref.watch(dateDetailProvider(widget.dateId).select((s) => s.dateDetail?.state));
    final text = switch (dateState) {
      null => ChatCopy.chatClosed,
      DateState.cancelled => ChatCopy.closedDateCancelled,
      _ => ChatCopy.closedDateEnded,
    };

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildCentredMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(ChatCopy.loadFailed, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _notifier.load(), child: const Text(ChatCopy.tryAgain)),
        ],
      ),
    );
  }
}

class _PartnerAvatar extends StatelessWidget {
  final String name;
  final String? url;

  const _PartnerAvatar({required this.name, this.url});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primaryOrangeLight,
      foregroundImage: url == null ? null : CachedNetworkImageProvider(url!),
      child: Text(initial, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      child: Text(
        ChatCopy.intro,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
      ),
    );
  }
}

class _ListSpinner extends StatelessWidget {
  const _ListSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

/// A slim banner, while the chat is open, when the system won't show notifications.
class _NotificationsOffBanner extends ConsumerWidget {
  final String partnerName;

  const _NotificationsOffBanner({required this.partnerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(chatNotificationsEnabledProvider).valueOrNull ?? true;
    if (enabled) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.secondaryOrange.withValues(alpha: 0.35),
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ChatCopy.notificationsOff(partnerName),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(notificationPermissionServiceProvider).openAppSettingsPage(),
            child: const Text(ChatCopy.openSettings),
          ),
        ],
      ),
    );
  }
}
