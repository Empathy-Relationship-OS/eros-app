import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/legal/data/models/user_notice.dart';

/// The signed-in user's notices (RFC-009 §5.7, CF-B6). Logs ids and counts only.
class NoticesRepository {
  NoticesRepository(this._apiClient);

  final ApiClient _apiClient;
  final Logger _logger = Logger();

  /// GET /users/me/notices: newest first, `[]` if there are none.
  Future<List<UserNotice>> getNotices() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(ApiEndpoints.notices.list());
      final notices =
          response.map((e) => UserNotice.fromJson(e as Map<String, dynamic>)).toList();
      _logger.d('📬 ${notices.length} notices, ${notices.where((n) => !n.read).length} unread');
      return notices;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get notices (status ${e.statusCode})');
      rethrow;
    }
  }

  /// POST /users/me/notices/{id}/read. Marking it again keeps the first time.
  ///
  /// Throws [NotFoundException] for a notice that isn't the caller's.
  Future<void> markRead(int noticeId) async {
    try {
      await _apiClient.post<void>(ApiEndpoints.notices.markRead(noticeId));
      _logger.d('✅ Notice $noticeId marked read');
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to mark notice $noticeId read (status ${e.statusCode})');
      rethrow;
    }
  }
}

final noticesRepositoryProvider = Provider<NoticesRepository>((ref) {
  return NoticesRepository(ref.watch(apiClientProvider));
});
