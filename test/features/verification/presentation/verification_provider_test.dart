import 'package:eros_app/core/network/api_client_provider.dart';
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

  setUp(() {
    http = StubHttp();
    container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(apiClientOver(http))],
    );
    addTearDown(container.dispose);
  });

  test('loads the status from the server', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));

    final status = await container.read(verificationStatusProvider.future);

    expect(status.state, VerificationState.notVerified);
    expect(status.canStart, isTrue);
  });

  test('refresh refetches and replaces the status', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('IN_REVIEW', canStart: false));
    await container.read(verificationStatusProvider.future);

    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await container.read(verificationStatusProvider.notifier).refresh();

    expect(container.read(verificationStatusProvider).value!.state, VerificationState.verified);
    expect(http.sent('GET', statusPath), hasLength(2));
  });

  test('a failed refresh keeps the last known status', () async {
    http.responses['GET $statusPath'] = reply(200, statusJson('VERIFIED', canStart: false));
    await container.read(verificationStatusProvider.future);

    http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
    await container.read(verificationStatusProvider.notifier).refresh();

    final state = container.read(verificationStatusProvider);
    expect(state.hasError, isFalse);
    expect(state.value!.state, VerificationState.verified);
  });

  test('a failed first load is an error, and refresh recovers from it', () async {
    http.responses['GET $statusPath'] = reply(503, apiError('SERVICE_UNAVAILABLE'));
    await expectLater(
      container.read(verificationStatusProvider.future),
      throwsA(isA<VerificationUnavailableFailure>()),
    );

    http.responses['GET $statusPath'] = reply(200, statusJson('NOT_VERIFIED'));
    await container.read(verificationStatusProvider.notifier).refresh();

    expect(
      container.read(verificationStatusProvider).value!.state,
      VerificationState.notVerified,
    );
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
