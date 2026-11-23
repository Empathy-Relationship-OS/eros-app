import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';

/// Sends an existing user's app-store age signal (RFC-009 §5.3.1, CF-B12's
/// `POST /users/me/age-signal`). New users send theirs on `POST /users` instead.
///
/// Logs the source and the outcome only, never the band (primer rule 3).
class AgeSignalRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  AgeSignalRepository(this._apiClient);

  /// POST /users/me/age-signal. True when the backend wrote it, false when its newest signal from
  /// that store already had this band. A new minor band freezes the account for review.
  Future<bool> send(StoreAgeSignal signal) async {
    try {
      _logger.d('🪪 Sending the ${signal.source.backendName} age signal');
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.users.sendAgeSignal(),
        data: signal.toJson(),
      );
      final recorded = response['recorded'] == true;
      _logger.d('✅ Age signal sent (recorded: $recorded)');
      return recorded;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to send the age signal (status ${e.statusCode})');
      rethrow;
    }
  }
}

final ageSignalRepositoryProvider = Provider<AgeSignalRepository>((ref) {
  return AgeSignalRepository(ref.watch(apiClientProvider));
});

/// True for the backend's 403 `UNDERAGE` on `POST /users`: the age signal sent with it was under
/// 18, and nothing was created (CF-B12).
bool isUnderageRefusal(ApiException e) {
  if (e is! ForbiddenException) return false;
  final body = e.originalError;
  return body is Map && body['error'] == underageErrorCode;
}

/// The `error` code of the backend's under-18 refusal.
const String underageErrorCode = 'UNDERAGE';

/// Sign-up was refused because the account holder is under 18: the store said so, or the backend
/// answered 403 `UNDERAGE`. The app shows the underage screen and signs out.
class UnderageSignUpException implements Exception {
  const UnderageSignUpException();

  @override
  String toString() => 'UnderageSignUpException';
}
