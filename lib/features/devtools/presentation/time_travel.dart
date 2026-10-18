import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/presence_provider.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'providers/devtools_providers.dart';

/// Providers whose data depends on the server's "now" (RFC-003 §4.3).
///
/// When the dev clock moves, these are invalidated so open screens refetch
/// and show the new state (for example a date moving to presence
/// confirmation) without navigating away.
///
/// **When you add a screen whose data changes as time passes (deadlines,
/// windows that open or close, batches released at set times), add its
/// provider here.** Families are listed once and invalidate every member.
final List<ProviderOrFamily> timeSensitiveProviders = [
  // Dates: list tabs, the detail screen and its presence step.
  activeDatesProvider,
  pastDatesProvider,
  cancelledDatesProvider,
  dateDetailProvider,
  presenceProvider,
  // Matching: batches are released at set times of day.
  matchBatchProvider,
  // Wallet: deposits are refunded or forfeited when dates resolve.
  walletBalanceProvider,
  // Dev menu header shows the server time and offset.
  devtoolsHealthProvider,
];

/// Invalidates every provider in [timeSensitiveProviders].
///
/// Call after anything that moves the backend clock: the Time tab does,
/// and so should any scenario that advances time.
void invalidateTimeSensitiveState(WidgetRef ref) {
  for (final provider in timeSensitiveProviders) {
    ref.invalidate(provider);
  }
}

/// Short offset for the banner: `+1d 1h`, `+6h`, `+1h 30m`, `+45m`.
/// Zero units are left out. Under a minute shows seconds.
String formatShortOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final parts = [
    if (abs.inDays > 0) '${abs.inDays}d',
    if (abs.inHours % 24 > 0) '${abs.inHours % 24}h',
    if (abs.inMinutes % 60 > 0) '${abs.inMinutes % 60}m',
  ];
  if (parts.isEmpty) return '$sign${abs.inSeconds}s';
  return '$sign${parts.join(' ')}';
}

/// `Sat 18 Oct 2026, 13:00:00 BST`: [t] in the device's local time, with the
/// zone name.
String formatLocalTimeWithZone(DateTime t) {
  final local = t.toLocal();
  return '${DateFormat('EEE d MMM yyyy, HH:mm:ss').format(local)} '
      '${local.timeZoneName}';
}

/// `Sat 18 Oct 13:00`: [t] in the device's local time, for snackbars.
String formatLocalTimeShort(DateTime t) =>
    DateFormat('EEE d MMM HH:mm').format(t.toLocal());
