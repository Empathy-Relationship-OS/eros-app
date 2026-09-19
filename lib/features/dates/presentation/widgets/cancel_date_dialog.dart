import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/cancel_provider.dart';
import 'package:eros_app/features/dates/presentation/providers/date_detail_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/token_amount.dart';
import 'package:eros_app/features/wallet/presentation/providers/wallet_provider.dart';

/// Cancel date confirmation dialog
///
/// Per UI-9: Shows different copy based on cancellation tier
/// Pre-commitment, post-commitment, or late (within 24h)
class CancelDateDialog extends ConsumerStatefulWidget {
  final String dateId;
  final DateDetail dateDetail;
  final String partnerName;
  final String currentUid;

  const CancelDateDialog({
    super.key,
    required this.dateId,
    required this.dateDetail,
    required this.partnerName,
    required this.currentUid,
  });

  @override
  ConsumerState<CancelDateDialog> createState() => _CancelDateDialogState();
}

class _CancelDateDialogState extends ConsumerState<CancelDateDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Determine cancellation tier for copy (client-side, for dialog only)
  CancellationTier _getCancellationTier() {
    final state = widget.dateDetail.state;
    final scheduledStart = widget.dateDetail.scheduledStart;

    // Pre-commitment: before both deposits are paid
    if (state == DateState.awaitingAvailability ||
        state == DateState.awaitingDeposit) {
      return CancellationTier.preCommitment;
    }

    // Post-commitment or late
    if (scheduledStart != null) {
      final hoursUntilDate =
          scheduledStart.difference(DateTime.now()).inHours;
      if (hoursUntilDate < 24) {
        return CancellationTier.late;
      }
    }

    return CancellationTier.postCommitment;
  }

  /// Get dialog copy based on tier
  ({String title, String body}) _getDialogCopy() {
    final tier = _getCancellationTier();
    final partnerName = widget.partnerName;
    final tokenCost = TokenAmount.formatTokenAmount(widget.dateDetail.tokenCost);

    switch (tier) {
      case CancellationTier.preCommitment:
        return (
          title: 'Cancel this date?',
          body:
              'Anything you\'ve paid comes straight back to you. $partnerName will be told the date is off.',
        );

      case CancellationTier.postCommitment:
        return (
          title: 'Cancel and lose your deposit?',
          body:
              'You\'ve both committed, so cancelling now means your $tokenCost deposit goes to $partnerName and yours is not refunded.',
        );

      case CancellationTier.late:
        return (
          title: 'Cancel and lose your deposit?',
          body:
              'You\'ve both committed, so cancelling now means your $tokenCost deposit goes to $partnerName and yours is not refunded.\n\nThis is a late cancellation.',
        );
    }
  }

  void _handleCancel() async {
    final reason = _reasonController.text.trim();

    // Validate reason if provided
    if (reason.isNotEmpty && !Validators.isSafeText(reason)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation note contains invalid characters'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Trigger cancellation
    await ref
        .read(cancelProvider(widget.dateId).notifier)
        .cancelDate(reason: reason.isEmpty ? null : reason);

    // Handle result
    if (!mounted) return;
    final cancelState = ref.read(cancelProvider(widget.dateId));

    // Close dialog after cancellation completes
    Navigator.of(context).pop();

    if (cancelState.errorMessage == 'conflict') {
      // Date moved on - refetch and show toast
      ref.read(dateDetailProvider(widget.dateId).notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something changed. Updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (cancelState.errorMessage != null) {
      // Other error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cancelState.errorMessage!),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    } else if (cancelState.result != null) {
      // Success - refetch to show terminal state
      ref.read(dateDetailProvider(widget.dateId).notifier).refresh();

      // Show refund message if applicable
      final refund = cancelState.result!.mine(widget.currentUid);
      if (refund != null && double.tryParse(refund.amount) != null) {
        final amount = double.parse(refund.amount);
        if (amount > 0) {
          // Refresh wallet balance after refund
          ref.read(walletBalanceProvider.notifier).refresh();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${TokenAmount.formatTokenAmount(refund.amount)} refunded to your wallet.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelState = ref.watch(cancelProvider(widget.dateId));
    final copy = _getDialogCopy();

    return AlertDialog(
      title: Text(
        copy.title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.body,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Add a note (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            maxLength: 150,
            enabled: !cancelState.isLoading,
          ),
        ],
      ),
      actions: [
        // Keep the date (primary action)
        TextButton(
          onPressed: cancelState.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: const Text(
            'Keep the date',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Cancel date (destructive action)
        TextButton(
          onPressed: cancelState.isLoading ? null : _handleCancel,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
          ),
          child: cancelState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Cancel date'),
        ),
      ],
    );
  }
}
