import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
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

/// RFC-007 §5's 409 body for a user with no match preferences row (MP-B4).
const _preferencesRequired = ConflictException(
  'Choose who you\'re interested in first',
  originalError: {
    'error': 'MATCH_PREFERENCES_REQUIRED',
    'message': 'Choose who you\'re interested in first',
  },
);

/// Answers `GET /match/` with each of [answers] in turn (an exception is thrown), then 204.
class _FakeMatchRepository implements MatchRepository {
  _FakeMatchRepository(this.answers);

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

Map<String, dynamic> _saved() {
  final body = mpFixture('get_users_me_match_preferences_defaults') as Map<String, dynamic>;
  body['isSet'] = true;
  body['gender'] = {'values': ['FEMALE'], 'dealbreaker': true};
  return body;
}

FakeMatchPreferencesApi _api() => FakeMatchPreferencesApi(responses: {
      // Options suggest women, as for a straight man.
      'GET $_optionsPath': mpFixture('get_match_preferences_options') as Object,
      'GET $_preferencesPath': mpFixture('get_users_me_match_preferences_defaults') as Object,
      'PATCH $_preferencesPath': _saved(),
    });

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
      matchPreferencesRepositoryProvider.overrideWithValue(
        MatchPreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: MatchScreen()),
  ));
  await tester.pumpAndSettle();
}

bool _ticked(WidgetTester tester, String label) => tester.any(find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.check_box),
    ));

void main() {
  group('MatchScreen and MATCH_PREFERENCES_REQUIRED', () {
    testWidgets('a 409 opens Interested in with the suggestion from options pre-ticked',
        (tester) async {
      final api = _api();
      await _pump(tester, _FakeMatchRepository([_preferencesRequired]), api);

      expect(find.text('Who are you interested in?'), findsOneWidget);
      expect(_ticked(tester, 'Female'), isTrue);
      expect(_ticked(tester, 'Male'), isFalse);
      // Nothing is saved until Continue.
      expect(api.requests.where((r) => r.method == 'PATCH'), isEmpty);
    });

    testWidgets('the sheet can\'t be closed without answering', (tester) async {
      await _pump(tester, _FakeMatchRepository([_preferencesRequired]), _api());

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Who are you interested in?'), findsOneWidget);

      // A tap on the barrier above the sheet doesn't close it either.
      await tester.tapAt(const Offset(400, 5));
      await tester.pumpAndSettle();
      expect(find.text('Who are you interested in?'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('a save sends gender, closes the sheet and reloads the batch', (tester) async {
      final matches = _FakeMatchRepository([_preferencesRequired]);
      final api = _api();
      await _pump(tester, matches, api);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final patch = api.requests.singleWhere((r) => r.method == 'PATCH');
      expect(patch.data, {
        'gender': {'values': ['FEMALE'], 'dealbreaker': true},
      });
      expect(find.text('Who are you interested in?'), findsNothing);
      expect(matches.fetches, 2);
      // The reload answered 204, which shows the usual empty state.
      expect(find.text('No matches available right now'), findsOneWidget);
    });

    testWidgets('a failed save keeps the sheet open with the error', (tester) async {
      final matches = _FakeMatchRepository([_preferencesRequired]);
      final api = _api();
      await _pump(tester, matches, api);
      api.error = const ServerException('down');

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Who are you interested in?'), findsOneWidget);
      expect(find.byKey(const Key('interested-in-error')), findsOneWidget);
      expect(matches.fetches, 1);
    });

    testWidgets('the sheet still asks when options fail, with nothing pre-ticked',
        (tester) async {
      final api = _api()..responses.remove('GET $_optionsPath');
      await _pump(tester, _FakeMatchRepository([_preferencesRequired]), api);

      expect(find.text('Who are you interested in?'), findsOneWidget);
      expect(_ticked(tester, 'Female'), isFalse);
    });

    testWidgets('any other 409 is shown as an error, not the sheet', (tester) async {
      const other = ConflictException('Something else', originalError: {'error': 'OTHER'});
      await _pump(tester, _FakeMatchRepository([other]), _api());

      expect(find.text('Who are you interested in?'), findsNothing);
      expect(find.text('Something else'), findsOneWidget);
    });
  });
}
