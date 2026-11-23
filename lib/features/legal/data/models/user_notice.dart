import 'package:flutter/foundation.dart';

/// What a notice is about (RFC-009 §5.7). The server may add kinds before the app knows them.
enum UserNoticeKind {
  /// Someone the user exchanged chat messages with was banned for fraud.
  fraudContactBanned('FRAUD_CONTACT_BANNED'),

  /// A kind this build doesn't know. Never shown: the app has no copy for it.
  unknown('UNKNOWN');

  const UserNoticeKind(this.wire);

  final String wire;

  static UserNoticeKind fromWire(String? value) =>
      values.firstWhere((kind) => kind.wire == value, orElse: () => unknown);
}

/// One of the signed-in user's notices, from `GET /users/me/notices` (RFC-009 §6).
///
/// Nothing in it says who or what it's about, and the app mustn't guess. Its legal wording is the
/// document at [documentUrl].
@immutable
class UserNotice {
  const UserNotice({
    required this.noticeId,
    required this.kind,
    required this.createdAt,
    required this.read,
    this.documentUrl,
  });

  final int noticeId;
  final UserNoticeKind kind;
  final DateTime createdAt;
  final bool read;

  /// The current `FRAUD_NOTICE` document for the user's region, or null if there's none yet.
  final String? documentUrl;

  factory UserNotice.fromJson(Map<String, dynamic> json) => UserNotice(
        noticeId: (json['noticeId'] as num).toInt(),
        kind: UserNoticeKind.fromWire(json['kind'] as String?),
        createdAt: DateTime.parse(json['createdAt'] as String),
        read: json['read'] as bool,
        documentUrl: json['documentUrl'] as String?,
      );

  @override
  String toString() => 'UserNotice($noticeId, ${kind.wire}, read: $read)';
}
