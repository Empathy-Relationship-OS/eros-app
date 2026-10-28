import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/date_preferences/data/date_preferences_repository.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/date_preferences_screen.dart';
import 'package:eros_app/features/date_preferences/presentation/screens/edit_date_types_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../fake_date_preferences_api.dart';

const _preferencesPath = 'GET /users/me/date-preferences';
const _optionsPath = 'GET /date-preferences/options';
const _patchPath = 'PATCH /users/me/date-preferences';

// The fixture user loves Dinner (3), hasn't set Drinks (2, so "Happy to") and says "Not for me"
// to Coffee (1). The London options list Dinner, Drinks, Coffee, in that order.
const _dinner = 3;
const _drinks = 2;
const _coffee = 1;

Map<String, dynamic> _preferences() =>
    dpFixture('get_users_me_date_preferences') as Map<String, dynamic>;

Map<String, dynamic> _londonOptions() =>
    dpFixture('get_date_preferences_options_london') as Map<String, dynamic>;

List<Map<String, dynamic>> _activities(Map<String, dynamic> options) =>
    (options['activities'] as List<dynamic>).cast<Map<String, dynamic>>();

Map<String, dynamic> _activity(Map<String, dynamic> options, int id) =>
    _activities(options).singleWhere((a) => a['activityId'] == id);

/// The London options with a coming-soon activity added at the end.
Map<String, dynamic> _withBowling() {
  final options = _londonOptions();
  (options['activities'] as List<dynamic>).add({
    'activityId': 7,
    'name': 'Bowling',
    'category': 'ACTIVE',
    'status': 'COMING_SOON',
    'tokenCost': 1.50,
    'durationMinutes': 120,
    'description': 'A few frames and a drink',
    'iconUrl': null,
    'ageNote': null,
  });
  return options;
}

/// What the server returns after saving [levels].
Map<String, dynamic> _saved(Map<int, String> levels) => _preferences()
  ..['activities'] = [
    for (final entry in levels.entries) {'activityId': entry.key, 'level': entry.value},
  ];

FakeDatePreferencesApi _api({Map<String, dynamic>? options, Map<String, dynamic>? saved}) {
  return FakeDatePreferencesApi(responses: {
    _preferencesPath: _preferences(),
    _optionsPath: options ?? _londonOptions(),
    _patchPath: ?saved,
  });
}

/// Opens the hub, then the Date types editor from its row.
///
/// The view is tall enough for every row and the "keep one" notice above them.
Future<void> _open(WidgetTester tester, FakeDatePreferencesApi api) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      datePreferencesRepositoryProvider.overrideWithValue(
        DatePreferencesRepository(apiClient: api, logger: Logger(level: Level.off)),
      ),
    ],
    child: const MaterialApp(home: DatePreferencesScreen()),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Love it')); // the hub's Dinner line, in the Date types card
  await tester.pumpAndSettle();
  expect(find.byType(EditDateTypesScreen), findsOneWidget);
}

Finder _choice(int activityId, String label) => find.descendant(
    of: find.byKey(ValueKey('level-$activityId')), matching: find.text(label));

Set<PreferenceLevel> _selected(WidgetTester tester, int activityId) => tester
    .widget<SegmentedButton<PreferenceLevel>>(find.descendant(
        of: find.byKey(ValueKey('level-$activityId')),
        matching: find.byType(SegmentedButton<PreferenceLevel>)))
    .selected;

Future<void> _choose(WidgetTester tester, int activityId, String label) async {
  await tester.ensureVisible(_choice(activityId, label));
  await tester.pump();
  await tester.tap(_choice(activityId, label));
  await tester.pump();
}

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed != null;

double _top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

void main() {
  group('EditDateTypesScreen', () {
    testWidgets('has a row per activity from the options, in their order, with its deposit',
        (tester) async {
      await _open(tester, _api());

      expect(find.widgetWithText(AppBar, 'Date types'), findsOneWidget);
      final names = ['Dinner', 'Drinks', 'Coffee'];
      final tops = [for (final name in names) _top(tester, name)];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(find.text('1 token deposit'), findsNWidgets(2));
      expect(find.text('0.5 token deposit'), findsOneWidget);
      for (final id in [_dinner, _drinks, _coffee]) {
        expect(find.byKey(ValueKey('level-$id')), findsOneWidget);
      }
    });

    testWidgets('renders whatever the options send: names, descriptions and order',
        (tester) async {
      final options = _londonOptions();
      final activities = options['activities'] as List<dynamic>;
      final coffee = activities.removeLast() as Map<String, dynamic>;
      activities.insert(0, coffee
        ..['name'] = 'Coffee and cake'
        ..['description'] = 'An hour or so somewhere cosy'
        ..['tokenCost'] = 0.25);
      await _open(tester, _api(options: options));

      expect(find.text('Coffee and cake'), findsOneWidget);
      expect(find.text('An hour or so somewhere cosy'), findsOneWidget);
      expect(find.text('0.25 token deposit'), findsOneWidget);
      expect(_top(tester, 'Coffee and cake'), lessThan(_top(tester, 'Dinner')));
    });

    testWidgets('starts from the saved levels, with unset activities at "Happy to"',
        (tester) async {
      await _open(tester, _api());

      expect(_selected(tester, _dinner), {PreferenceLevel.love});
      expect(_selected(tester, _drinks), {PreferenceLevel.ok});
      expect(_selected(tester, _coffee), {PreferenceLevel.no});
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('saves every activity\'s level, then shows the server\'s response',
        (tester) async {
      final api = _api(saved: _saved({_dinner: 'LOVE', _drinks: 'LOVE', _coffee: 'OK'}));
      await _open(tester, api);

      await _choose(tester, _drinks, 'Love it');
      expect(_saveEnabled(tester), isTrue);
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final patch = api.requests.singleWhere((r) => '${r.method} ${r.path}' == _patchPath);
      expect(patch.data, {
        'activities': [
          {'activityId': _dinner, 'level': 'LOVE'},
          {'activityId': _drinks, 'level': 'LOVE'},
          {'activityId': _coffee, 'level': 'NO'},
        ],
      });
      // Back on the hub, which shows what the server saved (Coffee "Happy to"), not the draft.
      expect(find.byType(EditDateTypesScreen), findsNothing);
      expect(find.text('Love it'), findsNWidgets(2));
      expect(find.text('Happy to'), findsOneWidget);
      expect(find.text('Not for me'), findsNothing);
    });

    testWidgets('keeps one: "Not for me" on every active activity disables Save',
        (tester) async {
      await _open(tester, _api());
      expect(find.text('Keep at least one kind of date'), findsNothing);

      await _choose(tester, _dinner, 'Not for me');
      await _choose(tester, _drinks, 'Not for me');

      expect(find.text('Keep at least one kind of date'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);

      await _choose(tester, _coffee, 'Happy to');

      expect(find.text('Keep at least one kind of date'), findsNothing);
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('keeps one: a coming-soon activity doesn\'t count', (tester) async {
      await _open(tester, _api(options: _withBowling()));

      await _choose(tester, _dinner, 'Not for me');
      await _choose(tester, _drinks, 'Not for me');

      expect(_selected(tester, 7), {PreferenceLevel.ok});
      expect(find.text('Keep at least one kind of date'), findsOneWidget);
      expect(_saveEnabled(tester), isFalse);
    });

    testWidgets('shows the server\'s 400 in the banner and stays open', (tester) async {
      final api = _api();
      await _open(tester, api);
      api.error = const ValidationException('At least one active date type must not be "Not for me"');

      await _choose(tester, _drinks, 'Love it');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-error-banner')), findsOneWidget);
      expect(find.text('At least one active date type must not be "Not for me"'), findsOneWidget);
      expect(find.byType(EditDateTypesScreen), findsOneWidget);
      expect(_saveEnabled(tester), isTrue);
    });

    testWidgets('tags a coming-soon activity, which can still be set and is saved',
        (tester) async {
      final api = _api(
        options: _withBowling(),
        saved: _saved({_dinner: 'LOVE', _drinks: 'OK', _coffee: 'NO', 7: 'LOVE'}),
      );
      await _open(tester, api);

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('1.5 token deposit'), findsOneWidget);
      // Only Bowling has the tag.
      expect(
        find.descendant(
            of: find.ancestor(of: find.text('Bowling'), matching: find.byType(Wrap)),
            matching: find.text('Coming soon')),
        findsOneWidget,
      );

      await _choose(tester, 7, 'Love it');
      expect(_selected(tester, 7), {PreferenceLevel.love});
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final patch = api.requests.singleWhere((r) => '${r.method} ${r.path}' == _patchPath);
      expect((patch.data['activities'] as List<dynamic>).last, {'activityId': 7, 'level': 'LOVE'});
    });

    testWidgets('shows the server\'s ageNote under Drinks, and Drinks can still be set',
        (tester) async {
      final options = _londonOptions();
      _activity(options, _drinks)['ageNote'] = 'Drinks dates are 21+ in Houston';
      final api = _api(
        options: options,
        saved: _saved({_dinner: 'LOVE', _drinks: 'LOVE', _coffee: 'NO'}),
      );
      await _open(tester, api);

      expect(find.text('Drinks dates are 21+ in Houston'), findsOneWidget);
      final note = _top(tester, 'Drinks dates are 21+ in Houston');
      expect(note, greaterThan(_top(tester, 'Drinks')));
      expect(note, lessThan(_top(tester, 'Coffee')));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('level-$_drinks'))).dy,
        greaterThan(note),
      );

      await _choose(tester, _drinks, 'Love it');
      expect(_selected(tester, _drinks), {PreferenceLevel.love});
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      final patch = api.requests.singleWhere((r) => '${r.method} ${r.path}' == _patchPath);
      expect((patch.data['activities'] as List<dynamic>)[1], {'activityId': _drinks, 'level': 'LOVE'});
    });

    testWidgets('shows no age note when the server sends none', (tester) async {
      await _open(tester, _api());

      expect(find.textContaining('21+'), findsNothing);
      expect(find.textContaining('18+'), findsNothing);
    });
  });
}
