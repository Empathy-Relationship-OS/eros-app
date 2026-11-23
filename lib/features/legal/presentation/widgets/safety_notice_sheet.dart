import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';

/// The sheet for an unread safety notice (CF-F5). "OK" pops `true`, which marks it read; a swipe
/// or back leaves it unread, so it shows again on the next launch or resume.
class SafetyNoticeSheet extends StatelessWidget {
  const SafetyNoticeSheet({super.key, required this.onReadMore});

  /// Opens the notice's legal document. Null hides "Read more" (there's no document yet).
  final VoidCallback? onReadMore;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(SafetyNoticeCopy.title, style: textTheme.headlineSmall),
            ),
            const SizedBox(height: 12),
            Text(
              SafetyNoticeCopy.fraudContactBanned,
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            if (onReadMore != null) ...[
              AppButton(
                label: SafetyNoticeCopy.readMore,
                kind: AppButtonKind.outline,
                trailingIcon: Icons.open_in_new,
                onPressed: onReadMore,
              ),
              const SizedBox(height: 12),
            ],
            AppButton(
              label: SafetyNoticeCopy.ok,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
