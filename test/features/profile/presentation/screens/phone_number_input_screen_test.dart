import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:eros_app/features/profile/presentation/screens/phone_number_input_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

import 'onboarding_harness.dart';

class _User implements User {
  _User(this.phoneNumber);

  @override
  final String? phoneNumber;

  @override
  String? get email => 'sam@example.com';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthService {
  _Auth([this.phone]);

  final String? phone;

  @override
  User? get currentUser => _User(phone);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late OnboardingHarness harness;

  setUp(() => harness = OnboardingHarness());

  Future<void> pump(
    WidgetTester tester, {
    String? firebasePhone,
    ProfileCreationDraft? draft,
    String? region = 'GB',
  }) async {
    await harness.pump(
      tester,
      PhoneNumberInputScreen(deviceRegion: () => region),
      initialDraft: draft,
      overrides: [authServiceProvider.overrideWithValue(_Auth(firebasePhone))],
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.descendant(
        of: find.byType(InternationalPhoneNumberInput),
        matching: find.byType(TextFormField),
      );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextFormField>(field()).controller!.text;

  bool canContinue(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue')).onPressed !=
      null;

  /// Types [text] a character at a time, as a keyboard does, so the as-you-type formatter runs.
  Future<void> type(WidgetTester tester, String text) async {
    for (final char in text.split('')) {
      await tester.enterText(field(), fieldText(tester) + char);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('starts on the device\'s country, formats as typed and saves E.164', (tester) async {
    await pump(tester);
    expect(find.text('+44'), findsOneWidget);
    expect(canContinue(tester), isFalse);

    await type(tester, '7400123456');

    expect(fieldText(tester), '7400 123456');
    expect(canContinue(tester), isTrue);
    await harness.tapContinue(tester);
    expect(harness.draft.phoneNumber, '+447400123456');
    expect(harness.pushed, ['/profile-creation/terms']);
  });

  testWidgets('a US device starts on +1', (tester) async {
    await pump(tester, region: 'US');
    expect(find.text('+1'), findsOneWidget);

    await type(tester, '2015550123');

    expect(fieldText(tester), '201-555-0123');
    expect(canContinue(tester), isTrue);
    await harness.tapContinue(tester);
    expect(harness.draft.phoneNumber, '+12015550123');
  });

  testWidgets('falls back to the UK when the device has no region', (tester) async {
    await pump(tester, region: null);
    expect(find.text('+44'), findsOneWidget);
  });

  testWidgets('keeps Continue off for a number that is too short for the country', (tester) async {
    await pump(tester);

    await type(tester, '07400');

    expect(canContinue(tester), isFalse);
    expect(find.text('Enter a valid number for this country'), findsOneWidget);
  });

  testWidgets('opens on the country of the Firebase number and saves it to the draft',
      (tester) async {
    await pump(tester, firebasePhone: '+12015550123');

    expect(find.text('Confirm your phone number'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(fieldText(tester), '201-555-0123');
    expect(canContinue(tester), isTrue);
    expect(harness.draft.phoneNumber, '+12015550123');
  });

  testWidgets('opens on the country of a number saved in the draft', (tester) async {
    await pump(tester, draft: ProfileCreationDraft(phoneNumber: '+447400123456'), region: 'US');

    expect(find.text('+44'), findsOneWidget);
    expect(fieldText(tester), '7400 123456');
    expect(canContinue(tester), isTrue);
  });

  testWidgets('a UK number typed with its leading 0 is accepted and saved in E.164',
      (tester) async {
    await pump(tester);

    await type(tester, '07400123456');

    expect(canContinue(tester), isTrue);
    await harness.tapContinue(tester);
    expect(harness.draft.phoneNumber, '+447400123456');
  });

  testWidgets('an older free-text draft without a country code starts empty', (tester) async {
    await pump(tester, draft: ProfileCreationDraft(phoneNumber: '07400 123456'));

    expect(find.text('+44'), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    expect(canContinue(tester), isFalse);
  });
}
