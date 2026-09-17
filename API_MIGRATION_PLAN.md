# API Standardization Migration Plan

**Status**: PENDING APPROVAL
**Created**: 2026-04-19
**Estimated Time**: 9-12 hours
**Impact**: Refactor all API calls from manual `http` to centralized `ApiClient` (Dio)

---

## Table of Contents

1. [Overview](#overview)
2. [Current State Analysis](#current-state-analysis)
3. [Proposed Architecture](#proposed-architecture)
4. [Migration Phases](#migration-phases)
   - [Phase 1: Build Core Infrastructure](#phase-1-build-core-infrastructure)
   - [Phase 2: Migrate Repositories](#phase-2-migrate-repositories)
   - [Phase 3: Cleanup & Testing](#phase-3-cleanup--testing)
5. [Benefits & Metrics](#benefits--metrics)
6. [Risk Assessment](#risk-assessment)
7. [Rollback Plan](#rollback-plan)
8. [File Checklist](#file-checklist)

---

## Overview

### Goals

Standardize all API calls in the Eros Flutter app by:

1. **Eliminating boilerplate** - Remove repetitive auth headers, error handling, and retry logic
2. **Type safety** - Use strongly-typed endpoint definitions instead of string concatenation
3. **Centralized concerns** - Handle auth, retries, logging, and rate limiting in one place
4. **Environment management** - Support local, develop, beta, and production configurations
5. **Better testability** - Mock `ApiClient` instead of raw HTTP calls

### Approach

Migrate from manual `http` package usage to a centralized Dio-based `ApiClient` with:
- **Strongly-typed endpoint classes** (`ApiEndpoints.users.getCurrentUser()`)
- **Automatic auth injection** via `AuthInterceptor`
- **Intelligent retry logic** for 401/403/429 via `RetryInterceptor`
- **Unified exception hierarchy** (`ApiException` with specific subclasses)
- **S3 direct upload support** integrated into `ApiClient`

---

## Current State Analysis

### Packages in Use

- ✅ **http: ^1.2.2** - Currently used across all repositories
- ❌ **dio: ^5.7.0** - Available but unused (indicates intent to standardize)

### Existing Repositories

| Repository | Lines of Code | Issues |
|------------|---------------|--------|
| `ProfileRepository` | ~315 lines | Hardcoded baseUrl, manual headers, custom exceptions |
| `QARepository` | ~200 lines | Custom retry logic only in this repo |
| `PhotoRepository` | ~250 lines | S3 upload flow with manual HTTP calls |

### Problems Identified

1. ❌ **Hardcoded baseUrl** in every repository (`http://localhost:8940`)
2. ❌ **Duplicate error handling** - Same status codes handled differently across repos
3. ❌ **Manual header construction** - `Authorization: Bearer <token>` repeated everywhere
4. ❌ **Inconsistent retry logic** - Only `QARepository` has 403 retry
5. ❌ **No rate limiting** - 429 status codes not handled
6. ❌ **Custom exceptions** - Each repo has its own exception classes
7. ❌ **No timeout configuration** - Using HTTP defaults
8. ❌ **Poor testability** - Hard to mock HTTP calls

---

## Proposed Architecture

### Directory Structure

```
lib/core/network/
├── api_client.dart              # Main Dio wrapper with request methods
├── api_endpoints.dart           # Strongly-typed endpoint definitions
├── api_config.dart              # Environment-based configuration
├── api_client_provider.dart     # Riverpod provider
├── interceptors/
│   ├── auth_interceptor.dart    # Auto-inject Firebase ID tokens
│   ├── retry_interceptor.dart   # Handle 401/403/429 retries
│   └── logging_interceptor.dart # Request/response logging (dev only)
├── exceptions/
│   └── api_exception.dart       # Unified exception hierarchy
└── models/
    └── api_response.dart        # Standard response wrapper (future)
```

### Key Design Decisions

#### 1. Strongly-Typed Endpoints

**Before (Error-prone):**
```dart
final endpoint = '$baseUrl/users/me';
```

**After (Type-safe):**
```dart
final endpoint = ApiEndpoints.users.getCurrentUser();
```

**Benefits:**
- Compile-time safety (typos caught by IDE)
- Autocomplete for all endpoints
- Centralized documentation
- Easy refactoring
- Type-safe path parameters

#### 2. Automatic Authentication

**Before:**
```dart
final token = await _authService.getIdToken();
final headers = {'Authorization': 'Bearer $token'};
final response = await http.get(uri, headers: headers);
```

**After:**
```dart
final response = await _apiClient.get(endpoint); // Auth auto-injected
```

#### 3. Intelligent Retry Logic

Centralized handling for:
- **401 Unauthorized** → Refresh token and retry
- **403 Forbidden** → Refresh custom claims and retry
- **429 Rate Limited** → Exponential backoff and retry

#### 4. Unified Exception Hierarchy

```dart
sealed class ApiException { ... }
  ├── ValidationException (400)
  ├── UnauthorizedException (401)
  ├── ForbiddenException (403)
  ├── NotFoundException (404)
  ├── ConflictException (409)
  ├── RateLimitException (429)
  ├── ServerException (500+)
  ├── NetworkException (no internet)
  └── UnknownApiException (catch-all)
```

#### 5. Environment Management

**Hybrid approach: Flutter Flavors + dart-define**

```bash
# Local (default)
flutter run

# Develop
flutter run --flavor develop --dart-define=ENV=develop

# Beta
flutter run --flavor beta --dart-define=ENV=beta

# Production
flutter run --flavor production --dart-define=ENV=production
```

**Benefits:**
- Different app IDs (install all environments side-by-side)
- Different app names (Muse Dev, Muse Beta, Muse)
- Separate Firebase projects per environment
- CI/CD friendly

---

## Migration Phases

---

## Phase 1: Build Core Infrastructure

**Estimated Time:** 3-4 hours
**Risk:** Low (no impact on existing code)

### Step 1.1: Create API Configuration

**File:** `lib/core/network/api_config.dart`

```dart
enum Environment {
  local,
  develop,
  beta,
  production;

  static Environment get current {
    const envString = String.fromEnvironment('ENV', defaultValue: 'local');
    return Environment.values.firstWhere(
      (e) => e.name == envString,
      orElse: () => Environment.local,
    );
  }
}

class ApiConfig {
  // Base URLs per environment
  static String get baseUrl {
    switch (Environment.current) {
      case Environment.local:
        return 'http://localhost:8080';
      case Environment.develop:
        return 'https://api-dev.muse.app';
      case Environment.beta:
        return 'https://api-beta.muse.app';
      case Environment.production:
        return 'https://api.muse.app';
    }
  }

  // Timeouts
  static Duration get connectTimeout => Environment.current == Environment.local
      ? const Duration(seconds: 60)
      : const Duration(seconds: 30);

  static Duration get receiveTimeout => Environment.current == Environment.local
      ? const Duration(seconds: 60)
      : const Duration(seconds: 30);

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  // Rate limiting
  static const Duration rateLimitBackoff = Duration(seconds: 5);

  // Logging
  static bool get enableDetailedLogging =>
      Environment.current == Environment.local ||
      Environment.current == Environment.develop;
}
```

---

### Step 1.2: Create Unified Exception Hierarchy

**File:** `lib/core/network/exceptions/api_exception.dart`

```dart
/// Base exception for all API-related errors
sealed class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const ApiException(
    this.message, {
    this.statusCode,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

/// 400 Bad Request - Validation errors
class ValidationException extends ApiException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException(
    super.message, {
    this.fieldErrors,
    super.statusCode = 400,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() {
    if (fieldErrors != null && fieldErrors!.isNotEmpty) {
      final errors = fieldErrors!.entries
          .map((e) => '${e.key}: ${e.value.join(", ")}')
          .join('; ');
      return 'ValidationException: $message - $errors';
    }
    return 'ValidationException: $message';
  }
}

/// 401 Unauthorized - Invalid or expired token
class UnauthorizedException extends ApiException {
  const UnauthorizedException(
    super.message, {
    super.statusCode = 401,
    super.originalError,
    super.stackTrace,
  });
}

/// 403 Forbidden - Valid token but insufficient permissions
class ForbiddenException extends ApiException {
  const ForbiddenException(
    super.message, {
    super.statusCode = 403,
    super.originalError,
    super.stackTrace,
  });
}

/// 404 Not Found
class NotFoundException extends ApiException {
  const NotFoundException(
    super.message, {
    super.statusCode = 404,
    super.originalError,
    super.stackTrace,
  });
}

/// 409 Conflict - Resource already exists or state conflict
class ConflictException extends ApiException {
  const ConflictException(
    super.message, {
    super.statusCode = 409,
    super.originalError,
    super.stackTrace,
  });
}

/// 429 Too Many Requests - Rate limiting
class RateLimitException extends ApiException {
  final Duration? retryAfter;

  const RateLimitException(
    super.message, {
    this.retryAfter,
    super.statusCode = 429,
    super.originalError,
    super.stackTrace,
  });
}

/// 500-599 Server errors
class ServerException extends ApiException {
  const ServerException(
    super.message, {
    super.statusCode = 500,
    super.originalError,
    super.stackTrace,
  });
}

/// Network connectivity issues (no internet, timeout, etc.)
class NetworkException extends ApiException {
  const NetworkException(
    super.message, {
    super.originalError,
    super.stackTrace,
  }) : super(statusCode: null);
}

/// Unexpected/unknown errors
class UnknownApiException extends ApiException {
  const UnknownApiException(
    super.message, {
    super.statusCode,
    super.originalError,
    super.stackTrace,
  });
}
```

---

### Step 1.3: Create API Endpoints (Type-Safe)

**File:** `lib/core/network/api_endpoints.dart`

```dart
/// Centralized API endpoint definitions
/// All endpoints are strongly-typed and provide compile-time safety
class ApiEndpoints {
  ApiEndpoints._(); // Private constructor - use static members only

  // Root health check
  static const String healthCheck = '/';

  // Feature-specific endpoint groups
  static final users = _UsersEndpoints();
  static final photos = _PhotosEndpoints();
  static final qa = _QAEndpoints();
  static final match = _MatchEndpoints();
  static final dates = _DatesEndpoints();
}

// ====================
// USERS ENDPOINTS
// ====================
class _UsersEndpoints {
  /// POST /users - Create new user
  String create() => '/users';

  /// GET /users/exists - Check if user exists
  String checkExists() => '/users/exists';

  /// GET /users/me - Get current user profile
  String getCurrentUser() => '/users/me';

  /// PATCH /users/me - Update current user profile
  String updateCurrentUser() => '/users/me';

  /// GET /users/id/{userId}/public - Get public profile by ID
  String getPublicProfile(String userId) => '/users/id/$userId/public';
}

// ====================
// PHOTOS ENDPOINTS
// ====================
class _PhotosEndpoints {
  /// POST /users/me/photos/presigned-url - Get S3 presigned upload URL
  String getPresignedUrl() => '/users/me/photos/presigned-url';

  /// POST /users/me/photos - Confirm photo upload to S3
  String confirmUpload() => '/users/me/photos';

  /// DELETE /users/me/photos/{photoId} - Delete photo
  String delete(String photoId) => '/users/me/photos/$photoId';

  /// PATCH /users/me/photos/reorder - Reorder photos
  String reorder() => '/users/me/photos/reorder';
}

// ====================
// Q&A ENDPOINTS
// ====================
class _QAEndpoints {
  /// GET /users/qa/me - Get user's Q&A collection
  String getCurrentUserQA() => '/users/qa/me';

  /// POST /users/qa/me/collection - Create/update Q&A collection
  String createOrUpdateCollection() => '/users/qa/me/collection';

  /// GET /users/qa/id/{userId} - Get public Q&A for user
  String getPublicQA(String userId) => '/users/qa/id/$userId';
}

// ====================
// MATCHING ENDPOINTS
// ====================
class _MatchEndpoints {
  /// GET /match/ - Fetch daily batch of matches
  String fetchBatch() => '/match/';

  /// PATCH /match/action/{matchId} - Like or pass on match
  String action(String matchId) => '/match/action/$matchId';

  /// GET /match/last-24 - Get last 24 hours of passes
  String getLast24Hours() => '/match/last-24';
}

// ====================
// DATES ENDPOINTS (Future)
// ====================
class _DatesEndpoints {
  /// Placeholder for future date scheduling endpoints
  /// Will be populated as date features are implemented
}
```

**Note:** When adding new endpoints in the future, follow this pattern:
1. Add endpoint group class (e.g., `_DatesEndpoints`)
2. Add static getter in `ApiEndpoints` (e.g., `static final dates = _DatesEndpoints()`)
3. Add methods that return endpoint strings with path parameters

---

### Step 1.4: Create Auth Interceptor

**File:** `lib/core/network/interceptors/auth_interceptor.dart`

```dart
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

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        _logger.d('🔐 Auth token injected for ${options.method} ${options.path}');
      } else {
        _logger.w('⚠️  No auth token available for ${options.method} ${options.path}');
      }
    } catch (e, stackTrace) {
      _logger.e('❌ Failed to inject auth token', error: e, stackTrace: stackTrace);
    }

    handler.next(options);
  }
}
```

---

### Step 1.5: Create Retry Interceptor

**File:** `lib/core/network/interceptors/retry_interceptor.dart`

```dart
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../../auth/auth_service.dart';
import '../api_config.dart';
import '../exceptions/api_exception.dart';

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
```

---

### Step 1.6: Create Logging Interceptor

**File:** `lib/core/network/interceptors/logging_interceptor.dart`

```dart
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
```

---

### Step 1.7: Create Main API Client

**File:** `lib/core/network/api_client.dart`

```dart
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../auth/auth_service.dart';
import 'api_config.dart';
import 'exceptions/api_exception.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/logging_interceptor.dart';
import 'interceptors/retry_interceptor.dart';

/// Centralized HTTP client for all API requests
/// Uses Dio with automatic auth injection, retry logic, and error handling
class ApiClient {
  final Dio _dio;
  final Logger _logger = Logger();

  ApiClient(AuthService authService) : _dio = Dio() {
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

    // Add interceptors in order (auth → retry → logging)
    _dio.interceptors.addAll([
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
  Future<void> uploadToS3({
    required String presignedUrl,
    required List<int> fileBytes,
    required String contentType,
  }) async {
    try {
      _logger.d('📤 Uploading to S3: ${fileBytes.length} bytes');

      final dio = Dio(); // Separate Dio instance for S3 (no interceptors)
      final response = await dio.put(
        presignedUrl,
        data: fileBytes,
        options: Options(
          headers: {
            'Content-Type': contentType,
            'Content-Length': fileBytes.length.toString(),
          },
          validateStatus: (status) => status != null && status < 300,
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw NetworkException(
          'S3 upload failed with status ${response.statusCode}',
          originalError: response.data,
        );
      }

      _logger.d('✅ S3 upload successful');
    } on DioException catch (e, stackTrace) {
      _logger.e('❌ S3 upload failed', error: e, stackTrace: stackTrace);
      throw NetworkException(
        'Failed to upload to S3: ${e.message}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
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
      return response.data as T;
    }

    // Error responses - throw appropriate exceptions
    throw _mapStatusCodeToException(statusCode, response.data);
  }

  ApiException _mapStatusCodeToException(int? statusCode, dynamic responseData) {
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
        return RateLimitException(
          message ?? 'Too many requests',
          statusCode: statusCode,
          originalError: responseData,
        );

      case >= 500:
        return ServerException(
          message ?? 'Server error',
          statusCode: statusCode,
          originalError: responseData,
        );

      default:
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
```

---

### Step 1.8: Create Riverpod Provider

**File:** `lib/core/network/api_client_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';
import 'api_client.dart';

/// Provides singleton ApiClient instance with AuthService dependency
final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(authService);
});
```

---

### Phase 1 Checklist

- [ ] Create `lib/core/network/api_config.dart`
- [ ] Create `lib/core/network/exceptions/api_exception.dart`
- [ ] Create `lib/core/network/api_endpoints.dart`
- [ ] Create `lib/core/network/interceptors/auth_interceptor.dart`
- [ ] Create `lib/core/network/interceptors/retry_interceptor.dart`
- [ ] Create `lib/core/network/interceptors/logging_interceptor.dart`
- [ ] Create `lib/core/network/api_client.dart`
- [ ] Create `lib/core/network/api_client_provider.dart`
- [ ] Run `flutter analyze` to check for errors
- [ ] Verify no breaking changes to existing code

---

## Phase 2: Migrate Repositories

**Estimated Time:** 4-5 hours
**Risk:** Medium (requires testing after each migration)

### Migration Order

1. **ProfileRepository** (simplest, good test case)
2. **QARepository** (has retry logic to replace)
3. **PhotoRepository** (most complex, S3 uploads)

---

### Step 2.1: Migrate ProfileRepository

**File:** `lib/features/profile/data/repositories/profile_repository.dart`

#### Before & After Comparison

**BEFORE (~315 lines):**
```dart
class ProfileRepository {
  final AuthService _authService;
  final Logger _logger = Logger();
  final String baseUrl = 'http://localhost:8940'; // Hardcoded

  Future<User> getCurrentUser() async {
    final token = await _authService.getIdToken();
    final endpoint = '$baseUrl/users/me';

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http.get(Uri.parse(endpoint), headers: headers);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return User.fromJson(json);
      } else if (response.statusCode == 401) {
        throw ProfileRepositoryException('Unauthorized: ${response.body}');
      } else if (response.statusCode == 404) {
        throw ProfileRepositoryException('User not found');
      } else {
        throw ProfileRepositoryException('Failed: ${response.statusCode}');
      }
    } catch (e) {
      _logger.e('🚨 Error getting current user: $e');
      rethrow;
    }
  }

  // ... 4 more methods with similar boilerplate (200+ lines)
}
```

**AFTER (~90 lines):**
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/exceptions/api_exception.dart';
import '../../domain/entities/user.dart';
import '../models/user_request.dart';

class ProfileRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  ProfileRepository(this._apiClient);

  /// Create new user profile
  Future<User> createUser(UserRequest request) async {
    try {
      _logger.d('📝 Creating user profile');

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.users.create(),
        data: request.toJson(),
      );

      return User.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to create user', error: e);
      rethrow; // ApiException will be caught by UI layer
    }
  }

  /// Check if user already exists
  Future<bool> checkUserExists() async {
    try {
      _logger.d('🔍 Checking if user exists');

      await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.checkExists(),
      );

      return true;
    } on NotFoundException {
      return false;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to check user existence', error: e);
      rethrow;
    }
  }

  /// Get current user profile
  Future<User> getCurrentUser() async {
    try {
      _logger.d('👤 Getting current user profile');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.getCurrentUser(),
      );

      return User.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get current user', error: e);
      rethrow;
    }
  }

  /// Update current user profile
  Future<User> updateUser(Map<String, dynamic> updates) async {
    try {
      _logger.d('✏️  Updating user profile: ${updates.keys.join(", ")}');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.users.updateCurrentUser(),
        data: updates,
      );

      return User.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to update user', error: e);
      rethrow;
    }
  }

  /// Get public profile by user ID
  Future<User> getPublicProfile(String userId) async {
    try {
      _logger.d('👁️  Getting public profile for user: $userId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.getPublicProfile(userId),
      );

      return User.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get public profile', error: e);
      rethrow;
    }
  }
}

/// Riverpod provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient);
});
```

#### Changes Made

- ❌ **Removed:** `http` package, manual headers, baseUrl, `ProfileRepositoryException`
- ✅ **Added:** `ApiClient` injection, `ApiEndpoints`, `ApiException` handling
- 📉 **Reduced:** 315 lines → 90 lines (71% reduction)

#### Testing After Migration

```bash
# Run repository tests
flutter test test/features/profile/data/repositories/profile_repository_test.dart

# Run related widget tests
flutter test test/features/profile/presentation/

# Manual testing
flutter run
# Navigate to profile screens and verify all CRUD operations work
```

---

### Step 2.2: Migrate QARepository

**File:** `lib/features/profile/data/repositories/qa_repository.dart`

#### Key Changes

- Remove custom `_makeAuthenticatedRequest` helper (ApiClient handles retries)
- Remove manual 403 retry logic (RetryInterceptor handles it)
- Use `ApiEndpoints.qa.*` instead of string concatenation
- Replace `QARepositoryException` with `ApiException`

#### New Implementation

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/exceptions/api_exception.dart';
import '../../domain/entities/qa_collection.dart';
import '../models/qa_request.dart';

class QARepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  QARepository(this._apiClient);

  /// Get user's Q&A collection
  Future<QACollection?> getCurrentUserQA() async {
    try {
      _logger.d('❓ Getting user Q&A collection');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.qa.getCurrentUserQA(),
      );

      return QACollection.fromJson(response);
    } on NotFoundException {
      // User hasn't created Q&A yet - return null
      _logger.d('ℹ️  No Q&A collection found for user');
      return null;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get Q&A collection', error: e);
      rethrow;
    }
  }

  /// Create or update Q&A collection
  Future<QACollection> createOrUpdateQACollection(List<QARequest> qaList) async {
    try {
      _logger.d('💾 Creating/updating Q&A collection with ${qaList.length} items');

      // Validate before submission
      if (qaList.length < 3) {
        throw ValidationException(
          'Minimum 3 Q&A responses required',
          fieldErrors: {'qaList': ['Must have at least 3 responses']},
        );
      }

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.qa.createOrUpdateCollection(),
        data: {'qaList': qaList.map((qa) => qa.toJson()).toList()},
      );

      return QACollection.fromJson(response);
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to save Q&A collection', error: e);
      rethrow;
    }
  }

  /// Get public Q&A for a user
  Future<QACollection?> getPublicQA(String userId) async {
    try {
      _logger.d('👁️  Getting public Q&A for user: $userId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.qa.getPublicQA(userId),
      );

      return QACollection.fromJson(response);
    } on NotFoundException {
      _logger.d('ℹ️  No public Q&A found for user: $userId');
      return null;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to get public Q&A', error: e);
      rethrow;
    }
  }
}

/// Riverpod provider for QARepository
final qaRepositoryProvider = Provider<QARepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return QARepository(apiClient);
});
```

#### Changes Made

- ❌ **Removed:** `_makeAuthenticatedRequest`, manual 403 retry, `QARepositoryException`
- ✅ **Added:** Direct `ApiClient` usage, simplified error handling
- 📉 **Reduced:** ~200 lines → ~80 lines (60% reduction)

---

### Step 2.3: Migrate PhotoRepository

**File:** `lib/features/profile/data/repositories/photo_repository.dart`

#### Key Changes

- Use `ApiClient.uploadToS3()` for presigned URL uploads
- Use `ApiEndpoints.photos.*` for all endpoints
- Keep batch upload logic but simplify HTTP calls
- Replace `PhotoRepositoryException` with `ApiException`

#### New Implementation

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_client_provider.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/exceptions/api_exception.dart';
import '../../domain/entities/photo.dart';

class PhotoRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  PhotoRepository(this._apiClient);

  // ====================
  // SINGLE PHOTO UPLOAD
  // ====================

  /// Complete flow: Get presigned URL → Upload to S3 → Confirm upload
  Future<Photo> uploadPhoto({
    required String fileName,
    required String contentType,
    required List<int> fileBytes,
  }) async {
    try {
      _logger.d('📸 Starting photo upload: $fileName');

      // Step 1: Get presigned URL from backend
      final presignedData = await _getPresignedUrl(fileName, contentType);
      final presignedUrl = presignedData['presignedUrl'] as String;
      final photoKey = presignedData['photoKey'] as String;

      // Step 2: Upload directly to S3
      await _apiClient.uploadToS3(
        presignedUrl: presignedUrl,
        fileBytes: fileBytes,
        contentType: contentType,
      );

      // Step 3: Confirm upload with backend
      final photo = await _confirmUpload(photoKey);

      _logger.d('✅ Photo uploaded successfully: ${photo.id}');
      return photo;
    } on ApiException catch (e) {
      _logger.e('🚨 Photo upload failed', error: e);
      rethrow;
    }
  }

  /// Step 1: Request presigned S3 upload URL
  Future<Map<String, dynamic>> _getPresignedUrl(
    String fileName,
    String contentType,
  ) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.photos.getPresignedUrl(),
      data: {
        'fileName': fileName,
        'contentType': contentType,
      },
    );

    return response;
  }

  /// Step 3: Confirm successful S3 upload with backend
  Future<Photo> _confirmUpload(String photoKey) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.photos.confirmUpload(),
      data: {'photoKey': photoKey},
    );

    return Photo.fromJson(response);
  }

  // ====================
  // BATCH PHOTO UPLOAD
  // ====================

  /// Upload multiple photos with progress tracking
  Future<List<Photo>> uploadPhotos({
    required List<PhotoUploadData> photos,
    Function(int completed, int total)? onProgress,
  }) async {
    _logger.d('📸 Starting batch upload: ${photos.length} photos');

    final uploadedPhotos = <Photo>[];
    final errors = <String, String>{};

    for (var i = 0; i < photos.length; i++) {
      final photoData = photos[i];

      try {
        final photo = await uploadPhoto(
          fileName: photoData.fileName,
          contentType: photoData.contentType,
          fileBytes: photoData.fileBytes,
        );

        uploadedPhotos.add(photo);
        onProgress?.call(i + 1, photos.length);
      } on ApiException catch (e) {
        _logger.e('🚨 Failed to upload photo ${photoData.fileName}', error: e);
        errors[photoData.fileName] = e.message;

        // Continue with other photos even if one fails
        continue;
      }
    }

    // If all photos failed, throw exception
    if (uploadedPhotos.isEmpty && errors.isNotEmpty) {
      throw ValidationException(
        'All photo uploads failed',
        fieldErrors: {'photos': errors.values.toList()},
      );
    }

    // Log partial failures
    if (errors.isNotEmpty) {
      _logger.w('⚠️  ${errors.length} photos failed to upload');
    }

    return uploadedPhotos;
  }

  // ====================
  // PHOTO MANAGEMENT
  // ====================

  /// Delete a photo
  Future<void> deletePhoto(String photoId) async {
    try {
      _logger.d('🗑️  Deleting photo: $photoId');

      await _apiClient.delete<void>(
        ApiEndpoints.photos.delete(photoId),
      );

      _logger.d('✅ Photo deleted successfully');
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to delete photo', error: e);
      rethrow;
    }
  }

  /// Reorder photos
  Future<void> reorderPhotos(List<String> photoIds) async {
    try {
      _logger.d('🔄 Reordering photos: ${photoIds.join(", ")}');

      await _apiClient.patch<void>(
        ApiEndpoints.photos.reorder(),
        data: {'photoIds': photoIds},
      );

      _logger.d('✅ Photos reordered successfully');
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to reorder photos', error: e);
      rethrow;
    }
  }
}

/// Data class for batch photo uploads
class PhotoUploadData {
  final String fileName;
  final String contentType;
  final List<int> fileBytes;

  const PhotoUploadData({
    required this.fileName,
    required this.contentType,
    required this.fileBytes,
  });
}

/// Riverpod provider for PhotoRepository
final photoRepositoryProvider = Provider<PhotoRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PhotoRepository(apiClient);
});
```

#### Changes Made

- ❌ **Removed:** Manual S3 PUT requests, `PhotoRepositoryException`, boilerplate
- ✅ **Added:** `ApiClient.uploadToS3()`, cleaner batch upload flow
- 📉 **Reduced:** ~250 lines → ~150 lines (40% reduction)

---

### Step 2.4: Update Repository Providers

**Search for provider updates:**
```bash
grep -r "ProfileRepository(" lib/features/*/presentation/providers/
```

**Example update in:** `lib/features/profile/presentation/providers/profile_provider.dart`

```dart
// BEFORE
final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<User>>((ref) {
  final repository = ProfileRepository(ref.read(authServiceProvider));
  return ProfileNotifier(repository);
});

// AFTER
final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<User>>((ref) {
  final repository = ref.watch(profileRepositoryProvider); // Use provider
  return ProfileNotifier(repository);
});
```

---

### Phase 2 Checklist

- [ ] Migrate `ProfileRepository` to use `ApiClient`
- [ ] Test ProfileRepository (unit + manual)
- [ ] Migrate `QARepository` to use `ApiClient`
- [ ] Test QARepository (unit + manual)
- [ ] Migrate `PhotoRepository` to use `ApiClient`
- [ ] Test PhotoRepository including S3 uploads
- [ ] Update all presentation layer providers
- [ ] Run full test suite: `flutter test`
- [ ] Manual testing of all profile/photo/QA flows

---

## Phase 3: Cleanup & Testing

**Estimated Time:** 2-3 hours
**Risk:** Low

---

### Step 3.1: Remove Old Custom Exceptions

**Search for old exception usage:**
```bash
grep -r "ProfileRepositoryException\|PhotoRepositoryException\|QARepositoryException" lib/
```

**Files to clean up:**
- Remove `ProfileRepositoryException` class definition
- Remove `PhotoRepositoryException` class definition
- Remove `QARepositoryException` class definition
- Remove `BatchPhotoUploadException` class definition

These are now replaced by the unified `ApiException` hierarchy.

---

### Step 3.2: Update Error Handling in UI Layer

**Search for catch blocks:**
```bash
grep -r "on ProfileRepositoryException\|on PhotoRepositoryException\|on QARepositoryException" lib/features/*/presentation/
```

**Example update in:** `lib/features/profile/presentation/screens/profile_edit_screen.dart`

```dart
// BEFORE
try {
  await profileRepository.updateUser(updates);
  showSnackbar('Profile updated successfully');
} on ProfileRepositoryException catch (e) {
  showSnackbar('Profile update failed: ${e.message}');
} catch (e) {
  showSnackbar('Unexpected error');
}

// AFTER
try {
  await profileRepository.updateUser(updates);
  showSnackbar('Profile updated successfully');
} on ValidationException catch (e) {
  // Show field-specific errors
  if (e.fieldErrors != null) {
    showFieldErrors(e.fieldErrors!);
  } else {
    showSnackbar(e.message);
  }
} on UnauthorizedException catch (e) {
  // Force re-login
  navigateToLogin();
} on NetworkException catch (e) {
  showSnackbar('Connection error - check your internet');
} on ApiException catch (e) {
  // Generic API error
  showSnackbar('Error: ${e.message}');
}
```

---

### Step 3.3: Update pubspec.yaml

**File:** `pubspec.yaml`

```yaml
dependencies:
  # Remove http package (no longer needed)
  # http: ^1.2.2  ❌ REMOVE THIS

  # Keep dio (now our primary HTTP client)
  dio: ^5.7.0

  # ... rest of dependencies
```

**Run:**
```bash
flutter pub get
flutter clean
flutter pub get
```

---

### Step 3.4: Setup Flutter Flavors (Optional)

#### Android Setup

**File:** `android/app/build.gradle`

```gradle
android {
    // ... existing config

    flavorDimensions "environment"

    productFlavors {
        local {
            dimension "environment"
            applicationIdSuffix ".local"
            resValue "string", "app_name", "Muse Local"
        }
        develop {
            dimension "environment"
            applicationIdSuffix ".dev"
            resValue "string", "app_name", "Muse Dev"
        }
        beta {
            dimension "environment"
            applicationIdSuffix ".beta"
            resValue "string", "app_name", "Muse Beta"
        }
        production {
            dimension "environment"
            resValue "string", "app_name", "Muse"
        }
    }
}
```

#### iOS Setup

**Create schemes in Xcode:**

1. Open `ios/Runner.xcworkspace` in Xcode
2. Product → Scheme → New Scheme
3. Create: `Runner-Local`, `Runner-Develop`, `Runner-Beta`, `Runner-Production`
4. Edit each scheme → Build Configuration → Match to flavor

**Or use command line:**
```bash
# Run with specific environment
flutter run --flavor develop --dart-define=ENV=develop
flutter run --flavor beta --dart-define=ENV=beta
flutter run --flavor production --dart-define=ENV=production

# Build with specific environment
flutter build apk --flavor production --dart-define=ENV=production
flutter build ios --flavor production --dart-define=ENV=production
```

---

### Step 3.5: Write Tests for ApiClient

**File:** `test/core/network/api_client_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';

@GenerateMocks([AuthService])
void main() {
  late ApiClient apiClient;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    when(mockAuthService.getIdToken()).thenAnswer((_) async => 'test-token');

    apiClient = ApiClient(mockAuthService);
  });

  group('ApiClient GET requests', () {
    test('should return data on successful 200 response', () async {
      // TODO: Implement with mocked Dio
    });

    test('should throw NotFoundException on 404', () async {
      // TODO: Test 404 handling
    });

    test('should throw UnauthorizedException on 401', () async {
      // TODO: Test 401 handling
    });
  });

  group('ApiClient POST requests', () {
    test('should send data and return response on 201', () async {
      // TODO: Test POST with data
    });

    test('should throw ValidationException on 400', () async {
      // TODO: Test validation error handling
    });
  });

  group('S3 Upload', () {
    test('should upload file to presigned URL successfully', () async {
      // TODO: Test S3 upload flow
    });

    test('should throw NetworkException on S3 failure', () async {
      // TODO: Test S3 error handling
    });
  });
}
```

---

### Step 3.6: Update Repository Tests

**Example:** `test/features/profile/data/repositories/profile_repository_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

@GenerateMocks([ApiClient])
void main() {
  late ProfileRepository repository;
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ProfileRepository(mockApiClient);
  });

  group('getCurrentUser', () {
    test('should return User when API call succeeds', () async {
      // Arrange
      when(mockApiClient.get<Map<String, dynamic>>(any))
          .thenAnswer((_) async => {
                'id': 'test-id',
                'firstName': 'John',
                // ... user data
              });

      // Act
      final user = await repository.getCurrentUser();

      // Assert
      expect(user.id, 'test-id');
      expect(user.firstName, 'John');
      verify(mockApiClient.get(any)).called(1);
    });

    test('should throw NotFoundException when user not found', () async {
      // Arrange
      when(mockApiClient.get<Map<String, dynamic>>(any))
          .thenThrow(NotFoundException('User not found'));

      // Act & Assert
      expect(
        () => repository.getCurrentUser(),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
```

---

### Step 3.7: Integration Testing

**File:** `integration_test/api_integration_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eros_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('API Integration Tests', () {
    testWidgets('Profile creation flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // TODO: Test complete profile creation flow with real API
      // 1. Sign in
      // 2. Create profile
      // 3. Verify profile saved
    });

    testWidgets('Photo upload flow', (tester) async {
      // TODO: Test photo upload with S3 presigned URLs
    });

    testWidgets('Retry logic on 403', (tester) async {
      // TODO: Test automatic token refresh and retry
    });
  });
}
```

**Run integration tests:**
```bash
flutter test integration_test/api_integration_test.dart
```

---

### Phase 3 Checklist

- [ ] Remove old custom exception classes
- [ ] Update all UI error handling to use `ApiException` hierarchy
- [ ] Update `pubspec.yaml` (remove `http`, keep `dio`)
- [ ] Run `flutter pub get`
- [ ] Setup Flutter flavors (optional)
- [ ] Write unit tests for `ApiClient`
- [ ] Update all repository tests to mock `ApiClient`
- [ ] Write integration tests for critical flows
- [ ] Run full test suite: `flutter test`
- [ ] Manual testing across all environments (local, dev, beta)
- [ ] Update `CLAUDE.md` with API architecture docs (see below)

---

## Benefits & Metrics

### Code Reduction

| Repository | Before | After | Reduction |
|------------|--------|-------|-----------|
| ProfileRepository | 315 lines | 90 lines | **71%** |
| QARepository | 200 lines | 80 lines | **60%** |
| PhotoRepository | 250 lines | 150 lines | **40%** |
| **Total** | **765 lines** | **320 lines** | **58%** |

### Feature Comparison

| Feature | Before | After |
|---------|--------|-------|
| Auth header injection | Manual (every call) | Automatic (interceptor) |
| Error handling | 3 different patterns | 1 unified pattern |
| Retry logic | 1 of 3 repos | All endpoints |
| Rate limit handling | None | All endpoints |
| Environment switching | Hardcoded URLs | dart-define flags |
| S3 uploads | Manual HTTP | Integrated in ApiClient |
| Testability | Hard (HTTP mocking) | Easy (ApiClient mocking) |

---

## Risk Assessment

| Risk | Mitigation | Severity |
|------|-----------|----------|
| Breaking existing features | Migrate one repo at a time, test after each | Low |
| S3 upload regression | Keep integration test for photo flow | Medium |
| Exception handling changes in UI | Search and update all catch blocks | Low |
| Missing endpoints | Use existing repos as reference, cross-check with openapi.yaml | Low |
| Performance regression | Benchmark critical paths (Dio is generally faster) | Very Low |

---

## Rollback Plan

If critical issues arise during any phase:

### Phase 1 Issues (Infrastructure)
- Delete `lib/core/network/` directory
- No impact on existing code (nothing depends on it yet)
- Run `flutter clean && flutter pub get`

### Phase 2 Issues (Repository Migration)
Revert individual repository files via git:
```bash
git checkout HEAD -- lib/features/profile/data/repositories/profile_repository.dart
git checkout HEAD -- lib/features/profile/data/repositories/qa_repository.dart
git checkout HEAD -- lib/features/profile/data/repositories/photo_repository.dart
```

### Phase 3 Issues (Cleanup)
- Re-add `http` package to `pubspec.yaml`
- Keep both `http` and `dio` temporarily while debugging
- Revert UI error handling changes if needed

---

## File Checklist

### Phase 1: New Files to Create ✅

- [ ] `lib/core/network/api_config.dart`
- [ ] `lib/core/network/api_endpoints.dart`
- [ ] `lib/core/network/api_client.dart`
- [ ] `lib/core/network/api_client_provider.dart`
- [ ] `lib/core/network/exceptions/api_exception.dart`
- [ ] `lib/core/network/interceptors/auth_interceptor.dart`
- [ ] `lib/core/network/interceptors/retry_interceptor.dart`
- [ ] `lib/core/network/interceptors/logging_interceptor.dart`

### Phase 2: Files to Modify ✏️

- [ ] `lib/features/profile/data/repositories/profile_repository.dart`
- [ ] `lib/features/profile/data/repositories/qa_repository.dart`
- [ ] `lib/features/profile/data/repositories/photo_repository.dart`
- [ ] Presentation layer error handlers (search for old exception types)
- [ ] Presentation layer providers (update to use new repository providers)

### Phase 3: Files to Update/Remove 🗑️

- [ ] `pubspec.yaml` (remove `http` package)
- [ ] `CLAUDE.md` (add API architecture section)
- [ ] `android/app/build.gradle` (add flavors)
- [ ] `test/core/network/api_client_test.dart` (create)
- [ ] Repository test files (update to mock `ApiClient`)

---

## Approval Checklist

Before starting implementation, confirm:

- [ ] **Architecture approved**: 3-tier approach (ApiConfig, ApiEndpoints, ApiClient + Interceptors)
- [ ] **Migration order approved**: ProfileRepository → QARepository → PhotoRepository
- [ ] **Flavors setup**: Include Android/iOS flavor configuration? (Yes/No/Later)
- [ ] **Testing scope**: Write unit tests for ApiClient? (Yes/No)
- [ ] **Environment URLs confirmed**:
  - [ ] Local: `http://localhost:8080`
  - [ ] Develop: `https://api-dev.muse.app`
  - [ ] Beta: `https://api-beta.muse.app`
  - [ ] Production: `https://api.muse.app`

---

## Timeline

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| **Phase 1** | Build infrastructure (8 files) | 3-4 hours |
| **Phase 2** | Migrate 3 repositories + testing | 4-5 hours |
| **Phase 3** | Cleanup, tests, docs, flavors | 2-3 hours |
| **Total** | | **9-12 hours** |

With pair programming or code review: **+2-3 hours**

---

## Next Steps

1. **Review this plan** with the team
2. **Confirm environment URLs** (develop, beta, production)
3. **Approve the approach** and timeline
4. **Begin Phase 1 implementation** (no risk to existing code)
5. **Test incrementally** after each repository migration
6. **Update documentation** throughout the process

---

## References

- OpenAPI spec: `openapi/documentation.yaml`
- Current repositories: `lib/features/*/data/repositories/`
- Screenshot catalogue: `screenshots/Screenshot_Catalogue.md`
- Project instructions: `CLAUDE.md`
