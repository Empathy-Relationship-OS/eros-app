import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/network/api_endpoints.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/question_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_item_dto.dart';
import 'package:eros_app/features/profile/domain/models/user_qa_collection_dto.dart';

/// Repository for Q&A related API calls
class QARepository {
  final ApiClient _apiClient;
  final AuthService _authService;
  final Logger _logger;

  QARepository({
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

  /// Fetch all available questions from the backend
  /// GET /questions
  Future<List<QuestionDTO>> getAllQuestions() async {
    try {
      _logger.i('❓ Getting all questions');

      final response = await _apiClient.get<List<dynamic>>(
        '/questions',
      );

      final questions = response
          .map((json) => QuestionDTO.fromJson(json as Map<String, dynamic>))
          .toList();

      _logger.i('✅ Retrieved ${questions.length} questions');
      return questions;
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw QARepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Access denied');
      throw QARepositoryException(
        'You don\'t have permission to access this resource. Please complete your profile setup.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw QARepositoryException(
        'We couldn\'t process your request. Please try again.',
      );
    }
  }

  /// Submit a collection of Q&As for the current user
  /// POST /users/qa/me/collection
  Future<UserQACollectionDTO> submitQACollection(
    List<UserQAItemDTO> qas,
  ) async {
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
      _logger.i('💾 Submitting Q&A collection with ${qas.length} items');

      final userId = _authService.getUserId();

      final requestBody = {
        'userId': userId,
        'qas': qas.map((qa) => qa.toJson()).toList(),
        'totalCount': qas.length,
      };

      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiEndpoints.qa.createOrUpdateCollection(),
        data: requestBody,
      );

      final collection = UserQACollectionDTO.fromJson(response);
      _logger.i('✅ Q&A collection submitted successfully');
      return collection;
    } on ValidationException catch (e) {
      _logger.w('⚠️  Validation error: ${e.message}');
      throw QARepositoryException(
        e.message,
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw QARepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Access denied');
      throw QARepositoryException(
        'You don\'t have permission to access this resource. Please complete your profile setup.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw QARepositoryException(
        'We couldn\'t process your request. Please try again.',
      );
    }
  }

  /// Get the current user's Q&As
  /// GET /users/qa/me
  Future<UserQACollectionDTO> getMyQAs() async {
    try {
      _logger.i('🔍 Getting current user Q&As');

      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiEndpoints.qa.getCurrentUserQA(),
      );

      final collection = UserQACollectionDTO.fromJson(response);
      _logger.i('✅ Retrieved ${collection.totalCount} Q&As');
      return collection;
    } on NotFoundException {
      _logger.w('⚠️  No Q&As found (404)');
      // Return empty collection
      return UserQACollectionDTO(
        userId: _authService.getUserId(),
        qas: [],
        totalCount: 0,
      );
    } on UnauthorizedException {
      _logger.e('🔒 Authentication failed (401)');
      throw QARepositoryException(
        'There was a problem verifying your identity. Please try signing in again.',
      );
    } on ForbiddenException {
      _logger.e('🚫 Forbidden (403) - Access denied');
      throw QARepositoryException(
        'You don\'t have permission to access this resource. Please complete your profile setup.',
      );
    } on NetworkException catch (e) {
      _logger.e('💥 Network error', error: e);
      throw QARepositoryException(
        'Unable to connect to the server. Please check your internet connection and try again.',
      );
    } on ApiException catch (e) {
      _logger.e('❌ Unexpected error', error: e);
      throw QARepositoryException(
        'We couldn\'t process your request. Please try again.',
      );
    }
  }
}

/// Riverpod provider for QARepository
final qaRepositoryProvider = Provider<QARepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final authService = ref.watch(authServiceProvider);
  return QARepository(
    apiClient: apiClient,
    authService: authService,
  );
});

/// Base exception for Q&A repository errors
class QARepositoryException implements Exception {
  final String message;

  QARepositoryException(this.message);

  @override
  String toString() => 'QARepositoryException: $message';
}
