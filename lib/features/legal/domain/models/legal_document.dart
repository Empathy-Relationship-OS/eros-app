import 'package:flutter/foundation.dart';

/// A kind of legal document, which is also the kind of a consent (RFC-009 §5.2). Must match the
/// backend's `DocumentKind`.
enum DocumentKind {
  terms('TERMS'),
  privacyNotice('PRIVACY_NOTICE'),
  safetyNotice('SAFETY_NOTICE'),
  datingBillOfRights('DATING_BILL_OF_RIGHTS'),
  sensitiveData('SENSITIVE_DATA'),
  locationPin('LOCATION_PIN'),
  marketing('MARKETING'),

  /// A document only: the text behind a fraud-ban notice. Nobody consents to it.
  fraudNotice('FRAUD_NOTICE');

  /// The value on the wire.
  final String backendValue;

  const DocumentKind(this.backendValue);

  /// The kind for [value], or null for one this build doesn't know (a newer server). Parsers skip
  /// those rather than fail, so old builds keep working when a kind is added.
  static DocumentKind? fromBackend(Object? value) {
    for (final kind in values) {
      if (kind.backendValue == value) return kind;
    }
    return null;
  }
}

/// A current document from `GET /legal/documents`. Its wording lives at [url], never in the app
/// (primer rule 18). A consent to it is sent with [version] unchanged (rule 17).
@immutable
class LegalDocument {
  final DocumentKind kind;
  final String version;
  final String url;
  final DateTime effectiveAt;

  /// Whether a user in this region must accept it.
  final bool required;

  const LegalDocument({
    required this.kind,
    required this.version,
    required this.url,
    required this.effectiveAt,
    required this.required,
  });

  /// Null for a kind this build doesn't know.
  static LegalDocument? fromJson(Map<String, dynamic> json) {
    final kind = DocumentKind.fromBackend(json['kind']);
    if (kind == null) return null;
    return LegalDocument(
      kind: kind,
      version: json['version'] as String,
      url: json['url'] as String,
      effectiveAt: DateTime.parse(json['effectiveAt'] as String),
      required: json['required'] as bool? ?? false,
    );
  }

  /// Every document in [json] whose kind this build knows, in the server's order.
  static List<LegalDocument> listFromJson(List<dynamic> json) => [
        for (final item in json)
          ?LegalDocument.fromJson(item as Map<String, dynamic>),
      ];

  @override
  String toString() => 'LegalDocument(${kind.backendValue}, $version)';
}
