import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/utils/user_text.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/data/repositories/safety_repository.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// Who, or which of their photos, a report outside a date is about.
typedef ContentReportTarget = ({String userId, int? mediaId});

/// The report form outside a date: what's chosen, and how the submit went.
class ContentReportState {
  final ContentReportCategory? category;

  /// As typed. Cleaned with `UserText` only when submitted.
  final String description;
  final bool isSubmitting;

  /// Set once the report is filed (or was already filed).
  final ContentReportResult? result;

  /// The backend can't find them for this viewer any more (404): they're already hidden.
  final bool gone;

  /// A problem with the whole form, shown near the submit button.
  final String? errorMessage;

  const ContentReportState({
    this.category,
    this.description = '',
    this.isSubmitting = false,
    this.result,
    this.gone = false,
    this.errorMessage,
  });

  /// The report is done with: filed, or nothing left to report. Either way the profile should
  /// leave the screen.
  bool get finished => result != null || gone;

  ContentReportState copyWith({
    ContentReportCategory? category,
    String? description,
    bool? isSubmitting,
    ContentReportResult? result,
    bool? gone,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ContentReportState(
      category: category ?? this.category,
      description: description ?? this.description,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      gone: gone ?? this.gone,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Holds one report on a profile or a photo (RFC-009 §5.5, CF-F4). Logs ids only: the
/// description is never logged (primer rule 3).
class ContentReportNotifier extends StateNotifier<ContentReportState> {
  final SafetyRepository _repository;
  final ContentReportTarget _target;
  final Logger _logger = Logger();

  ContentReportNotifier(this._repository, this._target) : super(const ContentReportState());

  void selectCategory(ContentReportCategory category) {
    state = state.copyWith(category: category, clearErrorMessage: true);
  }

  void setDescription(String raw) {
    state = state.copyWith(description: raw);
  }

  /// The first problem that stops the form being sent, or null.
  String? validate() {
    if (state.category == null) return SafetyCopy.chooseCategory;
    return UserText.validate(
      state.description,
      name: 'Description',
      maxLength: UserTextLimits.reportDescription,
      multiline: true,
    );
  }

  /// Files the report. Returns true when it's finished with ([ContentReportState.finished]).
  Future<bool> submit() async {
    if (state.isSubmitting || state.finished) return state.finished;
    final error = validate();
    if (error != null) {
      state = state.copyWith(errorMessage: error);
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearErrorMessage: true);
    final description = UserText.clean(state.description, multiline: true);
    try {
      final result = await _repository.reportContent(
        ContentReportRequest(
          targetUserId: _target.userId,
          targetMediaId: _target.mediaId,
          category: state.category!,
          description: description.isEmpty ? null : description,
        ),
      );
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false, result: result);
      return true;
    } on NotFoundException {
      if (!mounted) return true;
      state = state.copyWith(isSubmitting: false, gone: true, errorMessage: SafetyCopy.profileGone);
      return true;
    } on NetworkException {
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: SafetyCopy.networkError);
    } catch (e) {
      _logger.e('🚨 Content report failed for user ${_target.userId}');
      if (!mounted) return false;
      state = state.copyWith(isSubmitting: false, errorMessage: SafetyCopy.submitFailed);
    }
    return false;
  }
}

/// One report form per target, dropped when the sheet closes.
final contentReportProvider = StateNotifierProvider.autoDispose
    .family<ContentReportNotifier, ContentReportState, ContentReportTarget>((ref, target) {
  return ContentReportNotifier(ref.watch(safetyRepositoryProvider), target);
});
