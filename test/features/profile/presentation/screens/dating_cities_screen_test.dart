import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/screens/dating_cities_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../date_preferences/fake_date_preferences_api.dart';
import 'onboarding_harness.dart';

FakeDatePreferencesApi _api() =>
    FakeDatePreferencesApi(responses: {'GET /city/all': dpFixture('get_city_all') as Object});

Future<OnboardingHarness> _pump(
  WidgetTester tester,
  FakeDatePreferencesApi api, {
  ProfileCreationDraft? initialDraft,
}) async {
  final harness = OnboardingHarness();
  await harness.pump(
    tester,
    const DatingCitiesScreen(),
    initialDraft: initialDraft,
    overrides: [
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
  );
  await tester.pumpAndSettle();
  return harness;
}

bool _selected(WidgetTester tester, String city) =>
    tester.widget<FilterChip>(find.widgetWithText(FilterChip, city)).selected;

bool _continueEnabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue')).onPressed !=
    null;

void main() {
  group('DatingCitiesScreen', () {
    testWidgets('shows the cities from GET /city/all, with Continue disabled until one is chosen',
        (tester) async {
      await _pump(tester, _api());

      expect(find.widgetWithText(FilterChip, 'London'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Houston'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Dallas'), findsOneWidget);
      // The old hard-coded list is gone.
      expect(find.text('Manchester'), findsNothing);
      expect(_continueEnabled(tester), isFalse);
    });

    testWidgets('saves the chosen city ids to the draft, in the order chosen', (tester) async {
      final harness = await _pump(tester, _api());

      await tester.tap(find.text('Houston'));
      await tester.pump();
      await tester.tap(find.text('London'));
      await tester.pump();
      expect(find.text('2 cities selected'), findsOneWidget);

      await harness.tapContinue(tester);

      expect(harness.draft.datingCityIds, [2, 1]);
      expect(harness.pushed, ['/profile-creation/gender']);
    });

    testWidgets('restores its selection from the draft', (tester) async {
      await _pump(tester, _api(), initialDraft: ProfileCreationDraft(datingCityIds: [2]));

      expect(_selected(tester, 'Houston'), isTrue);
      expect(_selected(tester, 'London'), isFalse);
      expect(find.text('1 city selected'), findsOneWidget);
      expect(_continueEnabled(tester), isTrue);
    });

    testWidgets('never sends a restored city the server no longer lists', (tester) async {
      final harness =
          await _pump(tester, _api(), initialDraft: ProfileCreationDraft(datingCityIds: [99, 1]));

      expect(find.text('1 city selected'), findsOneWidget);
      await harness.tapContinue(tester);

      expect(harness.draft.datingCityIds, [1]);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final api = _api();
      final cities = api.responses.remove('GET /city/all')!;
      await _pump(tester, api);

      expect(find.text('We couldn\'t load the cities. Please try again.'), findsOneWidget);
      expect(_continueEnabled(tester), isFalse);

      api.responses['GET /city/all'] = cities;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'London'), findsOneWidget);
    });
  });
}
