import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/enums/interests.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/screens/height_input_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/interests/interests_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/languages_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/location_input_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/personality/personality_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'onboarding_harness.dart';

/// Answers `checkUserExists` with [exists]; nothing else is used by these screens.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({required this.exists});

  final bool exists;

  @override
  Future<UserExistsResponse> checkUserExists() async => UserExistsResponse(exists: exists, userId: 'u1');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// These tests drive the screens only through what a user sees, so they pass against the
/// screens before and after the editors were extracted: the drafts written are the same.
void main() {
  group('InterestsScreen', () {
    final sports = Sport.values.map((e) => e.displayName).toList();

    testWidgets('saves the chosen interests in the order chosen, across tabs', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const InterestsScreen());

      expect(find.text('Select 5 more'), findsOneWidget);
      for (final sport in sports.take(4)) {
        await tester.tap(find.text(sport));
        await tester.pump();
      }
      await tester.tap(find.text('Food & Drink'));
      await tester.pumpAndSettle();
      final food = FoodAndDrink.values.first.displayName;
      await tester.tap(find.text(food));
      await tester.pump();

      expect(find.text('5/10 selected'), findsOneWidget);
      await harness.tapContinue(tester);

      expect(harness.draft.interests, [...sports.take(4), food]);
      expect(harness.pushed, ['/profile-creation/personality']);
    });

    testWidgets('search filters the grid', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const InterestsScreen());

      await tester.enterText(find.byType(TextField), sports[1].substring(0, 4));
      await tester.pump();

      Finder inGrid(String text) =>
          find.descendant(of: find.byType(GridView), matching: find.text(text));
      expect(inGrid(sports[1]), findsOneWidget);
      expect(inGrid(sports.last), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text('No interests found'), findsOneWidget);
    });

    testWidgets('stops at 10, and a chip removes its interest', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const InterestsScreen());

      for (final sport in sports.take(11)) {
        await tester.tap(find.text(sport).first);
        await tester.pump();
      }
      expect(find.text('10/10 selected'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(find.text('9/10 selected'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pump();
      expect(find.text('0/10 selected'), findsOneWidget);
    });

    testWidgets('restores the draft', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const InterestsScreen(),
        initialDraft: ProfileCreationDraft(interests: sports.take(5).toList()),
      );

      expect(find.text('5/10 selected'), findsOneWidget);
      await harness.tapContinue(tester);
      expect(harness.draft.interests, sports.take(5).toList());
    });
  });

  group('PersonalityScreen', () {
    final traits = Trait.values.take(3).toList();

    Future<OnboardingHarness> chooseTraits(WidgetTester tester, {required bool exists}) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const PersonalityScreen(),
        overrides: [profileRepositoryProvider.overrideWithValue(_FakeProfileRepository(exists: exists))],
      );
      for (final trait in traits) {
        await tester.tap(find.text(trait.displayName));
        await tester.pump();
      }
      return harness;
    }

    testWidgets('saves traits and no star sign, then goes to submission', (tester) async {
      final harness = await chooseTraits(tester, exists: false);

      await harness.tapContinue(tester);

      expect(harness.draft.traits, traits);
      expect(harness.draft.starSign?.field, isNull);
      expect(harness.draft.starSign?.visible, isFalse);
      expect(harness.pushed, ['/profile-creation/submit']);
    });

    testWidgets('saves a hidden star sign, and skips to Q&A when the user exists', (tester) async {
      final harness = await chooseTraits(tester, exists: true);

      await tester.tap(find.text('Star Sign'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(StarSign.values[2].displayName));
      await tester.pump();
      await tester.tap(find.text('Show on my profile'));
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.starSign?.field, StarSign.values[2]);
      expect(harness.draft.starSign?.visible, isFalse);
      expect(harness.pushed, ['/profile-creation/qa']);
    });

    testWidgets('Continue needs 3 traits', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const PersonalityScreen());

      await tester.tap(find.text(traits.first.displayName));
      await tester.pump();

      expect(find.text('Select 2 more'), findsOneWidget);
      expect(find.text('1/10 selected'), findsOneWidget);
    });
  });

  group('LanguagesScreen', () {
    final english = Languages.all[0];
    final spanish = Languages.all[1];

    testWidgets('saves the chosen languages and makes the first one preferred', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const LanguagesScreen());

      await tester.tap(find.text(spanish.name));
      await tester.pump();
      await tester.tap(find.text(english.name).first); // name and native name are both English
      await tester.pump();
      expect(find.text('2 languages selected'), findsOneWidget);
      await harness.tapContinue(tester);

      expect(harness.draft.spokenLanguages?.field, [spanish, english]);
      expect(harness.draft.spokenLanguages?.visible, isTrue);
      expect(harness.draft.preferredLanguage, spanish);
      expect(harness.pushed, ['/profile-creation/height']);
    });

    testWidgets('starts from the preferred language and keeps it', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const LanguagesScreen(),
        initialDraft: ProfileCreationDraft(preferredLanguage: english),
      );

      expect(find.text('1 language selected'), findsOneWidget);
      await tester.tap(find.text(spanish.name));
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.spokenLanguages?.field, [english, spanish]);
      expect(harness.draft.preferredLanguage, english);
    });

    testWidgets('Continue is disabled with nothing selected', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const LanguagesScreen());

      await harness.tapContinue(tester);

      expect(harness.pushed, isEmpty);
    });
  });

  group('HeightInputScreen', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    testWidgets('saves feet and inches as cm', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const HeightInputScreen());

      await tester.enterText(field('Feet'), '5');
      await tester.enterText(field('Inches'), '9');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.heightCm, 175);
      expect(harness.pushed, ['/profile-creation/education']);
    });

    testWidgets('saves cm, converting what was typed in feet', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const HeightInputScreen());

      await tester.enterText(field('Feet'), '6');
      await tester.enterText(field('Inches'), '0');
      await tester.pump();
      await tester.tap(find.text('CM'));
      await tester.pump();

      expect(find.text('183'), findsOneWidget);
      await tester.enterText(field('Height (cm)'), '181');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.heightCm, 181);
    });

    testWidgets('an invalid height keeps Continue disabled', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const HeightInputScreen());

      await tester.enterText(field('Feet'), '5');
      await tester.enterText(field('Inches'), '12');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.pushed, isEmpty);
    });

    testWidgets('a restored height needs an edit before Continue, and round-trips through feet',
        (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const HeightInputScreen(),
        initialDraft: ProfileCreationDraft(heightCm: 171),
      );

      await harness.tapContinue(tester);
      expect(harness.pushed, isEmpty);

      // Retyping the same inches: 171 cm shows as 5'7", which is saved as 170 cm.
      await tester.enterText(field('Inches'), '7');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.draft.heightCm, 170);
    });
  });

  group('LocationInputScreen', () {
    testWidgets('saves the picked city and its coordinates', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const LocationInputScreen());

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'man');
      await tester.pump();
      await tester.tap(find.text('Manchester'));
      await tester.pump();

      expect(find.text('100+ venues in Manchester'), findsOneWidget);
      await harness.tapContinue(tester);

      expect(harness.draft.city, 'Manchester');
      expect(harness.draft.coordinatesLatitude, 53.4808);
      expect(harness.draft.coordinatesLongitude, -2.2426);
      expect(harness.pushed, ['/profile-creation/dating-cities']);
    });

    testWidgets('"Use my location" says it is coming and switches to typing', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const LocationInputScreen());

      await tester.tap(find.text('Use my location'));
      await tester.pump();

      expect(find.text('GPS location feature coming soon. Please enter city manually.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('clearing the field disables Continue', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const LocationInputScreen(),
        initialDraft: ProfileCreationDraft(city: 'London', coordinatesLatitude: 51.5074, coordinatesLongitude: -0.1278),
      );

      await tester.tap(find.text('Enter location manually'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await harness.tapContinue(tester);

      expect(harness.pushed, isEmpty);
    });

    testWidgets('a restored city can continue straight away', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(
        tester,
        const LocationInputScreen(),
        initialDraft: ProfileCreationDraft(city: 'London', coordinatesLatitude: 51.5074, coordinatesLongitude: -0.1278),
      );

      await harness.tapContinue(tester);

      expect(harness.draft.city, 'London');
      expect(harness.pushed, ['/profile-creation/dating-cities']);
    });
  });
}
