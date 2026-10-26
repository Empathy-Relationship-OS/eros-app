import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/utils/user_text.dart';

/// Shortest answer accepted, in characters after cleaning.
const int qaAnswerMinLength = 2;

/// Why [raw] can't be saved as a Q&A answer, or null when it can. Shared by onboarding's
/// `AnswerInputScreen` and the profile editor's Q&A section.
///
/// The answer is checked as it will be saved: cleaned by [UserText] with line breaks kept, and
/// counted in code points against [UserTextLimits.qaAnswer] (RFC-004 D-16). Text that only looks
/// like SQL or HTML is ordinary writing and is accepted.
String? qaAnswerError(String raw) {
  final length = UserText.length(cleanQAAnswer(raw));
  if (length < qaAnswerMinLength) return 'This answer is not long enough';
  if (length > UserTextLimits.qaAnswer) return 'Answer exceeds maximum length';
  return null;
}

/// [raw] as it is saved: cleaned, line breaks kept.
String cleanQAAnswer(String raw) => UserText.clean(raw, multiline: true);
