import 'package:flutter/foundation.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// Where a consent was given, for `POST /users/me/consents`. Sign-up consents go with
/// `POST /users` instead.
enum ConsentSource {
  settings('SETTINGS'),
  reprompt('REPROMPT');

  final String backendValue;

  const ConsentSource(this.backendValue);
}

/// The newest consent row of one kind.
@immutable
class Consent {
  final DocumentKind kind;
  final String version;

  /// False for a withdrawal.
  final bool granted;
  final DateTime at;

  const Consent({
    required this.kind,
    required this.version,
    required this.granted,
    required this.at,
  });

  /// Null for a kind this build doesn't know.
  static Consent? fromJson(Map<String, dynamic> json) {
    final kind = DocumentKind.fromBackend(json['kind']);
    if (kind == null) return null;
    return Consent(
      kind: kind,
      version: json['version'] as String,
      granted: json['granted'] as bool,
      at: DateTime.parse(json['at'] as String),
    );
  }
}

/// `GET /users/me/consents`, and the answer to `POST`.
@immutable
class ConsentState {
  /// The newest row per kind.
  final List<Consent> consents;

  /// Required kinds never granted, withdrawn, or granted on a version that must be accepted again.
  final List<DocumentKind> outstanding;

  /// True only on the answer to a `POST` that withdrew [DocumentKind.sensitiveData]: religion,
  /// ethnicity and their filters were cleared, but sexual orientation was kept because matching
  /// needs it (RFC-009 §5.2).
  final bool orientationRetained;

  const ConsentState({
    required this.consents,
    required this.outstanding,
    this.orientationRetained = false,
  });

  factory ConsentState.fromJson(Map<String, dynamic> json) {
    return ConsentState(
      consents: [
        for (final item in json['consents'] as List<dynamic>? ?? const [])
          ?Consent.fromJson(item as Map<String, dynamic>),
      ],
      outstanding: [
        for (final item in json['outstanding'] as List<dynamic>? ?? const [])
          ?DocumentKind.fromBackend(item),
      ],
      orientationRetained: json['orientationRetained'] as bool? ?? false,
    );
  }

  /// The newest row for [kind], or null if there is none.
  Consent? latest(DocumentKind kind) {
    for (final consent in consents) {
      if (consent.kind == kind) return consent;
    }
    return null;
  }

  /// Whether the newest row for [kind] is a grant. A kind with no row is not granted.
  bool isGranted(DocumentKind kind) => latest(kind)?.granted ?? false;
}

/// One choice in `POST /users/me/consents`. [granted] false withdraws. [version] is the version
/// of the document the user was shown (primer rule 17).
@immutable
class ConsentChoice {
  final DocumentKind kind;
  final String version;
  final bool granted;

  const ConsentChoice({required this.kind, required this.version, required this.granted});

  Map<String, dynamic> toJson() => {
        'kind': kind.backendValue,
        'version': version,
        'granted': granted,
      };
}
