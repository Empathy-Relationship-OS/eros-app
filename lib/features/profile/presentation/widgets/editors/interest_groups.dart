import 'package:eros_app/features/profile/domain/enums/interests.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/multi_choice_editor.dart';

/// Interest categories, one tab each, as display names (what `interests` stores). Shared by
/// onboarding and the profile editor.
final List<MultiChoiceGroup<String>> interestGroups = [
  MultiChoiceGroup('Sports', Sport.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Food & Drink', FoodAndDrink.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Creative', Creative.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Entertainment', Entertainment.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Music', MusicGenre.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Activities', Activity.values.map((e) => e.displayName).toList()),
  MultiChoiceGroup('Interests', Interest.values.map((e) => e.displayName).toList()),
];

/// Interests must number between these (backend `UpdateUserRequest`).
const int minInterests = 5;
const int maxInterests = 10;
