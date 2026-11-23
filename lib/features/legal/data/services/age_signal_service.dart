import 'dart:async';
import 'dart:io' show Platform;

import 'package:age_range_signals/age_range_signals.dart';
import 'package:age_range_signals/age_range_signals_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';

/// Reads the app-store age signal (RFC-009 §5.3.1, D-13, CF-F6): Apple's Declared Age Range on
/// iOS 26 and later, Google's Play Age Signals on Android, through `age_range_signals`.
///
/// [read] never throws. Declined, unknown, unsupported (an iPhone below iOS 26, another
/// platform), a timeout or any error give null, and null never blocks anyone. It never logs the
/// band (primer rule 3): only the error type, so a setup problem still shows in a debug log.
class AgeSignalService {
  /// The plugin's platform. Tests replace it with a fake.
  final AgeRangeSignalsPlatform _platform;

  /// Which store this phone's signal comes from; null where there is none.
  final AgeSignalSource? _source;

  /// How long the store gets to answer, its own sheet included. The plugin's older iOS
  /// eligibility check can hang on iOS 26.2 (fixed in 0.6.0), and sign-up must not hang with it.
  final Duration timeout;

  AgeSignalService({
    AgeRangeSignalsPlatform? platform,
    AgeSignalSource? source,
    bool useDeviceSource = true,
    this.timeout = defaultTimeout,
  })  : _platform = platform ?? AgeRangeSignalsPlatform.instance,
        _source = source ?? (useDeviceSource ? _deviceSource() : null);

  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Apple buckets the age against these (1 to 3 gates, at least 2 years apart). They sit on
  /// Google's fixed band edges, so both stores report the same bands: 0-12, 13-15, 16-17, 18+.
  static const List<int> ageGates = [13, 16, 18];

  /// Asks the store and maps its answer. Apple shows its sharing sheet here; on Android, Play
  /// shows nothing in this plugin version.
  Future<StoreAgeSignal?> read() async {
    final source = _source;
    if (source == null) return null;
    try {
      return await _ask(source).timeout(timeout);
    } on TimeoutException {
      debugPrint('Age signal: the store did not answer in time');
      return null;
    } catch (e) {
      // The type only: an exception's details could carry what the store said.
      debugPrint('Age signal: none (${e.runtimeType})');
      return null;
    }
  }

  Future<StoreAgeSignal?> _ask(AgeSignalSource source) async {
    await _platform.initialize(ageGates: ageGates);
    final result = await _platform.checkAgeSignals();
    return mapAgeSignalsResult(result, source);
  }

  static AgeSignalSource? _deviceSource() {
    if (kIsWeb) return null;
    if (Platform.isIOS) return AgeSignalSource.apple;
    if (Platform.isAndroid) return AgeSignalSource.google;
    return null;
  }
}

/// Maps the plugin's result to the backend's band, or null when it says nothing about the age.
///
/// - Declined or unknown: null.
/// - A range starting at 18 or more, or `verified` with no range (Android reports verified
///   adults that way): [AgeBand.adult].
/// - A range ending below 18: a minor band, picked by where it starts (no lower bound is under
///   13), so a range wider than one band reads as its youngest.
/// - Anything else (a range across 18, or `supervised` with no range): null, since the signal
///   only ever adds a reason to stop (§5.3.1).
StoreAgeSignal? mapAgeSignalsResult(AgeSignalsResult result, AgeSignalSource source) {
  final band = _bandOf(result);
  if (band == null) return null;
  return StoreAgeSignal(source: source, band: band);
}

AgeBand? _bandOf(AgeSignalsResult result) {
  if (result.status == AgeSignalsStatus.declined || result.status == AgeSignalsStatus.unknown) {
    return null;
  }
  final lower = result.ageLower;
  final upper = result.ageUpper;
  if (lower != null && lower >= 18) return AgeBand.adult;
  if (upper != null && upper < 18) {
    final from = lower ?? 0;
    if (from < 13) return AgeBand.under13;
    if (from < 16) return AgeBand.age13To15;
    return AgeBand.age16To17;
  }
  if (lower == null && upper == null && result.status == AgeSignalsStatus.verified) {
    return AgeBand.adult;
  }
  return null;
}

final ageSignalServiceProvider = Provider<AgeSignalService>((ref) => AgeSignalService());
