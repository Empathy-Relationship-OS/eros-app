import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';

/// Closing the signed-in user's account (RFC-009 §5.9).
class AccountRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  AccountRepository(this._apiClient);

  /// `DELETE /users/me`: closes the account now. The backend's `AccountErasureJob` erases it 30
  /// days later (D-5), deleting the Firebase user too, so the app leaves the Firebase user alone:
  /// while it exists, the same phone or email can't open a new account during the grace period,
  /// which matters for a banned account (CF-B8 hashes its identity only at erasure).
  Future<void> closeAccount() async {
    try {
      _logger.d('🗑️ Closing account');
      await _apiClient.delete<dynamic>(ApiEndpoints.users.deleteCurrentUser());
      _logger.i('✅ Account closed');
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to close account (status ${e.statusCode})');
      rethrow;
    }
  }
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(apiClientProvider));
});
