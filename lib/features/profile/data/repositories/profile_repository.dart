import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';

/// Repository for profile-related API calls
class ProfileRepository {
  final String baseUrl;
  final AuthService _authService;
  final Logger _logger;

  ProfileRepository({
    this.baseUrl = 'http://localhost:8940', // Change to production URL when deploying
    required AuthService authService,
    Logger? logger,
  })  : _authService = authService,
        _logger = logger ?? Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
        );

  /// Create a new user profile
  /// POST /users
  /// After successful creation, forces a token refresh to get updated role claims
  Future<void> createUser(CreateUserRequest request) async {
    final endpoint = '$baseUrl/users';
    _logger.i('📤 POST $endpoint');

    try {
      final token = await _authService.getIdToken();
      final requestBody = request.toJson();

      _logger.d('Request body: ${jsonEncode(requestBody)}');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      _logger.d('Request headers: ${headers.keys.join(", ")}');

      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.d('Response headers: ${response.headers}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 201) {
        _logger.i('✅ User profile created successfully');

        // Force token refresh to get updated role claims
        _logger.i('🔄 Forcing token refresh to get updated role claims...');
        await _authService.getIdToken(forceRefresh: true);
        _logger.i('✅ Token refreshed successfully');

        return;
      } else if (response.statusCode == 400) {
        // Validation error
        final error = jsonDecode(response.body);
        _logger.w('⚠️  Validation error: ${error['message']}');
        _logger.w('Validation errors: ${error['errors']}');
        throw ProfileValidationException(
          error['message'] ?? 'Validation failed',
          errors: error['errors'] as Map<String, dynamic>?,
        );
      } else if (response.statusCode == 409) {
        // User already exists
        _logger.w('⚠️  User profile already exists');
        throw ProfileRepositoryException(
          'It looks like you already have an account. Please try logging in instead.',
        );
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        _logger.e('Auth failure details: ${response.body}');
        throw ProfileRepositoryException(
          'There was a problem verifying your identity. Please try signing in again.',
        );
      } else if (response.statusCode == 403) {
        _logger.e('🚫 Forbidden (403) - Server rejected the request');
        _logger.e('Server response: ${response.body}');
        throw ProfileRepositoryException(
          'We couldn\'t process your request at this time. Please try again later.',
        );
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        throw ProfileRepositoryException(
          'Something went wrong while creating your profile. Please try again.',
        );
      }
    } on ProfileRepositoryException {
      rethrow;
    } on ProfileValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  /// Get current user's profile
  /// GET /users/me
  Future<Map<String, dynamic>> getCurrentUser() async {
    final endpoint = '$baseUrl/users/me';
    _logger.i('📤 GET $endpoint');

    try {
      final token = await _authService.getIdToken();
      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        _logger.i('✅ User profile retrieved successfully');
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        _logger.w('⚠️  User profile not found (404)');
        throw ProfileRepositoryException(
          'We couldn\'t find your profile. Please complete your profile setup.',
        );
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        _logger.e('Auth failure details: ${response.body}');
        throw ProfileRepositoryException(
          'There was a problem verifying your identity. Please try signing in again.',
        );
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        throw ProfileRepositoryException(
          'We couldn\'t load your profile. Please try again.',
        );
      }
    } catch (e, stackTrace) {
      if (e is ProfileRepositoryException) rethrow;
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  /// Update user profile
  /// PATCH /users/me
  Future<void> updateUser(Map<String, dynamic> updates) async {
    final endpoint = '$baseUrl/users/me';
    _logger.i('📤 PATCH $endpoint');

    try {
      final token = await _authService.getIdToken();

      _logger.d('Update payload: ${jsonEncode(updates)}');

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.patch(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode(updates),
      );

      _logger.i('📥 Response status: ${response.statusCode}');
      _logger.d('Response body: ${response.body}');

      if (response.statusCode == 200) {
        _logger.i('✅ User profile updated successfully');
        return;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        _logger.w('⚠️  Validation error: ${error['message']}');
        _logger.w('Validation errors: ${error['errors']}');
        throw ProfileValidationException(
          error['message'] ?? 'Validation failed',
          errors: error['errors'] as Map<String, dynamic>?,
        );
      } else if (response.statusCode == 401) {
        _logger.e('🔒 Authentication failed (401)');
        _logger.e('Auth failure details: ${response.body}');
        throw ProfileRepositoryException(
          'There was a problem verifying your identity. Please try signing in again.',
        );
      } else if (response.statusCode == 403) {
        _logger.e('🚫 Forbidden (403) - Server rejected the request');
        _logger.e('Server response: ${response.body}');
        throw ProfileRepositoryException(
          'We couldn\'t process your request at this time. Please try again later.',
        );
      } else {
        _logger.e('❌ Unexpected status code: ${response.statusCode}');
        _logger.e('Response body: ${response.body}');
        throw ProfileRepositoryException(
          'We couldn\'t update your profile. Please try again.',
        );
      }
    } on ProfileRepositoryException {
      rethrow;
    } on ProfileValidationException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }
}

/// Base exception for profile repository errors
class ProfileRepositoryException implements Exception {
  final String message;

  ProfileRepositoryException(this.message);

  @override
  String toString() => 'ProfileRepositoryException: $message';
}

/// Exception for validation errors from backend
class ProfileValidationException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;

  ProfileValidationException(this.message, {this.errors});

  @override
  String toString() {
    if (errors != null) {
      return 'ProfileValidationException: $message\nErrors: $errors';
    }
    return 'ProfileValidationException: $message';
  }

  /// Get user-friendly error message
  String getUserMessage() {
    if (errors != null && errors!.isNotEmpty) {
      final firstError = errors!.values.first;
      return firstError.toString();
    }
    return message;
  }
}
