import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/providers/content_report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// "Report" on a profile or a photo, outside a date (RFC-009 §5.5, CF-F4).
///
/// The form, then a thank-you once filed. Pops with true when the profile should leave the
/// screen (filed, or no longer there to report), or null if the person backed out. Open it
/// with `openContentReport`. Unlike a date's "Report and block", it touches no date or money.
class ContentReportSheet extends ConsumerStatefulWidget {
  final ContentReportTarget target;
  final String name;

  const ContentReportSheet({super.key, required this.target, required this.name});

  @override
  ConsumerState<ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends ConsumerState<ContentReportSheet> {
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentReportProvider(widget.target));
    final notifier = ref.read(contentReportProvider(widget.target).notifier);
    final textTheme = Theme.of(context).textTheme;
    final enabled = !state.isSubmitting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: state.finished
                ? [
                    Text(SafetyCopy.resultHeading, style: textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text(
                      state.gone ? SafetyCopy.profileGone : SafetyCopy.contentReportThanks,
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: SafetyCopy.done,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ]
                : [
                    Text(
                      SafetyCopy.contentReportTitle(photo: widget.target.mediaId != null),
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(SafetyCopy.contentReportIntro(widget.name), style: textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(SafetyCopy.categoryHeading, style: textTheme.titleSmall),
                    const SizedBox(height: 8),
                    RadioGroup<ContentReportCategory>(
                      groupValue: state.category,
                      onChanged: (category) {
                        if (category != null && enabled) notifier.selectCategory(category);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final category in ContentReportCategory.values)
                            RadioListTile<ContentReportCategory>(
                              value: category,
                              enabled: enabled,
                              title: Text(SafetyCopy.categoryLabel(category)),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      onChanged: notifier.setDescription,
                      enabled: enabled,
                      minLines: 2,
                      maxLines: 5,
                      maxLength: UserTextLimits.reportDescription,
                      keyboardType: TextInputType.multiline,
                      decoration: const InputDecoration(hintText: SafetyCopy.descriptionHint),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        state.errorMessage!,
                        style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    AppButton(
                      label: SafetyCopy.sendReport,
                      kind: AppButtonKind.destructive,
                      loading: state.isSubmitting,
                      onPressed: notifier.submit,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
