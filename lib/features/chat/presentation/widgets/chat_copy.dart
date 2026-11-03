/// Centralized copy for the date chat (RFC-006 §6.1, §6.2)
///
/// Follows the dates conventions (`DatesCopy`): short sentences, no em dashes, and the
/// partner is always called by name.
class ChatCopy {
  ChatCopy._();

  // ====================
  // DATE DETAIL ENTRY (§6.1)
  // ====================

  static String messagePartner(String partnerName) => 'Message $partnerName';

  static const String viewMessages = 'View messages';

  static const String opensAfterConfirming = 'Once you\'ve both confirmed, you can message each other.';

  static const String unreadMessages = 'Unread messages';

  // ====================
  // HEADER
  // ====================

  /// [time] is already formatted, e.g. "21:00" or "Sat 21:00".
  static String closesAt(String time) => 'Chat closes at $time';

  static const String chatClosed = 'Chat closed';

  static const String moreOptions = 'More options';

  static const String reportAndBlock = 'Report and block';

  // ====================
  // CONVERSATION
  // ====================

  static const String intro = 'Keep it about meeting up, and stay safe out there.';

  static String emptyConversation(String partnerName) => 'Say hello to $partnerName.';

  static const String sending = 'Sending';

  static const String notSentRetry = 'Not sent, tap to retry';

  static const String notSent = 'Not sent';

  /// Under my newest message the partner has read.
  static const String seen = 'Seen';

  static const String loadFailed = 'We couldn\'t load your messages.';

  static const String tryAgain = 'Try again';

  // ====================
  // INPUT
  // ====================

  static const String inputHint = 'Message';

  static const String send = 'Send';

  static const String quickReplies = 'Quick replies';

  static const String rejected = 'That message can\'t be sent. Please keep it respectful.';

  static const String rateLimited = 'You\'re sending messages quickly. Wait a moment, then tap to retry.';

  // ====================
  // FOOTERS AND STATES
  // ====================

  static const String closedDateEnded = 'This chat closed when your date ended.';

  static const String closedDateCancelled = 'This chat closed when the date was cancelled.';

  static const String archived = 'Messages from this date are no longer available.';

  // ====================
  // CONTACT TIP (RFC-006 D-6)
  // ====================

  static const String contactTip =
      'Sharing contact details? Meet in public first, and keep your plans in the app until you feel sure.';

  static const String contactTipDismiss = 'Got it';

  // ====================
  // NOTIFICATIONS BANNER
  // ====================

  static String notificationsOff(String partnerName) =>
      'Notifications are off, so you won\'t hear when $partnerName replies.';

  static const String openSettings = 'Turn on';
}
