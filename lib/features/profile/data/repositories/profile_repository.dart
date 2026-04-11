import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';

/// Repository for profile-related API calls
class ProfileRepository {
  final String baseUrl;
  final FirebaseAuth _auth;

  ProfileRepository({
    this.baseUrl = 'http://localhost:8080', // Change to production URL when deploying
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  /// Get Firebase ID token for authentication
  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw ProfileRepositoryException('User not authenticated');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw ProfileRepositoryException('Failed to get authentication token');
    }
    return token;
  }

  /// Create a new user profile
  /// POST /users
  Future<void> createUser(CreateUserRequest request) async {
    try {
      final token = await _getIdToken();
      final response = await http.post(
        Uri.parse('$baseUrl/users'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201) {
        // Success
        return;
      } else if (response.statusCode == 400) {
        // Validation error
        final error = jsonDecode(response.body);
        throw ProfileValidationException(
          error['message'] ?? 'Validation failed',
          errors: error['errors'] as Map<String, dynamic>?,
        );
      } else if (response.statusCode == 409) {
        // User already exists
        throw ProfileRepositoryException('User profile already exists');
      } else if (response.statusCode == 401) {
        throw ProfileRepositoryException('Authentication failed');
      } else {
        throw ProfileRepositoryException(
          'Failed to create profile: ${response.statusCode}',
        );
      }
    } on ProfileRepositoryException {
      rethrow;
    } on ProfileValidationException {
      rethrow;
    } catch (e) {
      throw ProfileRepositoryException('Network error: $e');
    }
  }

  /// Get current user's profile
  /// GET /users/me
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final token = await _getIdToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        throw ProfileRepositoryException('User profile not found');
      } else if (response.statusCode == 401) {
        throw ProfileRepositoryException('Authentication failed');
      } else {
        throw ProfileRepositoryException(
          'Failed to get profile: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ProfileRepositoryException) rethrow;
      throw ProfileRepositoryException('Network error: $e');
    }
  }

  /// Update user profile
  /// PATCH /users/me
  Future<void> updateUser(Map<String, dynamic> updates) async {
    try {
      final token = await _getIdToken();
      final response = await http.patch(
        Uri.parse('$baseUrl/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(updates),
      );

      if (response.statusCode == 200) {
        return;
      } else if (response.statusCode == 400) {
        final error = jsonDecode(response.body);
        throw ProfileValidationException(
          error['message'] ?? 'Validation failed',
          errors: error['errors'] as Map<String, dynamic>?,
        );
      } else if (response.statusCode == 401) {
        throw ProfileRepositoryException('Authentication failed');
      } else {
        throw ProfileRepositoryException(
          'Failed to update profile: ${response.statusCode}',
        );
      }
    } on ProfileRepositoryException {
      rethrow;
    } on ProfileValidationException {
      rethrow;
    } catch (e) {
      throw ProfileRepositoryException('Network error: $e');
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
