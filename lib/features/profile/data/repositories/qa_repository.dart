import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_collection_dto.dart';

/// Repository for Q&A related API calls
class QARepository {
  final String baseUrl;
  final FirebaseAuth _auth;
  final Logger _logger;

  QARepository({
    this.baseUrl = 'http://localhost:8940',
    FirebaseAuth? auth,
    Logger? logger,
  })  : _auth = auth ?? FirebaseAuth.instance,
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

  /// Get Firebase ID token for authentication
  /// Set [forceRefresh] to true to get a fresh token (e.g., after role claims update)
  Future<String> _getIdToken({bool forceRefresh = false}) async {
    _logger.d('Getting Firebase ID token for Q&A request (forceRefresh: $forceRefresh)...');
    final user = _auth.currentUser;
    if (user == null) {
      _logger.e('No authenticated user found');
      throw QARepositoryException('User not authenticated');
    }
    _logger.d('User authenticated: ${user.uid}');
    final token = await user.getIdToken(forceRefresh);
    if (token == null) {
      _logger.e('Failed to retrieve ID token');
      throw QARepositoryException('Failed to get authentication token');
    }
    _logger.d('Successfully retrieved ID token');
    return token;
  }

  /// Fetch all available questions from the backend
  /// GET /questions
  /// Automatically retries with token refresh on 403 (in case of stale token)
  Future<List<QuestionDTO>> getAllQuestions() async {
    final endpoint = '$baseUrl/questions';
    _logger.i('📤 GET $endpoint');

    try {
      return await _makeAuthenticatedRequest<List<QuestionDTO>>(
        () async {
          final token = await _getIdToken();
          return http.get(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );
        },
        (response) {
          final List<dynamic> jsonList = jsonDecode(response.body) as List;
          final questions = jsonList
              .map((json) => QuestionDTO.fromJson(json as Map<String, dynamic>))
              .toList();
          _logger.i('✅ Retrieved ${questions.length} questions');
          return questions;
        },
      );
    } catch (e, stackTrace) {
      if (e is QARepositoryException) rethrow;
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  /// Helper method to make authenticated requests with automatic retry on 403
  /// If we get a 403, it likely means the token doesn't have updated role claims
  /// We refresh the token and retry once
  Future<T> _makeAuthenticatedRequest<T>(
    Future<http.Response> Function() makeRequest,
    T Function(http.Response) parseResponse,
  ) async {
    // First attempt
    var response = await makeRequest();

    _logger.i('📥 Response status: ${response.statusCode}');
    _logger.d('Response body: ${response.body}');

    // If we get 403, refresh token and retry once
    if (response.statusCode == 403) {
      _logger.w('⚠️  403 Forbidden - Token may be stale, refreshing and retrying...');
      await _getIdToken(forceRefresh: true);

      // Retry with fresh token
      response = await makeRequest();
      _logger.i('📥 Retry response status: ${response.statusCode}');
      _logger.d('Retry response body: ${response.body}');
    }

    // Handle response
    if (response.statusCode == 200 || response.statusCode == 201) {
      return parseResponse(response);
    } else if (response.statusCode == 401) {
      _logger.e('🔒 Authentication failed (401)');
      throw QARepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } else if (response.statusCode == 403) {
      _logger.e('🚫 Forbidden (403) - Access denied even after token refresh');
      throw QARepositoryException(
        'You don\'t have permission to access this resource. Please complete your profile setup.',
      );
    } else {
      _logger.e('❌ Unexpected status code: ${response.statusCode}');
      _logger.e('Response body: ${response.body}');
      throw QARepositoryException(
        'We couldn\'t process your request. Please try again.',
      );
    }
  }

  /// Submit a collection of Q&As for the current user
  /// POST /users/qa/me/collection
  /// Automatically retries with token refresh on 403 (in case of stale token)
  Future<UserQACollectionDTO> submitQACollection(
    List<UserQAItemDTO> qas,
  ) async {
    final endpoint = '$baseUrl/users/qa/me/collection';
    _logger.i('📤 POST $endpoint');

    // Validate that we have 1-3 Q&As
    if (qas.isEmpty || qas.length > 3) {
      throw QARepositoryException(
        'You must provide between 1 and 3 Q&As',
      );
    }

    // Validate each Q&A
    for (final qa in qas) {
      if (qa.answer.trim().isEmpty) {
        throw QARepositoryException('All answers must be filled in');
      }
      if (qa.answer.length > 200) {
        throw QARepositoryException(
          'Answers must not exceed 200 characters',
        );
      }
      if (qa.displayOrder < 1 || qa.displayOrder > 3) {
        throw QARepositoryException(
          'Invalid display order for Q&A',
        );
      }
    }

    try {
      final userId = _auth.currentUser!.uid;

      return await _makeAuthenticatedRequest<UserQACollectionDTO>(
        () async {
          final token = await _getIdToken();

          final requestBody = {
            'userId': userId,
            'qas': qas.map((qa) => qa.toJson()).toList(),
            'totalCount': qas.length,
          };

          _logger.d('Request body: ${jsonEncode(requestBody)}');

          return http.post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(requestBody),
          );
        },
        (response) {
          if (response.statusCode == 400) {
            final error = jsonDecode(response.body);
            _logger.w('⚠️  Validation error: ${error['message']}');
            throw QARepositoryException(
              error['message'] ?? 'Invalid Q&A data',
            );
          }

          final collection = UserQACollectionDTO.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
          _logger.i('✅ Q&A collection submitted successfully');
          return collection;
        },
      );
    } on QARepositoryException {
      rethrow;
    } catch (e, stackTrace) {
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }

  /// Get the current user's Q&As
  /// GET /users/qa/me
  /// Automatically retries with token refresh on 403 (in case of stale token)
  Future<UserQACollectionDTO> getMyQAs() async {
    final endpoint = '$baseUrl/users/qa/me';
    _logger.i('📤 GET $endpoint');

    try {
      return await _makeAuthenticatedRequest<UserQACollectionDTO>(
        () async {
          final token = await _getIdToken();
          return http.get(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
            },
          );
        },
        (response) {
          if (response.statusCode == 404) {
            _logger.w('⚠️  No Q&As found (404)');
            // Return empty collection
            return UserQACollectionDTO(
              userId: _auth.currentUser!.uid,
              qas: [],
              totalCount: 0,
            );
          }

          final collection = UserQACollectionDTO.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>,
          );
          _logger.i('✅ Retrieved ${collection.totalCount} Q&As');
          return collection;
        },
      );
    } catch (e, stackTrace) {
      if (e is QARepositoryException) rethrow;
      _logger.e('💥 Network error', error: e, stackTrace: stackTrace);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    }
  }
}

/// Base exception for Q&A repository errors
class QARepositoryException implements Exception {
  final String message;

  QARepositoryException(this.message);

  @override
  String toString() => 'QARepositoryException: $message';
}
