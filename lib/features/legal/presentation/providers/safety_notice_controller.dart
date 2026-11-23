import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:eros_app/features/legal/data/models/user_notice.dart';
import 'package:eros_app/features/legal/data/repositories/notices_repository.dart';
import 'package:eros_app/features/legal/presentation/widgets/safety_notice_sheet.dart';

/// Opens [url] outside the app. Returns false if nothing could open it.
typedef OpenExternalUrl = Future<bool> Function(Uri url);

Future<bool> _launchExternal(Uri url) => launchUrl(url, mode: LaunchMode.externalApplication);

/// Shows the signed-in user's unread safety notices, one sheet at a time (RFC-009 §5.7, CF-F5).
///
/// [PushHost] calls [check] on launch, on resume and on a `SAFETY_NOTICE` push, and tells it who
/// is signed in through [userChanged]. Each check refetches `GET /users/me/notices`: state comes
/// from the server (primer rule 20), so a notice read on another phone doesn't show here.
///
/// The sheet sits above the app's navigator, so it waits until the user has reached home: on a
/// cold start the auth screen is still deciding where to go and would replace it. "OK" marks the
/// notice read and checks again, so a second unread notice shows next. Dismissing the sheet any
/// other way leaves the notice unread, and it shows again on the next launch or resume.
class SafetyNoticeController {
  SafetyNoticeController({
    required NoticesRepository Function() repository,
    GlobalKey<NavigatorState>? navigatorKey,
    ValueListenable<bool>? isHomeInStack,
    OpenExternalUrl? openUrl,
    Logger? logger,
  })  : _repository = repository,
        _navigatorKey = navigatorKey ?? appNavigatorKey,
        _isHomeInStack = isHomeInStack ?? appRouteObserver.isHomeInStack,
        _openUrl = openUrl ?? _launchExternal,
        _logger = logger ?? Logger() {
    _isHomeInStack.addListener(_onHomeChanged);
  }

  final NoticesRepository Function() _repository;
  final GlobalKey<NavigatorState> _navigatorKey;
  final ValueListenable<bool> _isHomeInStack;
  final OpenExternalUrl _openUrl;
  final Logger _logger;

  String? _uid;

  /// A check asked for before home was in the stack. Runs when home arrives.
  bool _pending = false;

  /// Fetching or showing a sheet.
  bool _busy = false;

  /// A sheet is on screen. A check then has nothing to add: coming back from "Read more" resumes
  /// the app, and must not show the same notice again once the sheet is dismissed.
  bool _showing = false;

  /// A check asked for while fetching, so the result may already be stale.
  bool _again = false;

  bool _disposed = false;

  /// Whether a check is waiting for home.
  @visibleForTesting
  bool get pending => _pending;

  /// Who is signed in, or null after sign-out. A sign-in checks for notices.
  void userChanged(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _pending = false;
    _again = false;
    if (uid != null) unawaited(check());
  }

  /// Refetches the notices and shows the oldest unread one, if there is one.
  Future<void> check() async {
    if (_disposed || _uid == null) return;
    if (!_isHomeInStack.value || _navigatorKey.currentState == null) {
      _pending = true;
      return;
    }
    if (_busy) {
      if (!_showing) _again = true;
      return;
    }
    _busy = true;
    _again = false;
    var checkAgain = false;
    try {
      checkAgain = await _showNext(_uid!);
    } finally {
      _busy = false;
    }
    if (checkAgain || _again) {
      _again = false;
      await check();
    }
  }

  /// Fetches and shows the next unread notice. Returns true when it was acknowledged, so the next
  /// one, if any, should show.
  Future<bool> _showNext(String uid) async {
    final List<UserNotice> notices;
    try {
      notices = await _repository().getNotices();
    } catch (e) {
      _logger.w('⚠️  Could not check notices', error: e);
      return false;
    }
    // Newest first from the server; show the oldest unread first. Kinds this build has no copy
    // for stay unread until an app update can show them.
    final unread = notices
        .where((n) => !n.read && n.kind == UserNoticeKind.fraudContactBanned)
        .toList()
        .reversed;
    if (unread.isEmpty || _disposed || _uid != uid) return false;
    // A check asked for during the fetch is already answered by this one.
    _again = false;

    final notice = unread.first;
    final context = _navigatorKey.currentState?.context;
    if (context == null || !context.mounted || !_isHomeInStack.value) {
      _pending = true;
      return false;
    }
    _logger.i('📬 Showing notice ${notice.noticeId}');
    final documentUrl = Uri.tryParse(notice.documentUrl ?? '');
    _showing = true;
    final bool? acknowledged;
    try {
      acknowledged = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => SafetyNoticeSheet(
          onReadMore: documentUrl == null || !documentUrl.hasScheme
              ? null
              : () => _readMore(notice.noticeId, documentUrl),
        ),
      );
    } finally {
      _showing = false;
    }
    if (acknowledged != true || _disposed || _uid != uid) return false;
    try {
      await _repository().markRead(notice.noticeId);
      return true;
    } catch (e) {
      // Still unread on the server, so it shows again next launch or resume.
      _logger.w('⚠️  Could not mark notice ${notice.noticeId} read', error: e);
      return false;
    }
  }

  Future<void> _readMore(int noticeId, Uri url) async {
    try {
      if (!await _openUrl(url)) _logger.w('⚠️  Nothing opened the document for notice $noticeId');
    } catch (e) {
      _logger.w('⚠️  Could not open the document for notice $noticeId', error: e);
    }
  }

  void _onHomeChanged() {
    if (!_pending || !_isHomeInStack.value) return;
    _pending = false;
    // Home has just been pushed; let that navigation finish first.
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(check()));
  }

  void dispose() {
    _disposed = true;
    _isHomeInStack.removeListener(_onHomeChanged);
  }
}

final safetyNoticeControllerProvider = Provider<SafetyNoticeController>((ref) {
  final controller = SafetyNoticeController(repository: () => ref.read(noticesRepositoryProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
