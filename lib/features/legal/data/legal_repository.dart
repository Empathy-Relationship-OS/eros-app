import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/legal/domain/models/consent.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';

/// A consent named a version that isn't the current one for the user's region (400
/// `CONSENT_VERSION_STALE`). The documents changed since they were loaded: reload and ask again.
class ConsentVersionStale implements Exception {
  final ApiException cause;

  /// The kinds whose version wasn't current.
  final List<DocumentKind> kinds;

  const ConsentVersionStale(this.cause, this.kinds);

  @override
  String toString() => 'ConsentVersionStale(${kinds.map((k) => k.backendValue).join(', ')})';
}

/// A required consent can't be withdrawn while the account is open (409
/// `CONSENT_REQUIRED_FOR_SERVICE`).
class ConsentRequiredForService implements Exception {
  final ApiException cause;
  final List<DocumentKind> kinds;

  const ConsentRequiredForService(this.cause, this.kinds);

  @override
  String toString() =>
      'ConsentRequiredForService(${kinds.map((k) => k.backendValue).join(', ')})';
}

/// Legal documents and the signed-in user's consents (RFC-009 §6).
///
/// Logs carry kinds and counts only, never consent text (RFC-009 §5.1 principle 7).
class LegalRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  LegalRepository(this._apiClient);

  /// `GET /legal/documents`: the current documents for [cityId]'s region, or for `ALL` without
  /// one. Kinds this build doesn't know are left out.
  Future<List<LegalDocument>> documents({int? cityId}) async {
    try {
      _logger.d('📜 Loading legal documents (city ${cityId ?? 'none'})');
      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.legal.documents(cityId: cityId),
      );
      return LegalDocument.listFromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to load legal documents (status ${e.statusCode})');
      rethrow;
    }
  }

  /// `GET /users/me/consents`: the newest consent per kind and what is still outstanding.
  Future<ConsentState> consents() async {
    try {
      _logger.d('📜 Loading consents');
      final response = await _apiClient.get<Map<String, dynamic>>(ApiEndpoints.legal.consents());
      return ConsentState.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to load consents (status ${e.statusCode})');
      rethrow;
    }
  }

  /// `POST /users/me/consents`: grants or withdraws [choices], all or none. Answers with the new
  /// state, whose [ConsentState.orientationRetained] is set after withdrawing sensitive data.
  ///
  /// Throws [ConsentVersionStale] or [ConsentRequiredForService] for those refusals, and any
  /// other [ApiException] as it is.
  Future<ConsentState> recordConsents(
    List<ConsentChoice> choices, {
    ConsentSource source = ConsentSource.settings,
  }) async {
    final kinds = choices.map((c) => '${c.kind.backendValue}=${c.granted}').join(', ');
    try {
      _logger.d('📜 Recording consents: $kinds (${source.backendValue})');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.legal.consents(),
        data: {
          'consents': [for (final choice in choices) choice.toJson()],
          'source': source.backendValue,
        },
      );
      return ConsentState.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to record consents: $kinds (status ${e.statusCode})');
      throw _mapFailure(e);
    }
  }

  static Object _mapFailure(ApiException e) {
    final body = e.originalError;
    final json = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    final kinds = [
      for (final item in json['kinds'] as List<dynamic>? ?? const [])
        ?DocumentKind.fromBackend(item),
    ];
    switch (json['error']) {
      case 'CONSENT_VERSION_STALE':
        return ConsentVersionStale(e, kinds);
      case 'CONSENT_REQUIRED_FOR_SERVICE':
        return ConsentRequiredForService(e, kinds);
    }
    return e;
  }
}

final legalRepositoryProvider = Provider<LegalRepository>((ref) {
  return LegalRepository(ref.watch(apiClientProvider));
});
