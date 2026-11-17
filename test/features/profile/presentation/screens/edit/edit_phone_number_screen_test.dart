import 'dart:convert';
import 'dart:io';

import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_phone_number_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/phone_number_field.dart';
import 'package:eros_app/features/profile/presentation/widgets/phone_number_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

Map<String, dynamic> _fixture() =>
    jsonDecode(File('test/fixtures/users/get_users_me.json').readAsStringSync()) as Map<String, dynamic>;

/// Serves `GET /users/me` with [phoneNumber]; `PUT /users/me/phone` records the number and stores
/// it, or throws [error].
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.phoneNumber, this.error});

  String? phoneNumber;
  final Object? error;
  final puts = <String?>[];

  @override
  Future<MyProfile> getCurrentUser() async =>
      MyProfile.fromJson({..._fixture(), 'phoneNumber': phoneNumber});

  @override
  Future<String?> updatePhoneNumber(String? e164) async {
    puts.add(e164);
    if (error != null) throw error!;
    return phoneNumber = e164;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The settings tile on a page of its own, as App Settings shows it.
Future<_FakeProfileRepository> _pump(WidgetTester tester, _FakeProfileRepository repository) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [profileRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: Scaffold(body: PhoneNumberSettingsTile())),
  ));
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.text('Phone number'));
  await tester.pumpAndSettle();
  expect(find.byType(EditPhoneNumberScreen), findsOneWidget);
}

Finder _field() => find.descendant(
      of: find.byType(InternationalPhoneNumberInput),
      matching: find.byType(TextFormField),
    );

String _fieldText(WidgetTester tester) => tester.widget<TextFormField>(_field()).controller!.text;

/// Types [text] a character at a time, as a keyboard does, so the as-you-type formatter runs.
Future<void> _type(WidgetTester tester, String text) async {
  for (final char in text.split('')) {
    await tester.enterText(_field(), _fieldText(tester) + char);
    await tester.pumpAndSettle();
  }
}

Future<void> _clear(WidgetTester tester) async {
  await tester.enterText(_field(), '');
  await tester.pumpAndSettle();
}

bool _canSave(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed != null;

// With no saved number the editor starts on the device's country, which is the US in tests.

void main() {
  group('formatPhoneNumberForDisplay', () {
    test('adds the dial code to the number formatted for its country', () async {
      expect(await formatPhoneNumberForDisplay('+447400123456'), '+44 7400 123456');
      expect(await formatPhoneNumberForDisplay('+12015550123'), '+1 201-555-0123');
    });

    test('returns anything it can\'t parse unchanged', () async {
      expect(await formatPhoneNumberForDisplay('not a number'), 'not a number');
    });
  });

  group('PhoneNumberSettingsTile', () {
    testWidgets('shows the number formatted for its country', (tester) async {
      await _pump(tester, _FakeProfileRepository(phoneNumber: '+447400123456'));

      expect(find.text('+44 7400 123456'), findsOneWidget);
    });

    testWidgets('says when there is none', (tester) async {
      await _pump(tester, _FakeProfileRepository());

      expect(find.text('Not added'), findsOneWidget);
    });

    testWidgets('opens the editor', (tester) async {
      await _pump(tester, _FakeProfileRepository());

      await _openEditor(tester);

      expect(find.text('Only shared with a date if you choose. Nobody else sees it.'), findsOneWidget);
      expect(find.text('Remove number'), findsNothing, reason: 'there is nothing to remove');
    });
  });

  group('EditPhoneNumberScreen', () {
    testWidgets('adds a number and shows it in the row', (tester) async {
      final repository = await _pump(tester, _FakeProfileRepository());
      await _openEditor(tester);
      expect(_canSave(tester), isFalse);

      await _type(tester, '2015550123');
      expect(_canSave(tester), isTrue);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.puts, ['+12015550123']);
      expect(find.byType(EditPhoneNumberScreen), findsNothing);
      expect(find.text('+1 201-555-0123'), findsOneWidget);
    });

    testWidgets('starts on the saved number, with Save off until it changes', (tester) async {
      await _pump(tester, _FakeProfileRepository(phoneNumber: '+12015550123'));
      await _openEditor(tester);

      expect(find.text('+1'), findsOneWidget);
      expect(_fieldText(tester), '201-555-0123');
      expect(_canSave(tester), isFalse);
    });

    testWidgets('keeps Save off for an invalid number', (tester) async {
      await _pump(tester, _FakeProfileRepository());
      await _openEditor(tester);

      await _type(tester, '20155');

      expect(_canSave(tester), isFalse);
      expect(find.text('Enter a valid number for this country'), findsOneWidget);
    });

    testWidgets('replaces a number', (tester) async {
      final repository = await _pump(tester, _FakeProfileRepository(phoneNumber: '+447400123456'));
      await _openEditor(tester);

      await _clear(tester);
      await _type(tester, '7400654321');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.puts, ['+447400654321']);
      expect(find.text('+44 7400 654321'), findsOneWidget);
    });

    testWidgets('shows the server\'s refusal and stays open', (tester) async {
      final repository = await _pump(
        tester,
        _FakeProfileRepository(
          error: ProfileValidationException(ProfileRepository.phoneNumberRejectedMessage),
        ),
      );
      await _openEditor(tester);

      await _type(tester, '2015550123');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repository.puts, ['+12015550123']);
      expect(find.text('That number didn\'t work. Check it and try again.'), findsOneWidget);
      expect(find.byType(EditPhoneNumberScreen), findsOneWidget);
    });

    testWidgets('removes the number after asking', (tester) async {
      final repository = await _pump(tester, _FakeProfileRepository(phoneNumber: '+447400123456'));
      await _openEditor(tester);

      await tester.tap(find.text('Remove number'));
      await tester.pumpAndSettle();
      expect(find.text('Remove your phone number?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(repository.puts, [null]);
      expect(find.byType(EditPhoneNumberScreen), findsNothing);
      expect(find.text('Not added'), findsOneWidget);
    });

    testWidgets('keeps the number when the removal is cancelled', (tester) async {
      final repository = await _pump(tester, _FakeProfileRepository(phoneNumber: '+447400123456'));
      await _openEditor(tester);

      await tester.tap(find.text('Remove number'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.puts, isEmpty);
      expect(find.byType(EditPhoneNumberScreen), findsOneWidget);
    });

    testWidgets('asks before throwing away an unsaved number', (tester) async {
      await _pump(tester, _FakeProfileRepository());
      await _openEditor(tester);

      await _type(tester, '2015550123');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('goes back without asking when nothing changed', (tester) async {
      await _pump(tester, _FakeProfileRepository(phoneNumber: '+447400123456'));
      await _openEditor(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(EditPhoneNumberScreen), findsNothing);
    });
  });
}
