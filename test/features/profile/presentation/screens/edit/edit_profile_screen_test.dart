import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_profile_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>;

/// Serves the fixture from GET. PATCH records the request and answers with the fixture with
/// the request's fields applied, as the server would.
class _FakeProfileRepository implements ProfileRepository {
  Map<String, dynamic> stored = _fixture();
  final requests = <Map<String, dynamic>>[];
  Object? updateError;

  @override
  Future<MyProfile> getCurrentUser() async => MyProfile.fromJson(stored);

  @override
  Future<MyProfile> updateUser(UpdateUserRequest request) async {
    final json = request.toJson();
    requests.add(json);
    if (updateError != null) throw updateError!;
    stored = {...stored, ...json};
    return MyProfile.fromJson(stored);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // The Profile tab's provider loads the public profile; never complete it.
    if (invocation.memberName == #getPublicProfile) return Completer<Never>().future;
    return super.noSuchMethod(invocation);
  }
}

Future<_FakeProfileRepository> _pumpHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final repository = _FakeProfileRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: EditProfileScreen()),
  ));
  await tester.pumpAndSettle();
  return repository;
}

/// The hub row whose label is [label].
Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

Finder _eyeIn(String label) => find.descendant(of: _row(label), matching: find.byType(IconButton));

TextButton _saveButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));

Future<void> _openRow(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  expect(find.byType(EditSectionScaffold), findsOneWidget);
}

void main() {
  group('hub', () {
    testWidgets('shows every value from the profile', (tester) async {
      await _pumpHub(tester);

      for (final text in [
        'Profile 70% complete',
        'Likes long walks.',
        'Engineer',
        '170 cm',
        'University',
        'London',
        'English, Spanish',
        'Hiking, Nature, Movies, Photography, Yoga, Afro Beats, BBQ',
        'Adventurous, Ambitious, Spontaneous, Energetic, Honest',
        'Aries',
        'Never',
        'Omnivore',
        'Serious Dating',
        'Monogamous',
        'Open to Kids',
        'Straight',
        'He/Him',
        'Christianity',
        'Black/African Descent',
        'I have AD(H)D, I have a learning disability',
        'Curious about everything.',
        'Ada Lovelace',
        '14 Mar 1995',
        'Female',
      ]) {
        expect(find.text(text), findsWidgets, reason: text);
      }
      // Politics, body attributes and body description are empty.
      expect(find.text('Add'), findsNWidgets(3));
    });

    testWidgets('hides Photos and Q&A until their editors exist', (tester) async {
      await _pumpHub(tester);

      expect(photosEditorEnabled, isFalse);
      expect(qaEditorEnabled, isFalse);
      expect(find.text('Photos'), findsNothing);
      expect(find.text('Q&A'), findsNothing);
    });

    testWidgets('locked rows say why and open nothing', (tester) async {
      await _pumpHub(tester);

      expect(find.text('Contact support to change this'), findsNWidgets(3));
      for (final value in ['Ada Lovelace', '14 Mar 1995', 'Female']) {
        await tester.tap(find.text(value));
        await tester.pumpAndSettle();
        expect(find.byType(EditSectionScaffold), findsNothing, reason: value);
      }
    });

    testWidgets('the eye flips one field\'s visibility with a one-field PATCH', (tester) async {
      final repository = await _pumpHub(tester);

      await tester.tap(_eyeIn('Religion'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {
        'religion': {'field': 'Christianity', 'display': true},
      });
      expect(
        tester.widget<Icon>(find.descendant(of: _eyeIn('Religion'), matching: find.byType(Icon))).icon,
        Icons.visibility_outlined,
      );
    });

    testWidgets('no eye where there is nothing to show', (tester) async {
      await _pumpHub(tester);

      expect(_eyeIn('Politics'), findsNothing); // no value
      expect(_eyeIn('Body'), findsNothing); // no attributes
      expect(_eyeIn('Bio'), findsNothing); // not a show/hide field
      expect(_eyeIn('Religion'), findsOneWidget);
    });

    testWidgets('a failed eye toggle shows the error and keeps the old state', (tester) async {
      final repository = await _pumpHub(tester);
      repository.updateError = ProfileRepositoryException('Unable to connect to the server.');

      await tester.tap(_eyeIn('Religion'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to connect to the server.'), findsOneWidget);
      expect(
        tester.widget<Icon>(find.descendant(of: _eyeIn('Religion'), matching: find.byType(Icon))).icon,
        Icons.visibility_off_outlined,
      );
    });
  });

  testWidgets('every row\'s editor opens and lays out at phone size', (tester) async {
    final repository = _FakeProfileRepository();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(home: EditProfileScreen()),
    ));
    await tester.pumpAndSettle();

    const labels = [
      'Bio', 'Occupation', 'Height', 'Education', 'Location', 'Languages', 'Interests', 'Traits',
      'Star sign', 'Drinking', 'Smoking', 'Diet', 'Dating intentions', 'Relationship type', 'Kids',
      'Sexual orientation', 'Pronouns', 'Religion', 'Politics', 'Ethnicity', 'Brain', 'Body',
    ];
    for (final label in labels) {
      final row = find.text(label).last; // 'Interests' is also a section title
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(EditSectionScaffold), findsOneWidget, reason: label);
      expect(tester.takeException(), isNull, reason: label);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }
  });

  group('section screens', () {
    testWidgets('Save is disabled until the value changes, then saves only that field', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Likes long walks.');

      expect(_saveButton(tester).onPressed, isNull);
      await tester.enterText(find.byType(TextFormField), 'Loves a good map');
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {'bio': 'Loves a good map'});
      expect(find.byType(EditSectionScaffold), findsNothing, reason: 'pops on success');
      expect(find.text('Loves a good map'), findsOneWidget, reason: 'the hub shows the saved value');
    });

    testWidgets('back with unsaved changes asks first', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Engineer');
      await tester.enterText(find.byType(TextFormField), 'Pilot');
      await tester.pump();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(EditSectionScaffold), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.byType(EditSectionScaffold), findsNothing);
      expect(repository.requests, isEmpty);
      expect(find.text('Engineer'), findsOneWidget);
    });

    testWidgets('back without changes just goes back', (tester) async {
      await _pumpHub(tester);
      await _openRow(tester, 'Engineer');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.byType(EditSectionScaffold), findsNothing);
    });

    testWidgets('a validation error shows in the banner and the screen stays open', (tester) async {
      final repository = await _pumpHub(tester);
      repository.updateError = ProfileValidationException(
        'Validation failed',
        errors: {'bio': ['Bio contains words we can\'t accept']},
      );
      await _openRow(tester, 'Likes long walks.');
      await tester.enterText(find.byType(TextFormField), 'Something');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-error-banner')), findsOneWidget);
      expect(find.text('Bio contains words we can\'t accept'), findsOneWidget);
      expect(find.byType(EditSectionScaffold), findsOneWidget);
    });

    testWidgets('an unexpected save error is reported, shown, and Save works again', (tester) async {
      final repository = await _pumpHub(tester);
      repository.updateError = StateError('something nobody expected');
      await _openRow(tester, 'Likes long walks.');
      await tester.enterText(find.byType(TextFormField), 'Something');
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>(), reason: 'reported through FlutterError');
      expect(find.text('We couldn\'t save your changes. Please try again.'), findsOneWidget);
      expect(find.byType(EditSectionScaffold), findsOneWidget);
      expect(_saveButton(tester).onPressed, isNotNull, reason: 'not stuck saving');

      repository.updateError = null;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(EditSectionScaffold), findsNothing);
    });

    testWidgets('text is saved as typed: apostrophes, quotes and the rest are kept', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Likes long walks.');

      await tester.enterText(find.byType(TextFormField), '  I\'m "Jo"; I <3 O\'Reilly\'s dogs -- really  ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {'bio': 'I\'m "Jo"; I <3 O\'Reilly\'s dogs -- really'});
    });

    testWidgets('only surrounding spaces don\'t count as a change', (tester) async {
      await _pumpHub(tester);
      await _openRow(tester, 'Engineer');

      await tester.enterText(find.byType(TextFormField), '  Engineer  ');
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
    });

    testWidgets('descriptions keep apostrophes too', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Curious about everything.');

      await tester.enterText(find.byType(TextFormField), "I'm curious; \"why?\"");
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        (repository.requests.single['brainDescription'] as Map)['field'],
        "I'm curious; \"why?\"",
      );
    });

    testWidgets('a choice saves the value with its visibility; "prefer not to say" saves hidden',
        (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'He/Him');

      expect(_saveButton(tester).onPressed, isNull);
      await tester.tap(find.text('Prefer not to say'));
      await tester.pump();
      expect(find.text('Show on my profile'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {
        'pronouns': {'field': 'Prefer not to say', 'display': false},
      });
    });

    testWidgets('ethnicity can\'t be saved empty', (tester) async {
      await _pumpHub(tester);
      await _openRow(tester, 'Black/African Descent');

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(_saveButton(tester).onPressed, isNull);
      expect(find.text('Choose at least 1'), findsOneWidget);
    });

    testWidgets('interests must stay between 5 and 10', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Hiking, Nature, Movies, Photography, Yoga, Afro Beats, BBQ');

      // Remove three chips: 4 left, too few.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pump();
      }
      expect(_saveButton(tester).onPressed, isNull);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      await tester.tap(find.text('Golf'));
      await tester.pump();
      await tester.tap(find.text('Kick Boxing'));
      await tester.pump();
      expect(_saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.requests.single.keys, ['interests']);
      expect((repository.requests.single['interests'] as List).length, 5);
    });

    testWidgets('height only saves a change', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, '170 cm');

      expect(_saveButton(tester).onPressed, isNull);
      await tester.tap(find.text('CM'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextFormField, 'Height (cm)'), '172');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {'heightCm': 172});
    });

    testWidgets('brain sends attributes and description, keeping their visibility', (tester) async {
      final repository = await _pumpHub(tester);
      await _openRow(tester, 'Curious about everything.');

      await tester.enterText(find.byType(TextFormField), 'Always asking why');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.requests.single, {
        'brainAttributes': {
          'field': ['I have AD(H)D', 'I have a learning disability'],
          'display': true,
        },
        'brainDescription': {'field': 'Always asking why', 'display': true},
      });
    });
  });
}
