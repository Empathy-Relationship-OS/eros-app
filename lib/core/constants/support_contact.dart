/// Muse's support mailbox, the one the ops runbook watches (RFC-009, CF-D1 section 1).
///
/// PLACEHOLDER: the runbook doesn't name the address yet. Keep it in this one constant so the
/// real one is a one-line change, and so every feature that offers "email us" shares it.
class SupportContact {
  SupportContact._();

  static const String email = 'support@muse.app';

  /// A `mailto:` link to [email] with [subject]. Nothing personal goes in it: the user adds what
  /// they want to say.
  static Uri mailto({String? subject}) => Uri(
        scheme: 'mailto',
        path: email,
        // `Uri.queryParameters` writes spaces as `+`, which mail apps show literally.
        query: subject == null ? null : 'subject=${Uri.encodeComponent(subject)}',
      );
}
