import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/presentation/providers/date_verification_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_formats.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_wall.dart';

/// [VerificationWall] for one date: once the viewer is verified, it refetches the date so the
/// wall comes down without a manual refresh (VF-F4).
class DateVerificationWall extends ConsumerWidget {
  final String dateId;

  /// The current step's deadline, when it has one.
  final DateTime? deadline;

  /// The one-line version, in place of the chat composer.
  final bool compact;

  const DateVerificationWall({
    super.key,
    required this.dateId,
    this.deadline,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadline = this.deadline;
    return VerificationWall(
      deadline: deadline == null ? null : DateFormats.formatDateTime(deadline),
      compact: compact,
      onVerified: () {
        if (!context.mounted) return;
        ref.read(dateVerificationRaisedProvider(dateId).notifier).afterVerified();
      },
    );
  }
}

/// The wall in place of an entry screen's form (availability, deposit, venue ranking), with
/// the screen's own "Cancel this date" kept below it (RFC-008 D-6).
class DateVerificationWallBody extends StatelessWidget {
  final String dateId;
  final DateTime? deadline;

  /// The screen's cancel action. Null where the screen shows none.
  final VoidCallback? onCancel;

  const DateVerificationWallBody({
    super.key,
    required this.dateId,
    this.deadline,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final onCancel = this.onCancel;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DateVerificationWall(dateId: dateId, deadline: deadline),
          if (onCancel != null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text('Cancel this date', style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
