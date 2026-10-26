import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../auth/auth_service.dart';
import 'api_config.dart';
import 'exceptions/api_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'interceptors/server_time_interceptor.dart';

/// Centralized HTTP client for all API requests
/// Uses Dio with automatic auth injection, retry logic, and error handling
class ApiClient {
  final Dio _dio;
  final Logger _logger = Logger();

  /// Builds the interceptor-free Dio used for S3 uploads. Tests pass one with a fake adapter.
  final Dio Function()? _s3DioFactory;

  ApiClient(AuthService authService, {Dio Function()? s3DioFactory})
      : _dio = Dio(),
        _s3DioFactory = s3DioFactory {
    // Configure base options
    _dio.options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (status) {
        // Don't throw on any status code - we'll handle errors manually
        return status != null && status < 500;
      },
    );

    // Add interceptors in order (server time → auth → retry → logging).
    // ServerTimeInterceptor goes first: RetryInterceptor resolves 401/403/429
    // in onError, which skips later interceptors, and those responses still
    // carry X-Server-Time.
    _dio.interceptors.addAll([
      ServerTimeInterceptor(),
      AuthInterceptor(authService),
      RetryInterceptor(authService),
      LoggingInterceptor(),
    ]);
  }

  // ====================
  // HTTP METHODS
  // ====================

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request<T>(
      path: path,
      method: 'GET',
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request<T>(
      path: path,
      method: 'POST',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request<T>(
      path: path,
      method: 'PATCH',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request<T>(
      path: path,
      method: 'PUT',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _request<T>(
      path: path,
      method: 'DELETE',
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// PUT request (for S3 uploads)
  ///
  /// [extraHeaders] are the presign response's `requiredHeaders`. They are signed into
  /// [presignedUrl], so they are sent exactly as given (they win over the defaults on a
  /// clash), and nothing extra is added when there are none. [onProgress] gets the fraction
  /// sent, from 0 to 1.
  Future<void> uploadToS3({
    required String presignedUrl,
    required List<int> fileBytes,
    required String contentType,
    Map<String, String> extraHeaders = const {},
    void Function(double progress)? onProgress,
  }) async {
    try {
      _logger.d('📤 Uploading to S3: ${fileBytes.length} bytes');

      // Dio sends only a Uint8List as raw bytes. Any other List<int> goes through the request
      // transformer and is uploaded as its text form, corrupting the image.
      final body = fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes);

      // Separate Dio instance for S3 (no interceptors)
      final dio = _s3DioFactory?.call() ?? Dio();
      final response = await dio.put(
        presignedUrl,
        data: body,
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': fileBytes.length.toString(),
            ...extraHeaders,
          },
          validateStatus: (status) => status != null && status < 300,
        ),
        onSendProgress: onProgress == null
            ? null
            : (sent, total) => onProgress(total > 0 ? sent / total : 0),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw NetworkException(
          'S3 upload failed with status ${response.statusCode}',
          originalError: response.data,
        );
      }

      _logger.d('✅ S3 upload successful');
    } on DioException catch (e, stackTrace) {
      // S3 explains a refusal in an XML body (<Code>AccessDenied</Code>,
      // <Code>SignatureDoesNotMatch</Code>…). Without it a 403 can't be told apart.
      final status = e.response?.statusCode;
      final s3Error = s3ErrorSummary(e.response?.data);
      final reason = [if (status != null) '$status', ?s3Error].join(' ');
      _logger.e('❌ S3 upload failed${reason.isEmpty ? '' : ': $reason'}', error: e, stackTrace: stackTrace);
      throw NetworkException(
        reason.isEmpty ? 'Failed to upload to S3: ${e.message}' : 'S3 refused the upload: $reason',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// `Code: Message` from an S3 XML error body, or null if [body] isn't one.
  static String? s3ErrorSummary(Object? body) {
    if (body is! String) return null;
    String? tag(String name) => RegExp('<$name>(.*?)</$name>', dotAll: true).firstMatch(body)?.group(1)?.trim();
    final code = tag('Code');
    if (code == null) return null;
    final message = tag('Message');
    return message == null ? code : '$code: $message';
  }

  // ====================
  // CORE REQUEST HANDLER
  // ====================

  Future<T> _request<T>({
    required String path,
    required String method,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: (options ?? Options()).copyWith(method: method),
      );

      // Handle response based on status code
      return _handleResponse<T>(response);
    } on ApiException {
      // Re-throw ApiException subclasses without wrapping
      // (thrown by _handleResponse for error status codes)
      rethrow;
    } on DioException catch (e, stackTrace) {
      _logger.e('❌ API request failed', error: e, stackTrace: stackTrace);
      throw _handleDioException(e, stackTrace);
    } catch (e, stackTrace) {
      _logger.e('❌ Unexpected error', error: e, stackTrace: stackTrace);
      throw UnknownApiException(
        'Unexpected error: $e',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  // ====================
  // RESPONSE HANDLING
  // ====================

  T _handleResponse<T>(Response response) {
    final statusCode = response.statusCode;

    // Success responses (200-299)
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      // Handle 204 No Content as null response
      if (statusCode == 204) {
        return null as T;
      }
      return response.data as T;
    }

    // Error responses - throw appropriate exceptions
    throw _mapStatusCodeToException(statusCode, response.data, response);
  }

  ApiException _mapStatusCodeToException(
    int? statusCode,
    dynamic responseData,
    Response? response,
  ) {
    final message = _extractErrorMessage(responseData);

    switch (statusCode) {
      case 400:
        return ValidationException(
          message ?? 'Validation failed',
          fieldErrors: _extractFieldErrors(responseData),
          statusCode: statusCode,
          originalError: responseData,
        );

      case 401:
        return UnauthorizedException(
          message ?? 'Authentication required',
          statusCode: statusCode,
          originalError: responseData,
        );

      case 403:
        return ForbiddenException(
          message ?? 'Access denied',
          statusCode: statusCode,
          originalError: responseData,
        );

      case 404:
        return NotFoundException(
          message ?? 'Resource not found',
          statusCode: statusCode,
          originalError: responseData,
        );

      case 409:
        return ConflictException(
          message ?? 'Resource conflict',
          statusCode: statusCode,
          originalError: responseData,
        );

      case 429:
        // Extract Retry-After header if present
        Duration? retryAfter;
        if (response != null) {
          final retryAfterHeader = response.headers.value('retry-after');
          if (retryAfterHeader != null) {
            final seconds = int.tryParse(retryAfterHeader);
            if (seconds != null) {
              retryAfter = Duration(seconds: seconds);
            }
          }
        }

        _logger.d('🚨 429 Rate Limit - Response data: $responseData');
        _logger.d('🚨 429 Rate Limit - Retry-After: $retryAfter');

        return RateLimitException(
          message ?? 'Too many requests',
          retryAfter: retryAfter,
          statusCode: statusCode,
          originalError: responseData,
        );

      default:
        // Handle 500+ as ServerException
        if (statusCode != null && statusCode >= 500) {
          return ServerException(
            message ?? 'Server error',
            statusCode: statusCode,
            originalError: responseData,
          );
        }

        return UnknownApiException(
          message ?? 'Unknown error occurred',
          statusCode: statusCode,
          originalError: responseData,
        );
    }
  }

  ApiException _handleDioException(DioException e, StackTrace stackTrace) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          'Request timeout - please check your connection',
          originalError: e,
          stackTrace: stackTrace,
        );

      case DioExceptionType.badResponse:
        return _mapStatusCodeToException(
          e.response?.statusCode,
          e.response?.data,
          e.response,
        );

      case DioExceptionType.connectionError:
        return NetworkException(
          'Connection error - please check your internet',
          originalError: e,
          stackTrace: stackTrace,
        );

      case DioExceptionType.cancel:
        return NetworkException(
          'Request cancelled',
          originalError: e,
          stackTrace: stackTrace,
        );

      default:
        return UnknownApiException(
          'Network error: ${e.message}',
          originalError: e,
          stackTrace: stackTrace,
        );
    }
  }

  // ====================
  // ERROR PARSING HELPERS
  // ====================

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      return responseData['message'] as String? ??
          responseData['error'] as String? ??
          responseData['detail'] as String?;
    }
    return null;
  }

  Map<String, List<String>>? _extractFieldErrors(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final errors = responseData['errors'] ?? responseData['fieldErrors'];
      if (errors is Map<String, dynamic>) {
        return errors.map((key, value) {
          if (value is List) {
            return MapEntry(key, value.map((e) => e.toString()).toList());
          }
          return MapEntry(key, [value.toString()]);
        });
      }
    }
    return null;
  }
}
