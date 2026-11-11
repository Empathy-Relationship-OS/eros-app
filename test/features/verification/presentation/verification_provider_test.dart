import 'dart:async';

import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/core/notifications/push_host.dart';
import 'package:eros_app/features/verification/domain/models/verification_failures.dart';
import 'package:eros_app/features/verification/domain/models/verification_models.dart';
import 'package:eros_app/features/verification/presentation/providers/verification_provider.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_verification_http.dart';

void main() {
  late StubHttp http;
  late ProviderContainer container;

  // The signed-in user. The API client follows it, as `apiClientProvider` does in the app.
  final uid = StateProvider<String?>((ref) => 'dev_alice');

  setUp(() {
    http = StubHttp();
    container = ProviderContainer(
      overrides: [
        signedInUidProvider.overrideWith((ref) => ref.watch(uid)),
        apiClientProvider.overrideWith((ref) {
          ref.watch(uid);
          return apiClientOver(http);
        }),
      ],
    );
    addTearDown(container.dispose);
    // A screen watching the status, so the auto-disposing providers stay alive.
    final sub = container.listen(verificationStatusProvider, (_, _) {});
    addTearDown(sub.close);
  });

  AsyncValue<VerificationStatus> current() => container.read(verificationStatusProvider);
  Future<VerificationStatus> loaded() =>
      container.read(verificationStatusForUserProvider(container.read(uid)).future);
  VerificationStatusNotifier notifier() => container.read(verificationStatusNotifierProvider);

  test('a new user never sees the previous user\'s status while theirs loads', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await loaded();

    // Every status request from here on waits, then fails.
    final release = Completer<void>();
    http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
    http.held['GET $statusPath'] = [
      for (var i = 0; i < 3; i++)
        (release: release.future, response: reply(503, apiError('SERVICE_UNAVAILABLE'))),
    ];
    container.read(uid.notifier).state = 'dev_bob';

    // Loading for Bob: nothing of Alice's is readable.
    expect(current().isLoading, isTrue);
    expect(current().valueOrNull, isNull);

    // Bob's fetch fails: an error, not Alice's status.
    release.complete();
    await expectLater(loaded(), throwsA(isA<VerificationUnavailableFailure>()));
    expect(current().hasError, isTrue);
    expect(current().valueOrNull, isNull);
  });

  test('a refresh that finishes last never overwrites a newer one', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    await loaded();

    final older = Completer<void>();
    final newer = Completer<void>();
    http.held['GET $statusPath'] = [
      (release: older.future, response: reply(200, statusJson('IN_REVIEW', canStart: false))),
      (release: newer.future, response: reply(200, statusJson('VERIFIED', canStart: false))),
    ];
    final first = notifier().refresh();
    final second = notifier().refresh();

    newer.complete();
    await second;
    older.complete();
    await first;

    expect(current().value!.state, VerificationState.verified);
  });

  test('a refresh still in flight for the previous user never lands on the new one', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await loaded();

    final aliceRefresh = Completer<void>();
    http.held['GET $statusPath'] = [
      (release: aliceRefresh.future, response: reply(200, statusJson('VERIFIED', canStart: false))),
    ];
    final pending = notifier().refresh();

    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    container.read(uid.notifier).state = 'dev_bob';
    await loaded();

    aliceRefresh.complete();
    await pending;

    expect(current().value!.state, VerificationState.notVerified);
  });

  test('loads the status from the server', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));

    final status = await loaded();

    expect(status.state, VerificationState.notVerified);
    expect(status.canStart, isTrue);
  });

  test('refresh refetches and replaces the status', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
    await loaded();

    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await notifier().refresh();

    expect(current().value!.state, VerificationState.verified);
    expect(http.sent('GET', statusPath), hasLength(2));
  });

  test('a failed refresh keeps the last known status', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await loaded();

    http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
    await notifier().refresh();

    expect(current().hasError, isFalse);
    expect(current().value!.state, VerificationState.verified);
  });

  test('a failed first load is an error, and refresh recovers from it', () async {
    http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
    await expectLater(loaded(), throwsA(isA<VerificationUnavailableFailure>()));

    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    await notifier().refresh();

    expect(current().value!.state, VerificationState.notVerified);
  });

  group('copy', () {
    final all = [
      VerificationCopy.wallTitle,
      VerificationCopy.inReview,
      VerificationCopy.retryReason(null),
      for (final reason in RetryReason.values) VerificationCopy.retryReason(reason),
      for (final problem in SelfieProblem.values) VerificationCopy.selfieProblem(problem),
    ];

    test('every reason and problem has wording, with no em dashes or numbers', () {
      for (final text in all) {
        expect(text.trim(), isNotEmpty);
        expect(text, isNot(contains('—')));
        expect(text, isNot(contains(RegExp(r'\d'))), reason: 'Reasons, never scores');
      }
    });

    test('the retry reasons are the wording in RFC-008 §7', () {
      expect(VerificationCopy.retryReason(RetryReason.poseMissing), 'We couldn\'t see the pose');
      expect(
        VerificationCopy.retryReason(RetryReason.unclear),
        'The picture was too dark or blurry',
      );
      expect(
        VerificationCopy.retryReason(RetryReason.notSamePerson),
        'Your selfie doesn\'t look like your profile photos. Update your photos or try again',
      );
      expect(
        VerificationCopy.retryReason(RetryReason.profilePhotosUnsuitable),
        'Add a clear photo of just you to your profile',
      );
      expect(VerificationCopy.selfieProblem(SelfieProblem.tooDark), 'Try again in better light');
    });
  });
}
