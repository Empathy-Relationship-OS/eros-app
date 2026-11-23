import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../api_config.dart';

/// Logs HTTP requests and responses (only in non-production environments)
///
/// Chat and report calls carry message text and report descriptions, which must never be
/// printed (RFC-006 §4.11), and match preference calls carry who a user wants to meet, by
/// religion or ethnicity among others (RFC-007 D-9). Verification calls carry the selfie's
/// presigned upload link, a credential that must never be printed (RFC-008 primer rule 4). For
/// those paths it logs the method, path and status only, with
/// no query, headers or bodies. Everywhere else a `phoneNumber` field, at any depth, is printed as
/// redacted (RFC-010: sign-up and `GET /users/me` carry the user's number). A streamed response (`ResponseType.stream`) is never read
/// here either: its body belongs to whoever listens to it.
class LoggingInterceptor extends Interceptor {
  final Logger _logger;

  LoggingInterceptor({Logger? logger}) : _logger = logger ?? Logger();

  /// True for paths whose bodies are private: anything containing `/chat`, `/report`,
  /// `/match-preferences`, `/verification` or `/age-signal` (an age band, RFC-009 primer rule 3).
  static bool isPrivatePath(String path) =>
      path.contains('/chat') ||
      path.contains('/report') ||
      path.contains('/match-preferences') ||
      path.contains('/verification') ||
      path.contains('/age-signal');

  /// True when only the method, path and status may be logged.
  static bool _bodyless(RequestOptions options) =>
      isPrivatePath(options.uri.path) || options.responseType == ResponseType.stream;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (ApiConfig.enableDetailedLogging && _bodyless(options)) {
      _logger.d('📤 REQUEST ${options.method} ${options.uri.path}');
    } else if (ApiConfig.enableDetailedLogging) {
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
    final uri = response.requestOptions.uri;
    if (ApiConfig.enableDetailedLogging && _bodyless(response.requestOptions)) {
      _logger.d('📥 RESPONSE ${response.statusCode} ${response.requestOptions.method} ${uri.path}');
    } else if (ApiConfig.enableDetailedLogging) {
      _logger.d('''
📥 RESPONSE
${response.statusCode} ${response.requestOptions.uri}
Body: ${_truncateData(redactPhoneNumbers(response.data))}
''');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final uri = err.requestOptions.uri;
    if (ApiConfig.enableDetailedLogging && _bodyless(err.requestOptions)) {
      _logger.e('❌ ERROR ${err.response?.statusCode} ${err.requestOptions.method} ${uri.path}');
    } else if (ApiConfig.enableDetailedLogging) {
      _logger.e('''
❌ ERROR
${err.requestOptions.method} ${err.requestOptions.uri}
Status: ${err.response?.statusCode}
Error: ${err.message}
Response: ${redactPhoneNumbers(err.response?.data)}
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
    body = redactPhoneNumbers(body);
    if (body is Map) {
      final sanitized = Map.from(body);
      // `ageSignal` rides on POST /users and holds an age band (RFC-009 primer rule 3).
      const sensitiveFields = ['password', 'token', 'secret', 'ageSignal'];

      for (final field in sensitiveFields) {
        if (sanitized.containsKey(field)) {
          sanitized[field] = '***REDACTED***';
        }
      }
      return sanitized;
    }
    return body;
  }

  /// [data] with every non-null `phoneNumber` value, in maps and lists at any depth, replaced by
  /// a placeholder. Anything else is returned as it is.
  static dynamic redactPhoneNumbers(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(
            key,
            key == 'phoneNumber' && value != null ? _redacted : redactPhoneNumbers(value),
          ));
    }
    if (data is List) return data.map(redactPhoneNumbers).toList();
    return data;
  }

  static const _redacted = '***REDACTED***';

  /// Truncate large response bodies for readability
  String _truncateData(dynamic data) {
    final str = data.toString();
    return str.length > 500 ? '${str.substring(0, 500)}... (truncated)' : str;
  }
}
