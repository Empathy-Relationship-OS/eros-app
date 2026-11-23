import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_list_provider.dart';
import 'package:eros_app/features/safety/presentation/report_flow.dart';
import 'package:eros_app/features/safety/presentation/screens/block_sheet.dart';
import 'package:eros_app/features/safety/presentation/screens/content_report_sheet.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// Reports and blocks outside a date (RFC-009 §5.5, §5.8, CF-F4).
///
/// Each entry point opens these and, when one returns true or [BlockSheetResult.blocked],
/// takes the profile off its screen and refetches what it shows (primer rule 20). A date's
/// "Report and block" (`openReportFlow`) is separate: it ends the date and moves money.

/// Opens "Report" for [userId], or for their photo [mediaId]. Returns true once the profile
/// should leave the screen.
Future<bool> openContentReport(
  BuildContext context, {
  required String userId,
  required String name,
  int? mediaId,
}) async {
  final hide = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ContentReportSheet(target: (userId: userId, mediaId: mediaId), name: name),
  );
  return hide ?? false;
}

/// Opens "Block" for [userId]. [canCancelDate] offers "Cancel date" when a date is in
/// progress; without it the sheet only says to cancel first. Shows "Blocked" once done.
Future<BlockSheetResult?> openBlockFlow(
  BuildContext context, {
  required String userId,
  required String name,
  bool canCancelDate = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await showModalBottomSheet<BlockSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlockSheet(userId: userId, name: name, canCancelDate: canCancelDate),
  );
  if (result == BlockSheetResult.blocked) {
    messenger?.showSnackBar(const SnackBar(content: Text(SafetyCopy.blocked)));
  }
  return result;
}

/// The dates lists, which may now leave out, or change, a date with someone just hidden.
void refreshDatesAfterHiding(WidgetRef ref) {
  ref.invalidate(activeDatesProvider);
  ref.invalidate(pastDatesProvider);
  ref.invalidate(cancelledDatesProvider);
}

/// How a safety action on a date partner ended, for the screen that shows them.
enum DatePartnerSafetyExit {
  /// Reported or blocked: they're hidden now, so the screen should go.
  hidden,

  /// A block found the date in progress, and the person chose to cancel it.
  cancelDate,
}

/// Whether the date partner menu shows at all. Once the viewer has reported the date they're
/// already hidden from each other, so there's nothing to report or block (#82).
bool showDatePartnerSafety(DateDetail date) => !date.youReported;

/// The report label for a date partner. While the date is in progress, "Report" is the date's
/// "Report and block", which ends the date under the refund rules (RFC-006): a report outside
/// the date would hide them and leave the date and its deposits running.
String datePartnerReportLabel(DateDetail date) =>
    date.state.isTerminal ? SafetyCopy.report : SafetyCopy.reportAndBlock;

/// Runs [action] on [date]'s partner, from the date's header or the partner's profile.
///
/// "Report" on a date in progress opens the date's report (and returns null: that flow shows
/// its own result and refreshes the date); on a finished date it reports the profile. "Block"
/// offers "Cancel date" on the 409 when the date can still be cancelled. Refetches the date
/// and the dates lists after a report or block.
Future<DatePartnerSafetyExit?> runDatePartnerSafety(
  BuildContext context,
  WidgetRef ref, {
  required DateDetail date,
  required String partnerId,
  required ProfileSafetyAction action,
}) async {
  final dateId = date.dateId.toString();
  switch (action) {
    case ProfileSafetyAction.report:
      if (!date.state.isTerminal) {
        await openReportFlow(context, ref, dateDetail: date);
        return null;
      }
      final hidden = await openContentReport(context, userId: partnerId, name: date.partnerName);
      if (!hidden) return null;
    case ProfileSafetyAction.block:
      final result = await openBlockFlow(
        context,
        userId: partnerId,
        name: date.partnerName,
        canCancelDate: date.cancellable && !date.state.isTerminal,
      );
      if (result == BlockSheetResult.cancelDate) return DatePartnerSafetyExit.cancelDate;
      if (result != BlockSheetResult.blocked) return null;
  }
  ref.read(dateDetailProvider(dateId).notifier).refresh();
  refreshDatesAfterHiding(ref);
  return DatePartnerSafetyExit.hidden;
}

/// What the safety menu on a profile offers.
enum ProfileSafetyAction { report, block }

/// The `⋯` menu on a profile, a batch card or a date partner's header: "Report", and "Block"
/// when [onBlock] is set (only matches can be blocked).
class ProfileSafetyMenu extends StatelessWidget {
  final VoidCallback onReport;
  final VoidCallback? onBlock;

  /// The label of the report item. A date in progress says "Report and block", as that
  /// report ends the date.
  final String reportLabel;

  /// For a menu over a photo: the icon sits on a dark disc so it reads on any picture.
  final bool overPhoto;

  const ProfileSafetyMenu({
    super.key,
    required this.onReport,
    this.onBlock,
    this.reportLabel = SafetyCopy.report,
    this.overPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final menu = PopupMenuButton<ProfileSafetyAction>(
      key: const Key('profile-safety-menu'),
      tooltip: SafetyCopy.moreOptions,
      icon: Icon(
        Icons.more_horiz,
        color: overPhoto ? AppColors.white : AppColors.textPrimary,
      ),
      onSelected: (action) => switch (action) {
        ProfileSafetyAction.report => onReport(),
        ProfileSafetyAction.block => onBlock?.call(),
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: ProfileSafetyAction.report, child: Text(reportLabel)),
        if (onBlock != null)
          const PopupMenuItem(value: ProfileSafetyAction.block, child: Text(SafetyCopy.block)),
      ],
    );
    if (!overPhoto) return menu;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: menu,
    );
  }
}

/// The long-press menu on a photo: one item, "Report this photo". Returns true when chosen.
Future<bool> showPhotoActions(BuildContext context) async {
  final chosen = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: const Text(SafetyCopy.reportPhoto),
        onTap: () => Navigator.of(sheetContext).pop(true),
      ),
    ),
  );
  return chosen ?? false;
}
