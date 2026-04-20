import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../api_config.dart';

/// Logs HTTP requests and responses (only in non-production environments)
class LoggingInterceptor extends Interceptor {
  final Logger _logger = Logger();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (ApiConfig.enableDetailedLogging) {
      _logger.d('''
📤 REQUEST
${options.method} ${options.uri}
Headers: ${_sanitizeHeaders(options.headers)}
Body: ${_sanitizeBody(options.data)}
''');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (ApiConfig.enableDetailedLogging) {
      _logger.d('''
📥 RESPONSE
${response.statusCode} ${response.requestOptions.uri}
Body: ${_truncateData(response.data)}
''');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (ApiConfig.enableDetailedLogging) {
      _logger.e('''
❌ ERROR
${err.requestOptions.method} ${err.requestOptions.uri}
Status: ${err.response?.statusCode}
Error: ${err.message}
Response: ${err.response?.data}
''');
    }
    handler.next(err);
  }

  /// Remove sensitive data from headers (Authorization tokens)
  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final sanitized = Map<String, dynamic>.from(headers);
    if (sanitized.containsKey('Authorization')) {
      sanitized['Authorization'] = 'Bearer ***REDACTED***';
    }
    return sanitized;
  }

  /// Redact sensitive body fields (passwords, tokens, etc.)
  dynamic _sanitizeBody(dynamic body) {
    if (body is Map) {
      final sanitized = Map.from(body);
      const sensitiveFields = ['password', 'token', 'secret'];

      for (final field in sensitiveFields) {
        if (sanitized.containsKey(field)) {
          sanitized[field] = '***REDACTED***';
        }
      }
      return sanitized;
    }
    return body;
  }

  /// Truncate large response bodies for readability
  String _truncateData(dynamic data) {
    final str = data.toString();
    return str.length > 500 ? '${str.substring(0, 500)}... (truncated)' : str;
  }
}
