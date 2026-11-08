import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_preferences_screen.dart';
import 'package:eros_app/features/matching/data/repositories/match_repository.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/matching/presentation/screens/match_screen.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../match_preferences/fake_match_preferences_api.dart';

const _preferencesPath = '/users/me/match-preferences';
const _optionsPath = '/match-preferences/options';

const _dealbreakerCopy = 'You\'ve seen everyone who fits your dealbreakers for now';
const _usualCopy = 'No matches available right now';

/// Answers `GET /match/` with each of [answers] in turn (an exception is thrown), then 204.
class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository([this.answers = const []]);

  final List<Object?> answers;
  int fetches = 0;

  @override
  Future<DailyBatchResponse?> fetchDailyBatch() async {
    final answer = fetches < answers.length ? answers[fetches] : null;
    fetches++;
    if (answer is Exception) throw answer;
    return answer as DailyBatchResponse?;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A user who has said who they're interested in. [dealbreakers] names the filters switched to
/// dealbreakers; every other one, Age included, is a preference.
Map<String, dynamic> _preferences({Set<String> dealbreakers = const {}}) {
  final body = mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>;
  body['isSet'] = true;
  body['gender'] = {'values': ['FEMALE'], 'dealbreaker': true};
  for (final key in body.keys.where((k) => k != 'isSet' && k != 'gender')) {
    (body[key] as Map<String, dynamic>)['dealbreaker'] = dealbreakers.contains(key);
  }
  return body;
}

FakeMatchPreferencesApi _api(Map<String, dynamic> preferences) => FakeMatchPreferencesApi(
      responses: {
        'GET $_optionsPath': mpFixture('get_match_preferences_options') as Object,
        'GET $_preferencesPath': preferences,
      },
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeMatchRepository matches,
  FakeMatchPreferencesApi api,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      matchRepositoryProvider.overrideWithValue(matches),
      // The hub's banner is remembered per user; no Firebase here.
      matchPreferencesBannerUidProvider.overrideWithValue('alice'),
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: MatchScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('MatchScreen empty batch (RFC-007 §6.4)', () {
    testWidgets('a 204 with a dealbreaker on says so, with a Match preferences button',
        (tester) async {
      await _pump(tester, _FakeMatchRepository(), _api(_preferences(dealbreakers: {'age'})));

      expect(find.text(_dealbreakerCopy), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Match preferences'), findsOneWidget);
      expect(find.text(_usualCopy), findsNothing);
      // Never a count of people (D-16).
      expect(find.textContaining(RegExp(r'\d')), findsNothing);
    });

    testWidgets('Match preferences opens the hub, and coming back loads the batch again',
        (tester) async {
      final matches = _FakeMatchRepository();
      await _pump(tester, matches, _api(_preferences(dealbreakers: {'religion'})));

      await tester.tap(find.widgetWithText(ElevatedButton, 'Match preferences'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchPreferencesScreen), findsOneWidget);
      expect(matches.fetches, 1);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchPreferencesScreen), findsNothing);
      expect(matches.fetches, 2);
      expect(find.text(_dealbreakerCopy), findsOneWidget);
    });

    testWidgets('a 204 with no dealbreaker keeps today\'s copy', (tester) async {
      await _pump(tester, _FakeMatchRepository(), _api(_preferences()));

      expect(find.text(_usualCopy), findsOneWidget);
      expect(find.text(_dealbreakerCopy), findsNothing);
      expect(find.text('Match preferences'), findsNothing);
    });

    testWidgets('Interested in alone doesn\'t count: it is always a dealbreaker (D-4)',
        (tester) async {
      final preferences = _preferences();
      expect((preferences['gender'] as Map)['dealbreaker'], isTrue);
      await _pump(tester, _FakeMatchRepository(), _api(preferences));

      expect(find.text(_dealbreakerCopy), findsNothing);
    });

    testWidgets('preferences that fail to load keep today\'s copy', (tester) async {
      final api = _api(_preferences(dealbreakers: {'age'}))
        ..error = const ServerException('down');
      await _pump(tester, _FakeMatchRepository(), api);

      expect(find.text(_usualCopy), findsOneWidget);
      expect(find.text(_dealbreakerCopy), findsNothing);
    });

    testWidgets('an error that isn\'t a 204 shows the error, even with dealbreakers on',
        (tester) async {
      await _pump(
        tester,
        _FakeMatchRepository([const ServerException('Something went wrong')]),
        _api(_preferences(dealbreakers: {'age'})),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text(_dealbreakerCopy), findsNothing);
    });
  });
}
