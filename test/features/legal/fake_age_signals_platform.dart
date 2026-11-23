import 'dart:async';

import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:eros_app/features/legal/data/services/age_signal_service.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Stands in for `age_range_signals`' native side: answers with [result], throws [error], or
/// never answers when [hang] is set. Records the gates and how often it was asked.
class FakeAgeSignalsPlatform extends AgeRangeSignalsPlatform with MockPlatformInterfaceMixin {
  FakeAgeSignalsPlatform({this.result, this.error, this.hang = false});

  AgeSignalsResult? result;
  Object? error;
  bool hang;

  List<int>? gates;
  int checks = 0;

  @override
  Future<void> initialize({List<int>? ageGates, bool useMockData = false, mockData}) async {
    gates = ageGates;
  }

  @override
  Future<AgeSignalsResult> checkAgeSignals() {
    checks++;
    if (hang) return Completer<AgeSignalsResult>().future;
    if (error != null) return Future.error(error!);
    return Future.value(result ?? const AgeSignalsResult(status: AgeSignalsStatus.unknown));
  }
}

/// An [AgeSignalService] that returns [signal] without a platform, counting reads.
class FixedAgeSignalService extends AgeSignalService {
  FixedAgeSignalService(this.signal) : super(platform: FakeAgeSignalsPlatform(), useDeviceSource: false);

  final StoreAgeSignal? signal;
  int reads = 0;

  @override
  Future<StoreAgeSignal?> read() async {
    reads++;
    return signal;
  }
}

const adultSignal = StoreAgeSignal(source: AgeSignalSource.apple, band: AgeBand.adult);
const minorSignal = StoreAgeSignal(source: AgeSignalSource.google, band: AgeBand.age13To15);
