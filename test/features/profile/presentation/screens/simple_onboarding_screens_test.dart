import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/screens/education_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/alcohol_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/bio_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/date_intentions_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/diet_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/kids_preference_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/occupation_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/political_view_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/pronouns_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/relationship_type_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/religion_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/sexual_orientation_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/preferences/smoking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

/// One `DisplayableChoiceEditor` screen and what it writes.
class _ChoiceScreen<T extends Enum> {
  final String name;
  final Widget Function() build;
  final List<T> values;
  final String Function(T) labelOf;
  final T? preferNotToSay;
  final DisplayableField<dynamic>? Function(ProfileCreationDraft) read;
  final String nextRoute;

  const _ChoiceScreen(
    this.name,
    this.build,
    this.values,
    this.labelOf,
    this.read,
    this.nextRoute, {
    this.preferNotToSay,
  });

  void define() {
    group(name, () {
      testWidgets('saves the choice, shown by default, and moves on', (tester) async {
        final harness = OnboardingHarness();
        await harness.pump(tester, build());

        await tester.tap(find.text(labelOf(values.first)));
        await tester.pump();
        await harness.tapContinue(tester);

        expect(read(harness.draft)?.field, values.first);
        expect(read(harness.draft)?.visible, isTrue);
        expect(harness.pushed, [nextRoute]);
      });

      testWidgets('saves it hidden when "Show on my profile" is unticked', (tester) async {
        final harness = OnboardingHarness();
        await harness.pump(tester, build());

        await tester.tap(find.text(labelOf(values.first)));
        await tester.pump();
        await tester.tap(find.text('Show on my profile'));
        await tester.pump();
        await harness.tapContinue(tester);

        expect(read(harness.draft)?.field, values.first);
        expect(read(harness.draft)?.visible, isFalse);
      });

      if (preferNotToSay != null) {
        testWidgets('"prefer not to say" hides the checkbox and saves hidden', (tester) async {
          final harness = OnboardingHarness();
          await harness.pump(tester, build());

          await tester.tap(find.text(labelOf(preferNotToSay as T)));
          await tester.pump();

          expect(find.text('Show on my profile'), findsNothing);
          await harness.tapContinue(tester);

          expect(read(harness.draft)?.field, preferNotToSay);
          expect(read(harness.draft)?.visible, isFalse);
        });
      }
    });
  }
}

void main() {
  const route = '/profile-creation/preferences';

  final choiceScreens = <_ChoiceScreen<dynamic>>[
    _ChoiceScreen<AlcoholConsumption>('AlcoholScreen', () => const AlcoholScreen(),
        AlcoholConsumption.values, (v) => v.displayName, (d) => d.alcoholConsumption, '$route/smoking',
        preferNotToSay: AlcoholConsumption.preferNotToSay),
    _ChoiceScreen<Diet>('DietScreen', () => const DietScreen(), Diet.values, (v) => v.displayName,
        (d) => d.diet, '$route/complete',
        preferNotToSay: Diet.preferNotToSay),
    _ChoiceScreen<KidsPreference>('KidsPreferenceScreen', () => const KidsPreferenceScreen(),
        KidsPreference.values, (v) => v.displayName, (d) => d.kidsPreference, '$route/alcohol',
        preferNotToSay: KidsPreference.preferNotToSay),
    _ChoiceScreen<PoliticalView>('PoliticalViewScreen', () => const PoliticalViewScreen(),
        PoliticalView.values, (v) => v.displayName, (d) => d.politicalView, '$route/diet',
        preferNotToSay: PoliticalView.preferNotToSay),
    _ChoiceScreen<Pronouns>('PronounsScreen', () => const PronounsScreen(), Pronouns.values,
        (v) => v.displayName, (d) => d.pronouns, '$route/religion',
        preferNotToSay: Pronouns.preferNotToSay),
    _ChoiceScreen<Religion>('ReligionScreen', () => const ReligionScreen(), Religion.values,
        (v) => v.displayName, (d) => d.religion, '$route/political-view',
        preferNotToSay: Religion.preferNotToSay),
    _ChoiceScreen<SexualOrientation>('SexualOrientationScreen', () => const SexualOrientationScreen(),
        SexualOrientation.values, (v) => v.displayName, (d) => d.sexualOrientation, '$route/bio',
        preferNotToSay: SexualOrientation.preferNotToSay),
    _ChoiceScreen<SmokingStatus>('SmokingScreen', () => const SmokingScreen(), SmokingStatus.values,
        (v) => v.displayName, (d) => d.smokingStatus, '$route/occupation',
        preferNotToSay: SmokingStatus.preferNotToSay),
    _ChoiceScreen<DateIntentions>('DateIntentionsScreen', () => const DateIntentionsScreen(),
        DateIntentions.values, (v) => v.displayName, (d) => d.dateIntentions, '$route/kids'),
    _ChoiceScreen<RelationshipType>('RelationshipTypeScreen', () => const RelationshipTypeScreen(),
        RelationshipType.values, (v) => v.displayName, (d) => d.relationshipType,
        '$route/sexual-orientation'),
  ];
  for (final screen in choiceScreens) {
    screen.define();
  }

  group('EducationScreen', () {
    testWidgets('saves the choice and moves on', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const EducationScreen());

      await tester.tap(find.text(EducationLevel.college.displayName));
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.educationLevel, EducationLevel.college);
      expect(harness.pushed, ['/profile-creation/phone']);
    });

    testWidgets('Continue does nothing until a level is chosen', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const EducationScreen());

      await harness.tapContinue(tester);

      expect(harness.draft.educationLevel, isNull);
      expect(harness.pushed, isEmpty);
    });
  });

  group('BioScreen', () {
    testWidgets('saves the sanitized bio and moves on', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const BioScreen());

      expect(find.text('0/300'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Loves "hiking"; coffee');
      await tester.pump();
      expect(find.text('22/300'), findsOneWidget);
      await harness.tapContinue(tester);

      expect(harness.draft.bio, 'Loves hiking coffee');
      expect(harness.pushed, ['$route/pronouns']);
    });

    testWidgets('Skip saves an empty bio', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const BioScreen());

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(harness.draft.bio, '');
      expect(harness.pushed, ['$route/pronouns']);
    });
  });

  group('OccupationScreen', () {
    testWidgets('saves the occupation and moves on', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const OccupationScreen());

      expect(find.text('Job / Occupation'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Engineer');
      await harness.tapContinue(tester);

      expect(harness.draft.occupation, 'Engineer');
      expect(harness.pushed, ['$route/relationship-type']);
    });

    testWidgets('an empty occupation is saved as null', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const OccupationScreen());

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      expect(harness.draft.occupation, isNull);
      expect(harness.pushed, ['$route/relationship-type']);
    });
  });
}
