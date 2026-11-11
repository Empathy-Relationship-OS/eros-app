/// Selfie verification models (RFC-008 §5.2, §6 "User").
///
/// Parsing is tolerant: a value this build doesn't know becomes `unknown` or `other`, never a
/// throw, so an older build keeps working when the backend adds one. Nothing here holds image
/// bytes, a score, or anything about another person (primer rules 19 and 21).
library;

/// The enum value whose UPPER_SNAKE wire name is [wire], or [fallback].
T _fromWire<T extends Enum>(List<T> values, Object? wire, T fallback) {
  for (final value in values) {
    if (_toWire(value) == wire) return value;
  }
  return fallback;
}

String _toWire(Enum e) =>
    e.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}').toUpperCase();

/// A user's verification state, as the app sees it (RFC-008 §5.2).
enum VerificationState {
  notVerified,
  inReview,
  retry,
  verified,
  locked,

  /// A state this build doesn't know. Treated as not verified, with no way to start.
  unknown;

  static VerificationState fromWire(Object? wire) => _fromWire(values, wire, unknown);
}

/// Why staff rejected the last attempt (RFC-008 §5.6). The app shows wording for it, never
/// the reviewer's note or a score.
enum RetryReason {
  poseMissing,
  unclear,
  notSamePerson,
  profilePhotosUnsuitable,

  /// `OTHER`, and any reason this build doesn't know.
  other;

  static RetryReason fromWire(Object? wire) => _fromWire(values, wire, other);
}

/// Why the automated check couldn't use a selfie, from a 422 `SELFIE_UNUSABLE`. The user
/// retakes it; the attempt isn't counted.
enum SelfieProblem {
  noFace,
  severalFaces,
  faceTooSmall,
  tooDark,
  tooBlurry,
  eyesNotVisible,
  sunglasses,

  /// A problem this build doesn't know.
  other;

  static SelfieProblem fromWire(Object? wire) => _fromWire(values, wire, other);
}

/// `GET /users/me/verification`.
class VerificationStatus {
  final VerificationState state;

  /// Only set in [VerificationState.retry].
  final RetryReason? reason;
  final int attemptsLeftToday;

  /// Whether `startAttempt` would be accepted now.
  final bool canStart;

  /// The consent text's current version. Sent back with `startAttempt`.
  final String consentVersion;

  const VerificationStatus({
    required this.state,
    this.reason,
    this.attemptsLeftToday = 0,
    this.canStart = false,
    this.consentVersion = '',
  });

  bool get isVerified => state == VerificationState.verified;

  factory VerificationStatus.fromJson(Map<String, dynamic> json) {
    final state = VerificationState.fromWire(json['state']);
    final reason = json['reason'];
    return VerificationStatus(
      state: state,
      // A retry with no reason still needs wording, so it reads as `other`.
      reason: state == VerificationState.retry || reason != null
          ? RetryReason.fromWire(reason)
          : null,
      attemptsLeftToday: (json['attemptsLeftToday'] as num?)?.toInt() ?? 0,
      canStart: json['canStart'] as bool? ?? false,
      consentVersion: json['consentVersion']?.toString() ?? '',
    );
  }
}

/// The pose the server picked for an attempt. The app bundles an illustration per [key];
/// [instruction] is shown as sent.
class VerificationPose {
  final String key;
  final String instruction;

  const VerificationPose({required this.key, required this.instruction});

  factory VerificationPose.fromJson(Map<String, dynamic> json) => VerificationPose(
        key: json['key'] as String? ?? '',
        instruction: json['instruction'] as String? ?? '',
      );
}

/// A presigned PUT for the selfie.
class SelfieUpload {
  final String url;

  /// Signed into [url], so they are sent exactly as given.
  final Map<String, String> headers;

  const SelfieUpload({required this.url, required this.headers});

  factory SelfieUpload.fromJson(Map<String, dynamic> json) => SelfieUpload(
        url: json['url'] as String,
        headers: ((json['headers'] as Map<String, dynamic>?) ?? const {})
            .map((k, v) => MapEntry(k, v.toString())),
      );

  /// The link is a credential: never print it.
  @override
  String toString() => 'SelfieUpload(url: <redacted>)';
}

/// `POST /users/me/verification/attempts`.
class VerificationAttemptStart {
  final String attemptId;
  final VerificationPose pose;
  final SelfieUpload upload;

  /// When [upload] stops working. Null only if the server didn't say.
  final DateTime? expiresAt;

  const VerificationAttemptStart({
    required this.attemptId,
    required this.pose,
    required this.upload,
    this.expiresAt,
  });

  String get url => upload.url;
  Map<String, String> get headers => upload.headers;

  factory VerificationAttemptStart.fromJson(Map<String, dynamic> json) => VerificationAttemptStart(
        attemptId: json['attemptId'].toString(),
        pose: VerificationPose.fromJson((json['pose'] as Map<String, dynamic>?) ?? const {}),
        upload: SelfieUpload.fromJson(json['upload'] as Map<String, dynamic>),
        expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      );

  /// The same attempt with the fresh link from a `SELFIE_UNUSABLE`, for the retake.
  VerificationAttemptStart withUpload(SelfieUpload upload, {DateTime? expiresAt}) =>
      VerificationAttemptStart(
        attemptId: attemptId,
        pose: pose,
        upload: upload,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  @override
  String toString() => 'VerificationAttemptStart(attemptId: $attemptId, pose: ${pose.key})';
}
