import 'package:flutter/foundation.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// One consent sent with `POST /users` (RFC-009 §5.2, CF-B2): a grant of [version] of [kind], the
/// version the user was shown at sign-up (primer rule 17).
@immutable
class SignupConsent {
  final DocumentKind kind;
  final String version;

  const SignupConsent({required this.kind, required this.version});

  Map<String, dynamic> toJson() => {'kind': kind.backendValue, 'version': version};

  @override
  bool operator ==(Object other) =>
      other is SignupConsent && other.kind == kind && other.version == version;

  @override
  int get hashCode => Object.hash(kind, version);

  @override
  String toString() => 'SignupConsent(${kind.backendValue}, $version)';
}
