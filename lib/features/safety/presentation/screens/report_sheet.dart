import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/report_form.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// "Report and block" (RFC-006 §4.7, §6.5), always with origin `REPORT`.
///
/// Two steps: the form, then a confirmation, because a report can't be undone. Pops with the
/// [ReportResult] once filed, or null if the person backed out. Open it with `openReportFlow`.
class ReportSheet extends ConsumerStatefulWidget {
  final String dateId;
  final String partnerName;

  /// The date has already ended: the report changes nothing about it, so the copy doesn't
  /// say it ends the date.
  final bool dateFinished;

  const ReportSheet({
    super.key,
    required this.dateId,
    required this.partnerName,
    required this.dateFinished,
  });

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  bool _confirming = false;

  void _review() {
    if (ref.read(reportProvider(widget.dateId).notifier).checkReady()) {
      setState(() => _confirming = true);
    }
  }

  Future<void> _submit() async {
    final notifier = ref.read(reportProvider(widget.dateId).notifier);
    final filed = await notifier.submit(ReportOrigin.report);
    if (!mounted) return;
    if (filed) {
      Navigator.of(context).pop(ref.read(reportProvider(widget.dateId)).result);
    } else {
      // Back to the form, where the error shows and everything typed is still there.
      setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.dateId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _confirming ? SafetyCopy.confirmTitle : SafetyCopy.reportAndBlock,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _confirming
                    ? SafetyCopy.confirmBody(widget.partnerName, dateFinished: widget.dateFinished)
                    : SafetyCopy.sheetIntro(widget.partnerName, dateFinished: widget.dateFinished),
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.5),
              ),
              const SizedBox(height: 16),
              // Kept in the tree while confirming, so nothing typed is lost on "Go back".
              Offstage(
                offstage: _confirming,
                child: ReportForm(dateId: widget.dateId),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: const TextStyle(fontSize: 14, color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              if (_confirming) ...[
                ElevatedButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(SafetyCopy.confirmButton),
                ),
                TextButton(
                  onPressed: state.isSubmitting ? null : () => setState(() => _confirming = false),
                  child: const Text(SafetyCopy.goBack),
                ),
              ] else
                ElevatedButton(
                  onPressed: _review,
                  child: const Text(SafetyCopy.reviewButton),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
