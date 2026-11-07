import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/screens/gender_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/interested_in_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

bool _ticked(WidgetTester tester, String label) => tester.any(find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.check_box),
    ));

bool _continueEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed != null;

void main() {
  group('InterestedInStepScreen', () {
    testWidgets('follows the gender step', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const GenderScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Female'));
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.pushed, ['/profile-creation/interested-in']);
    });

    testWidgets('pre-ticks nothing before orientation is asked, so Continue starts disabled',
        (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const InterestedInStepScreen(),
        initialDraft: ProfileCreationDraft(gender: Gender.male),
      );
      await tester.pumpAndSettle();

      expect(find.text('Step 5 of 11'), findsOneWidget);
      for (final label in ['Male', 'Female', 'Non-Binary', 'Other']) {
        expect(_ticked(tester, label), isFalse);
      }
      expect(_continueEnabled(tester), isFalse);
    });

    testWidgets('pre-ticks the suggestion when the draft already has an orientation',
        (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const InterestedInStepScreen(),
        initialDraft: ProfileCreationDraft(
          gender: Gender.male,
          sexualOrientation: DisplayableField(field: SexualOrientation.straight),
        ),
      );
      await tester.pumpAndSettle();

      expect(_ticked(tester, 'Female'), isTrue);
      expect(_ticked(tester, 'Male'), isFalse);
      // A suggestion is only a suggestion: nothing is in the draft until Continue.
      expect(harness.draft.interestedIn, isNull);
    });

    testWidgets('keeps the choice in the draft and goes on to date of birth', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const InterestedInStepScreen(),
        initialDraft: ProfileCreationDraft(gender: Gender.female),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Non-Binary'));
      await tester.pump();
      await tester.tap(find.text('Female'));
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.interestedIn, [Gender.female, Gender.nonBinary]);
      expect(harness.pushed, ['/profile-creation/dob']);
    });

    testWidgets('shows an earlier answer rather than the suggestion', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const InterestedInStepScreen(),
        initialDraft: ProfileCreationDraft(
          gender: Gender.male,
          sexualOrientation: DisplayableField(field: SexualOrientation.straight),
          interestedIn: [Gender.other],
        ),
      );
      await tester.pumpAndSettle();

      expect(_ticked(tester, 'Other'), isTrue);
      expect(_ticked(tester, 'Female'), isFalse);
    });
  });

  group('ProfileCreationDraft.interestedIn', () {
    test('survives a round trip through storage', () {
      final draft = ProfileCreationDraft(interestedIn: [Gender.male, Gender.nonBinary]);

      final restored = ProfileCreationDraft.fromJson(draft.toJson());

      expect(restored.interestedIn, [Gender.male, Gender.nonBinary]);
      expect(ProfileCreationDraft.fromJson({}).interestedIn, isNull);
    });
  });
}
