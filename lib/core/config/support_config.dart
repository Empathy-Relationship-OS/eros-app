/// The support mailbox, from `--dart-define=SUPPORT_EMAIL=...` (RFC-009 §5.10, D-9).
///
/// Data requests and complaints from Settings open an email to it, and the ops team answers from
/// it (OPS_RUNBOOK_COMPLIANCE.md section 1).
class SupportConfig {
  SupportConfig._();

  static const String _defined = String.fromEnvironment('SUPPORT_EMAIL');

  /// PLACEHOLDER: the support address isn't settled yet (the runbook says "to be filled in").
  /// Release builds must pass `SUPPORT_EMAIL`; replace this default once it is decided.
  static const String placeholderEmail = 'support@meetmymuse.com';

  /// The address the app writes to.
  static String get supportEmail => _defined.isEmpty ? placeholderEmail : _defined;

  /// Whether [supportEmail] is still the placeholder.
  static bool get isPlaceholder => _defined.isEmpty;
}
