import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// The server refused because a consent is missing or out of date: `CONSENT_REQUIRED` (RFC-009
/// §5.2, CF-B2). A 400 from `POST /users` at sign-up, or a 403 from saving a starting pin without
/// `LOCATION_PIN` (CF-B9). Body: `{ "error": "CONSENT_REQUIRED", "message", "missing": [...] }`.
class ConsentRequiredException implements Exception {
  /// The error code of the body.
  static const String code = 'CONSENT_REQUIRED';

  /// The kinds to show again, in the server's order. Kinds this build doesn't know are left out.
  final List<DocumentKind> missing;

  /// The HTTP status: 400 at sign-up, 403 for the pin.
  final int? statusCode;

  const ConsentRequiredException(this.missing, {this.statusCode});

  /// The refusal in [e], or null if [e] is some other error.
  static ConsentRequiredException? from(ApiException e) {
    final body = e.originalError;
    if (body is! Map<String, dynamic> || body['error'] != code) return null;
    return ConsentRequiredException(
      [
        for (final item in body['missing'] as List<dynamic>? ?? const [])
          ?DocumentKind.fromBackend(item),
      ],
      statusCode: e.statusCode,
    );
  }

  @override
  String toString() =>
      'ConsentRequiredException(${missing.map((k) => k.backendValue).join(', ')}, $statusCode)';
}
