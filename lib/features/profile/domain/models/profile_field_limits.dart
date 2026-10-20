/// Limits on profile fields that create and update requests share.
///
/// These must match the backend. Its database is the final word (RFC-004 D-11).
class ProfileFieldLimits {
  ProfileFieldLimits._();

  /// Maximum length of the brain and body descriptions. The backend database caps both columns
  /// at 100 characters (`VARCHAR(100)` plus a `CHECK`).
  static const int maxDescriptionLength = 100;
}
