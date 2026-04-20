import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';

/// Repository for profile-related API calls
class ProfileRepository {
  final ApiClient _apiClient;
  final AuthService _authService;
  final Logger _logger;

  ProfileRepository({
    required ApiClient apiClient,
    required AuthService authService,
    Logger? logger,
  })  : _apiClient = apiClient,
        _authService = authService,
        _logger = logger ??
            Logger(
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
    try {
      _logger.i('📝 Creating user profile');

      await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.users.create(),
        data: request.toJson(),
      );

      _logger.i('✅ User profile created successfully');

      // Force token refresh to get updated role claims
      _logger.i('🔄 Forcing token refresh to get updated role claims...');
      await _authService.getIdToken(forceRefresh: true);
      _logger.i('✅ Token refreshed successfully');
    } on ConflictException {
      _logger.w('⚠️  User profile already exists');
      throw ProfileRepositoryException(
        'It looks like you already have an account. Please try logging in instead.',
      );
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      throw ProfileValidationException(
        e.message,
        errors: e.fieldErrors,
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Server rejected the request');
      throw ProfileRepositoryException(
        'We couldn\'t process your request at this time. Please try again later.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw ProfileRepositoryException(
        'Something went wrong while creating your profile. Please try again.',
      );
    }
  }

  /// Check if user exists
  /// GET /users/exists
  /// Returns whether the user has been created in the backend
  Future<UserExistsResponse> checkUserExists() async {
    try {
      _logger.i('🔍 Checking if user exists');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.checkExists(),
      );

      _logger.i('✅ User exists check: ${response['exists']}');
      return UserExistsResponse.fromJson(response);
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw ProfileRepositoryException(
        'We couldn\'t check your profile status. Please try again.',
      );
    }
  }

  /// Get current user's profile
  /// GET /users/me
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      _logger.i('👤 Getting current user profile');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.getCurrentUser(),
      );

      _logger.i('✅ User profile retrieved successfully');
      return response;
    } on NotFoundException {
      _logger.w('⚠️  User profile not found (404)');
      throw ProfileRepositoryException(
        'We couldn\'t find your profile. Please complete your profile setup.',
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw ProfileRepositoryException(
        'We couldn\'t load your profile. Please try again.',
      );
    }
  }

  /// Update user profile
  /// PATCH /users/me
  Future<void> updateUser(Map<String, dynamic> updates) async {
    try {
      _logger.i('✏️  Updating user profile');

      await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.users.updateCurrentUser(),
        data: updates,
      );

      _logger.i('✅ User profile updated successfully');
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      throw ProfileValidationException(
        e.message,
        errors: e.fieldErrors,
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Server rejected the request');
      throw ProfileRepositoryException(
        'We couldn\'t process your request at this time. Please try again later.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw ProfileRepositoryException(
        'We couldn\'t update your profile. Please try again.',
      );
    }
  }

  /// Get public profile by user ID
  /// GET /users/id/{id}/public
  /// Used for viewing other users' profiles and previewing own profile
  Future<PublicProfileDTO> getPublicProfile(String userId) async {
    try {
      _logger.i('👁️  Getting public profile for user: $userId');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.getPublicProfile(userId),
      );

      _logger.i('✅ Public profile retrieved successfully');
      return PublicProfileDTO.fromJson(response);
    } on NotFoundException {
      _logger.w('⚠️  Profile not found (404)');
      throw ProfileRepositoryException(
        'We couldn\'t find this profile.',
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Access denied');
      throw ProfileRepositoryException(
        'You don\'t have permission to view this profile.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw ProfileRepositoryException(
        'We couldn\'t load this profile. Please try again.',
      );
    }
  }
}

/// Riverpod provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authService = ref.watch(authServiceProvider);
  return ProfileRepository(
    apiClient: apiClient,
    authService: authService,
  );
});

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
  final Map<String, List<String>>? errors;

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
      return firstError.first;
    }
    return message;
  }
}

/// Response model for user existence check
class UserExistsResponse {
  final bool exists;
  final String userId;

  UserExistsResponse({
    required this.exists,
    required this.userId,
  });

  factory UserExistsResponse.fromJson(Map<String, dynamic> json) {
    return UserExistsResponse(
      exists: json['exists'] as bool,
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exists': exists,
      'userId': userId,
    };
  }
}
