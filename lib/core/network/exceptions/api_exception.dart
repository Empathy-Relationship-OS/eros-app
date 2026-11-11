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

/// 403 `VERIFICATION_REQUIRED`: a date or chat action was refused because the signed-in user
/// isn't selfie-verified yet (RFC-008 §5.3).
///
/// It is a [ForbiddenException], so code that already handles a 403 keeps working. A screen
/// that knows about verification catches this first and shows the wall instead of an error.
class VerificationRequiredFailure extends ForbiddenException {
  /// The `error` code of the 403 body.
  static const String code = 'VERIFICATION_REQUIRED';

  const VerificationRequiredFailure(
    super.message, {
    super.statusCode = 403,
    super.originalError,
    super.stackTrace,
  });

  @override
  String toString() => 'VerificationRequiredFailure: $message';
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
