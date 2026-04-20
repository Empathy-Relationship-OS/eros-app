import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../auth/auth_service.dart';
import '../api_config.dart';

/// Handles automatic retries for 401/403/429 status codes
class RetryInterceptor extends Interceptor {
  final AuthService _authService;
  final Logger _logger = Logger();

  RetryInterceptor(this._authService);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    // Handle 401 Unauthorized - refresh token and retry
    if (statusCode == 401) {
      _logger.w('🔄 401 Unauthorized - Refreshing token and retrying...');

      try {
        // Force refresh Firebase token
        await _authService.getIdToken(forceRefresh: true);

        // Retry the original request
        final response = await _retryRequest(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        _logger.e('❌ Token refresh failed', error: e);
        return handler.next(err);
      }
    }

    // Handle 403 Forbidden - might be stale custom claims, refresh and retry
    if (statusCode == 403) {
      _logger.w('🔄 403 Forbidden - Refreshing token (custom claims may be stale)...');

      try {
        // Force refresh to get updated custom claims
        await _authService.getIdToken(forceRefresh: true);

        // Retry the original request
        final response = await _retryRequest(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        _logger.e('❌ Token refresh failed on 403', error: e);
        return handler.next(err);
      }
    }

    // Handle 429 Rate Limit - exponential backoff
    if (statusCode == 429) {
      final retryAfter = _getRetryAfterDuration(err.response);
      _logger.w('⏳ 429 Rate Limited - Waiting ${retryAfter.inSeconds}s before retry...');

      try {
        await Future.delayed(retryAfter);
        final response = await _retryRequest(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        _logger.e('❌ Retry after rate limit failed', error: e);
        return handler.next(err);
      }
    }

    // Pass through all other errors
    handler.next(err);
  }

  /// Retry the original request with fresh configuration
  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );

    final dio = Dio(); // Create new Dio instance to avoid interceptor loop
    dio.options.baseUrl = requestOptions.baseUrl;

    return dio.request(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }

  /// Extract retry-after duration from response headers or use default
  Duration _getRetryAfterDuration(Response? response) {
    if (response == null) return ApiConfig.rateLimitBackoff;

    // Check for Retry-After header (can be seconds or HTTP date)
    final retryAfter = response.headers.value('retry-after');
    if (retryAfter != null) {
      final seconds = int.tryParse(retryAfter);
      if (seconds != null) {
        return Duration(seconds: seconds);
      }
    }

    // Default backoff
    return ApiConfig.rateLimitBackoff;
  }
}
