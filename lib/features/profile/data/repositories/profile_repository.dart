import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/legal/domain/consent_required.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/legal/data/repositories/age_signal_repository.dart';

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
  /// Throws [ConsentRequiredException] for a 400 `CONSENT_REQUIRED` (RFC-009 §5.2).
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
    } on AccountDeletedFailure {
      // This uid's account was deleted (RFC-011 D-12): the screen shows AccountDeletedScreen.
      _logger.w('⚠️  Account was deleted');
      rethrow;
    } on ConflictException {
      _logger.w('⚠️  User profile already exists');
      throw ProfileRepositoryException(
        'It looks like you already have an account. Please try logging in instead.',
      );
    } on ValidationException catch (e) {
      // A consent missing or out of date (RFC-009 §5.2): the screen sends the user back to it.
      final consentRequired = ConsentRequiredException.from(e);
      if (consentRequired != null) {
        _logger.w('⚠️  Consent required: ${consentRequired.missing.map((k) => k.backendValue)}');
        throw consentRequired;
      }
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
    } on ForbiddenException catch (e) {
      // The age signal sent with it was under 18 (RFC-009 CF-B12): nothing was created.
      if (isUnderageRefusal(e)) {
        _logger.w('🚫 Sign-up refused: under 18');
        throw const UnderageSignUpException();
      }
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

  /// Get current user's profile, as values for editing
  /// GET /users/me
  Future<MyProfile> getCurrentUser() async {
    try {
      _logger.i('👤 Getting current user profile');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.users.getCurrentUser(),
      );

      _logger.i('✅ User profile retrieved successfully');
      return _parseMyProfile(
        response,
        'We couldn\'t load your profile. Please try again.',
      );
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

  /// Update user profile with UpdateUserRequest
  /// PATCH /users/me
  /// Returns the whole profile as the server stored it.
  Future<MyProfile> updateUser(UpdateUserRequest request) async {
    try {
      _logger.i('✏️  Updating user profile');

      final response = await _apiClient.patch<Map<String, dynamic>>(
        ApiEndpoints.users.updateCurrentUser(),
        data: request.toJson(),
      );

      _logger.i('✅ User profile updated successfully');
      // The PATCH has already been saved here, so a parse failure must not read as a failed save.
      return _parseMyProfile(
        response,
        'Your changes were saved, but we couldn\'t show them. Please reload your profile.',
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
    } on NotFoundException {
      _logger.e('❌ User not found (404) - Fatal error');
      throw ProfileRepositoryException(
        'We couldn\'t find your profile. This is a critical error. Please contact support.',
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

  /// Sets, replaces or (with null) removes the user's phone number (RFC-010 §5.3).
  /// PUT /users/me/phone
  /// Returns the number as the server stored it (E.164), or null. Never logs the number.
  Future<String?> updatePhoneNumber(String? e164) async {
    try {
      _logger.i(e164 == null ? '📵 Removing phone number' : '📱 Saving phone number');
      final response = await _apiClient.put<Map<String, dynamic>>(
        ApiEndpoints.users.updatePhoneNumber(),
        data: {'phoneNumber': e164},
      );
      return response['phoneNumber'] as String?;
    } on ValidationException {
      // The server's message names the field; the user gets the same words as at sign-up.
      throw ProfileValidationException(phoneNumberRejectedMessage);
    } on UnauthorizedException {
      throw ProfileRepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on NotFoundException {
      throw ProfileRepositoryException(
        'We couldn\'t find your profile. Please complete your profile setup.',
      );
    } on NetworkException {
      throw ProfileRepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      // The type only: never anything that could hold the number.
      _logger.e('❌ Unexpected error saving phone number (${e.runtimeType})');
      throw ProfileRepositoryException('We couldn\'t save your phone number. Please try again.');
    }
  }

  /// What the user sees when the server refuses a phone number.
  static const phoneNumberRejectedMessage = 'That number didn\'t work. Check it and try again.';

  /// Parses a `UserDTO`. A body the app can't read (a missing field, an enum value it doesn't
  /// know) throws a TypeError, ArgumentError or FormatException, none of which the `on`
  /// clauses above catch, so it becomes a [ProfileRepositoryException] with [message] here.
  MyProfile _parseMyProfile(Map<String, dynamic> json, String message) {
    try {
      return MyProfile.fromJson(json);
    } catch (e, st) {
      _logger.e('🧩 Could not parse the /users/me response', error: e, stackTrace: st);
      throw ProfileRepositoryException(message);
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

  /// True when the backend's 400 is about [field], by its field errors or its message
  /// (`phoneNumber is not a valid phone number`, RFC-010 §6). Only the field name is matched.
  bool namesField(String field) =>
      (errors?.containsKey(field) ?? false) || message.contains(field);

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

  /// True when this uid's account was deleted (`exists` is then false): the app shows
  /// `AccountDeletedScreen` instead of profile creation (RFC-011 §5.6, D-12). False from a
  /// backend without SI-B2, which doesn't send it.
  final bool deleted;

  UserExistsResponse({
    required this.exists,
    required this.userId,
    this.deleted = false,
  });

  factory UserExistsResponse.fromJson(Map<String, dynamic> json) {
    return UserExistsResponse(
      exists: json['exists'] as bool,
      userId: json['userId'] as String,
      deleted: json['deleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exists': exists,
      'userId': userId,
      'deleted': deleted,
    };
  }
}
