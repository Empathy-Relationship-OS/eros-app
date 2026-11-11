import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_profile_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_verification_http.dart';
import 'verification_status_harness.dart';

/// VF-F3 acceptance: the Profile tab's "Verify your profile" row and its hint per state.
void main() {
  late StubHttp http;
  late SharedPreferences prefs;

  setUp(() async {
    http = StubHttp();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpRow(WidgetTester tester, Map<String, dynamic> status, {int code = 200}) async {
    http.responses['GET $statusPath'] = reply(code, status);
    await pumpVerificationApp(
      tester,
      http: http,
      prefs: prefs,
      home: const Scaffold(body: VerificationProfileRow()),
    );
  }

  const hints = <String, String>{
    'NOT_VERIFIED': 'Not started',
    'IN_REVIEW': 'In review',
    'RETRY': 'Action needed',
    'LOCKED': 'Action needed',
    'VERIFIED': 'Verified',
    'SOMETHING_NEW': 'Not started',
  };

  for (final entry in hints.entries) {
    testWidgets('${entry.key}: "${entry.value}"', (tester) async {
      await pumpRow(tester, statusJson(entry.key, reason: entry.key == 'RETRY' ? 'UNCLEAR' : null));

      expect(find.text(VerificationCopy.verifyYourProfile), findsOneWidget);
      expect(find.text(entry.value), findsOneWidget);
      // A hint only, never the reason or a number.
      expect(find.textContaining(RegExp(r'\d')), findsNothing);
    });
  }

  testWidgets('no hint while the status can\'t be read', (tester) async {
    await pumpRow(tester, apiError('INTERNAL'), code: 500);

    expect(find.text(VerificationCopy.verifyYourProfile), findsOneWidget);
    for (final hint in hints.values.toSet()) {
      expect(find.text(hint), findsNothing);
    }
  });

  testWidgets('tapping it opens the status screen', (tester) async {
    await pumpRow(tester, statusJson('IN_REVIEW', canStart: false));

    await tester.tap(find.text(VerificationCopy.verifyYourProfile));
    await settle(tester);

    expect(find.byType(VerificationStatusScreen), findsOneWidget);
    expect(find.text(VerificationCopy.inReviewDetail), findsOneWidget);
  });
}
