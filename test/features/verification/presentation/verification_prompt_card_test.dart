import 'dart:async';

import 'package:eros_app/features/verification/data/verification_card_store.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_card_provider.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/screens/verification_status_screen.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_prompt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fake_verification_http.dart';
import 'verification_status_harness.dart';

Finder get _card => find.text(VerificationCopy.cardTitle);

/// VF-F3 acceptance: the "Verify before your first date" card on the Matches tab.
void main() {
  late StubHttp http;
  late SharedPreferences prefs;

  setUp(() async {
    http = StubHttp();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    Map<String, dynamic> status, {
    String uid = 'dev_alice',
  }) async {
    http.responses['GET $statusPath'] = reply(200, status);
    await pumpVerificationApp(
      tester,
      http: http,
      prefs: prefs,
      uid: uid,
      home: const Scaffold(body: Column(children: [VerificationPromptCard()])),
    );
  }

  /// The server's state changes, and something (a push, a resume) refetches it.
  Future<void> serverSays(WidgetTester tester, Map<String, dynamic> status) async {
    http.responses['GET $statusPath'] = reply(200, status);
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    // Not awaited: the request only completes as the test pumps.
    unawaited(container.read(verificationStatusNotifierProvider).refresh());
    await settle(tester);
  }

  Future<void> dismiss(WidgetTester tester) async {
    await tester.tap(find.byTooltip(VerificationCopy.cardDismiss));
    await settle(tester);
  }

  group('shows only where there\'s something to do', () {
    const shown = {'NOT_VERIFIED', 'RETRY', 'SOMETHING_NEW'};
    const hidden = {'IN_REVIEW', 'VERIFIED', 'LOCKED'};

    for (final state in shown) {
      testWidgets('$state: shown', (tester) async {
        await pumpCard(tester, statusJson(state, reason: state == 'RETRY' ? 'UNCLEAR' : null));
        expect(_card, findsOneWidget);
      });
    }
    for (final state in hidden) {
      testWidgets('$state: hidden', (tester) async {
        await pumpCard(tester, statusJson(state, canStart: false));
        expect(_card, findsNothing);
      });
    }

    testWidgets('hidden while the status loads or can\'t be read', (tester) async {
      http.responses['GET $statusPath'] = reply(500, apiError('INTERNAL'));
      await pumpVerificationApp(
        tester,
        http: http,
        prefs: prefs,
        home: const Scaffold(body: Column(children: [VerificationPromptCard()])),
      );
      expect(_card, findsNothing);
    });

    testWidgets('gone once verified', (tester) async {
      await pumpCard(tester, statusJson('NOT_VERIFIED'));
      await serverSays(tester, statusJson('VERIFIED', canStart: false));
      expect(_card, findsNothing);
    });
  });

  testWidgets('NOT_VERIFIED says what it takes; RETRY gives the reason', (tester) async {
    await pumpCard(tester, statusJson('NOT_VERIFIED'));
    expect(find.text(VerificationCopy.whatItTakes), findsOneWidget);

    await serverSays(tester, statusJson('RETRY', reason: 'POSE_MISSING'));
    expect(find.text(VerificationCopy.retryReason(RetryReason.poseMissing)), findsOneWidget);
  });

  testWidgets('tapping it opens the status screen', (tester) async {
    await pumpCard(tester, statusJson('NOT_VERIFIED'));

    await tester.tap(_card);
    await settle(tester);

    expect(find.byType(VerificationStatusScreen), findsOneWidget);
    expect(find.text(VerificationCopy.whyWeAsk), findsOneWidget);
  });

  group('dismissing', () {
    testWidgets('hides it, and it stays dismissed on this device', (tester) async {
      await pumpCard(tester, statusJson('NOT_VERIFIED'));

      await dismiss(tester);
      expect(_card, findsNothing);
      expect(prefs.getString(VerificationCardStore.dismissedKey('dev_alice')), 'notVerified');

      // A fresh start of the app, same device.
      await pumpCard(tester, statusJson('NOT_VERIFIED'));
      expect(_card, findsNothing);
    });

    testWidgets('is per user', (tester) async {
      await pumpCard(tester, statusJson('NOT_VERIFIED'));
      await dismiss(tester);

      await pumpCard(tester, statusJson('NOT_VERIFIED'), uid: 'dev_bob');
      expect(_card, findsOneWidget);
    });

    testWidgets('it comes back when the state becomes RETRY', (tester) async {
      await pumpCard(tester, statusJson('NOT_VERIFIED'));
      await dismiss(tester);

      await serverSays(tester, statusJson('IN_REVIEW', canStart: false));
      expect(_card, findsNothing);
      await serverSays(tester, statusJson('RETRY', reason: 'UNCLEAR'));
      expect(_card, findsOneWidget);
    });

    testWidgets('dismissed in RETRY, it stays dismissed in that RETRY', (tester) async {
      await pumpCard(tester, statusJson('RETRY', reason: 'UNCLEAR'));
      await dismiss(tester);
      expect(_card, findsNothing);

      await pumpCard(tester, statusJson('RETRY', reason: 'UNCLEAR'));
      expect(_card, findsNothing);
    });

    testWidgets('dismissed in RETRY, it comes back for the next RETRY', (tester) async {
      await pumpCard(tester, statusJson('RETRY', reason: 'UNCLEAR'));
      await dismiss(tester);

      await serverSays(tester, statusJson('IN_REVIEW', canStart: false));
      await serverSays(tester, statusJson('RETRY', reason: 'NOT_SAME_PERSON'));
      expect(_card, findsOneWidget);
    });
  });

  group('shouldShowVerificationCard', () {
    test('never dismissed: every actionable state', () {
      expect(shouldShowVerificationCard(VerificationState.notVerified, null), isTrue);
      expect(shouldShowVerificationCard(VerificationState.unknown, null), isTrue);
      expect(shouldShowVerificationCard(VerificationState.retry, null), isTrue);
      expect(shouldShowVerificationCard(VerificationState.inReview, null), isFalse);
      expect(shouldShowVerificationCard(VerificationState.locked, null), isFalse);
      expect(shouldShowVerificationCard(VerificationState.verified, null), isFalse);
    });

    test('dismissed: only a RETRY reached from elsewhere', () {
      const notVerified = VerificationState.notVerified;
      expect(shouldShowVerificationCard(VerificationState.notVerified, notVerified), isFalse);
      expect(shouldShowVerificationCard(VerificationState.retry, notVerified), isTrue);
      expect(shouldShowVerificationCard(VerificationState.retry, VerificationState.retry), isFalse);
    });
  });
}
