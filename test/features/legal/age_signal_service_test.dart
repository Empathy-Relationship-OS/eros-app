import 'package:age_range_signals/age_range_signals.dart';
import 'package:eros_app/features/legal/data/services/age_signal_service.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_age_signals_platform.dart';

AgeSignalService _service(FakeAgeSignalsPlatform platform,
        {AgeSignalSource source = AgeSignalSource.apple, Duration? timeout}) =>
    AgeSignalService(
      platform: platform,
      source: source,
      timeout: timeout ?? AgeSignalService.defaultTimeout,
    );

AgeSignalsResult _range(AgeSignalsStatus status, int? lower, int? upper) =>
    AgeSignalsResult(status: status, ageLower: lower, ageUpper: upper);

void main() {
  group('mapAgeSignalsResult', () {
    const apple = AgeSignalSource.apple;

    test('each of the store bands maps to the backend band', () {
      final cases = {
        _range(AgeSignalsStatus.supervised, 0, 12): AgeBand.under13,
        // Apple's lowest range has no lower bound.
        _range(AgeSignalsStatus.supervised, null, 12): AgeBand.under13,
        _range(AgeSignalsStatus.supervised, 13, 15): AgeBand.age13To15,
        _range(AgeSignalsStatus.supervised, 16, 17): AgeBand.age16To17,
        _range(AgeSignalsStatus.supervisedApprovalPending, 16, 17): AgeBand.age16To17,
        _range(AgeSignalsStatus.verified, 18, null): AgeBand.adult,
        // Android reports a verified adult with no range in this plugin version.
        _range(AgeSignalsStatus.verified, null, null): AgeBand.adult,
        // A supervised account whose parent attested 18 or over.
        _range(AgeSignalsStatus.supervised, 18, null): AgeBand.adult,
      };
      cases.forEach((result, band) {
        expect(mapAgeSignalsResult(result, apple), StoreAgeSignal(source: apple, band: band),
            reason: '${result.ageLower}-${result.ageUpper} ${result.status}');
      });
    });

    test('a range wider than one band reads as its youngest band', () {
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.supervised, 14, 17), apple)!.band,
          AgeBand.age13To15);
    });

    test('declined and unknown are no signal', () {
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.declined, null, null), apple), isNull);
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.unknown, null, null), apple), isNull);
      // Even with a range, which no store sends with these.
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.unknown, 13, 15), apple), isNull);
    });

    test('a range across 18, or supervised with no range, is no signal', () {
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.supervised, 16, null), apple), isNull);
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.supervised, 16, 20), apple), isNull);
      expect(mapAgeSignalsResult(_range(AgeSignalsStatus.supervised, null, null), apple), isNull);
    });

    test('keeps the source', () {
      expect(
        mapAgeSignalsResult(_range(AgeSignalsStatus.verified, 18, null), AgeSignalSource.google)!
            .source,
        AgeSignalSource.google,
      );
    });
  });

  group('AgeSignalService.read', () {
    test('initialises with gates on the band edges, then maps the answer', () async {
      final platform = FakeAgeSignalsPlatform(result: _range(AgeSignalsStatus.supervised, 13, 15));

      final signal = await _service(platform, source: AgeSignalSource.google).read();

      expect(platform.gates, [13, 16, 18]);
      expect(signal, const StoreAgeSignal(source: AgeSignalSource.google, band: AgeBand.age13To15));
    });

    test('declined is null', () async {
      final platform = FakeAgeSignalsPlatform(result: _range(AgeSignalsStatus.declined, null, null));
      expect(await _service(platform).read(), isNull);
    });

    test('an older iPhone is null', () async {
      final platform = FakeAgeSignalsPlatform(error: UnsupportedPlatformException('iOS 18'));
      expect(await _service(platform).read(), isNull);
    });

    test('any plugin error is null', () async {
      for (final error in <Object>[
        MissingEntitlementException('no entitlement'),
        ApiNotAvailableException('not here'),
        PlayServicesException('outdated'),
        NetworkErrorException('offline'),
        UserCancelledException('closed'),
        ApiErrorException('boom'),
        StateError('anything else'),
      ]) {
        final platform = FakeAgeSignalsPlatform(error: error);
        expect(await _service(platform).read(), isNull, reason: '${error.runtimeType}');
      }
    });

    test('a store that never answers is null after the timeout', () async {
      final platform = FakeAgeSignalsPlatform(hang: true);
      final signal =
          await _service(platform, timeout: const Duration(milliseconds: 10)).read();
      expect(signal, isNull);
    });

    test('a platform without a store is never asked', () async {
      final platform = FakeAgeSignalsPlatform(result: _range(AgeSignalsStatus.verified, 18, null));
      final service = AgeSignalService(platform: platform, useDeviceSource: false);

      expect(await service.read(), isNull);
      expect(platform.checks, 0);
    });
  });

  group('StoreAgeSignal', () {
    test('sends the backend names and leaves out a missing verification method', () {
      expect(minorSignal.toJson(), {'source': 'GOOGLE', 'band': 'AGE_13_15'});
      expect(
        const StoreAgeSignal(
          source: AgeSignalSource.apple,
          band: AgeBand.adult,
          verificationMethod: AgeSignalVerificationMethod.id,
        ).toJson(),
        {'source': 'APPLE', 'band': 'ADULT', 'verificationMethod': 'ID'},
      );
    });

    test('only the adult band is not a minor', () {
      expect(AgeBand.values.where((b) => !b.isMinor), [AgeBand.adult]);
    });

    test('toString never shows the band', () {
      for (final band in AgeBand.values) {
        final text = StoreAgeSignal(source: AgeSignalSource.apple, band: band).toString();
        expect(text, isNot(contains(band.backendName)));
        expect(text, contains('REDACTED'));
      }
    });
  });
}
