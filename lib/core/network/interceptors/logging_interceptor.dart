import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../api_config.dart';

/// Logs HTTP requests and responses (only in non-production environments)
///
/// Chat messages and report descriptions are never printed (RFC-006 primer rule 20): for a
/// path containing `/chat` or `/report`, only the method, path and status are logged.
class LoggingInterceptor extends Interceptor {
  final Logger _logger;

  LoggingInterceptor({Logger? logger}) : _logger = logger ?? Logger();

  static const String _bodyNotLogged = '[not logged]';

  /// Paths whose bodies may hold private text.
  static bool _isPrivate(Uri uri) => uri.path.contains('/chat') || uri.path.contains('/report');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (ApiConfig.enableDetailedLogging) {
      _logger.d('''
📤 REQUEST
${options.method} ${options.uri}
Headers: ${_sanitizeHeaders(options.headers)}
Body: ${_isPrivate(options.uri) ? _bodyNotLogged : _sanitizeBody(options.data)}
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
Body: ${_isPrivate(response.requestOptions.uri) ? _bodyNotLogged : _truncateData(response.data)}
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
Response: ${_isPrivate(err.requestOptions.uri) ? _bodyNotLogged : err.response?.data}
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
