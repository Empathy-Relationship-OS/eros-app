import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/screens/report_result_screen.dart';
import 'package:eros_app/features/safety/presentation/screens/report_sheet.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';

/// Opens "Report and block" for [dateDetail], then the result screen once it's filed.
///
/// Every entry point but the cancel dialog uses this: date detail's overflow menu, the
/// terminal panel's "Report", and the chat screen's `⋯` menu. They all send origin `REPORT`.
Future<void> openReportFlow(
  BuildContext context,
  WidgetRef ref, {
  required DateDetail dateDetail,
}) async {
  final result = await showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ReportSheet(
      dateId: dateDetail.dateId.toString(),
      partnerName: dateDetail.partnerName,
      dateFinished: dateDetail.state.isTerminal,
    ),
  );
  if (result == null || !context.mounted) return;
  await showReportResult(Navigator.of(context), ref, dateDetail: dateDetail, result: result);
}

/// Refreshes what a report changed, then shows the result screen on [navigator].
///
/// Takes a navigator rather than a context, so the cancel dialog can call it as it closes.
Future<void> showReportResult(
  NavigatorState navigator,
  WidgetRef ref, {
  required DateDetail dateDetail,
  required ReportResult result,
}) {
  refreshAfterReport(ref, dateDetail.dateId.toString(), result);
  return navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => ReportResultScreen(result: result, cityName: dateDetail.cityName),
    ),
  );
}

/// The date may now be cancelled, and the deposit refunded or on hold.
void refreshAfterReport(WidgetRef ref, String dateId, ReportResult result) {
  ref.read(dateDetailProvider(dateId).notifier).refresh();
  ref.invalidate(activeDatesProvider);
  ref.invalidate(pastDatesProvider);
  ref.invalidate(cancelledDatesProvider);
  if (result.yourRefund == RefundOutcome.refunded) {
    ref.invalidate(walletBalanceProvider);
  }
}
