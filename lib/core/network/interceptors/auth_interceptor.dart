import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../auth/auth_service.dart';

/// Automatically injects Firebase ID token into all API requests
class AuthInterceptor extends Interceptor {
  final AuthService _authService;
  final Logger _logger = Logger();

  AuthInterceptor(this._authService);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      // Get current Firebase ID token
      final token = await _authService.getIdToken();
      options.headers['Authorization'] = 'Bearer $token';
      _logger.d('🔐 Auth token injected for ${options.method} ${options.path}');
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to inject auth token', error: e, stackTrace: stackTrace);
      // Continue with request even if auth fails - let backend handle it
    }

    handler.next(options);
  }
}
