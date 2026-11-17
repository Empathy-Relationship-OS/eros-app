import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_theme.dart';
import 'package:eros_app/core/time/server_clock.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/providers/refund_provider.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';

/// A token purchase from the wallet history: what was bought, and the way to ask for a refund
/// while one may still be given.
///
/// Three steps: the details, a confirmation (a refund can't be undone), and what happened.
/// The app only rules out what it can see for itself, a purchase past the refund window or one
/// with no card payment. Whether any of its tokens were used is the backend's call, so the
/// action is offered and the backend's refusal is shown in plain words.
class PurchaseDetailSheet extends ConsumerStatefulWidget {
  final Transaction purchase;

  const PurchaseDetailSheet({super.key, required this.purchase});

  static Future<void> show(BuildContext context, Transaction purchase) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PurchaseDetailSheet(purchase: purchase),
    );
  }

  @override
  ConsumerState<PurchaseDetailSheet> createState() => _PurchaseDetailSheetState();
}

enum _Step { details, confirming, refunded }

class _PurchaseDetailSheetState extends ConsumerState<PurchaseDetailSheet> {
  _Step _step = _Step.details;
  bool _submitting = false;

  /// Why the last request didn't end in a refund.
  String? _message;

  /// The backend refused this purchase, so the action is no longer offered.
  bool _refused = false;

  Transaction get _purchase => widget.purchase;

  /// Why no refund can be asked for, or null when one can.
  String? get _closedReason {
    if (_purchase.status == TransactionStatus.refunded ||
        ref.read(purchaseRefunderProvider).wasRefunded(_purchase.transactionId)) {
      return WalletCopy.alreadyRefunded;
    }
    if (!_purchase.canRefund) return WalletCopy.refundUnavailable;

    const window = Duration(days: WalletCopy.refundDays);
    if (!_purchase.isWithin(window, ServerClock.instance.now())) {
      return WalletCopy.refundWindowClosed;
    }
    return null;
  }

  Future<void> _refund() async {
    // Set before the first await, so a second tap in the same frame finds it.
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _message = null;
    });

    // Taken now: if the sheet is swiped away mid-request, the result still has to be told.
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(purchaseRefunderProvider).refund(_purchase);

    if (!mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.message ?? WalletCopy.refundDoneTitle)),
      );
      return;
    }

    setState(() {
      _submitting = false;
      if (result.isRefunded) {
        _step = _Step.refunded;
      } else {
        // Back to the details, where the reason shows.
        _step = _Step.details;
        _message = result.message;
        _refused = result.kind == RefundResultKind.refused;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The back button waits for a request in flight, so its answer isn't missed.
      canPop: !_submitting,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: switch (_step) {
              _Step.details => _details(context),
              _Step.confirming => _confirmation(context),
              _Step.refunded => _outcome(context),
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final package = _purchase.package;
    final money = _purchase.formattedMoneyAmount;
    final closedReason = _closedReason;
    final canAsk = closedReason == null && !_refused;

    return [
      Text(
        package != null ? '${package.displayName} package' : _purchase.displayText,
        style: textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      _DetailRow(label: 'Tokens', value: _purchase.formattedTokens),
      if (money != null) _DetailRow(label: 'Paid', value: money),
      _DetailRow(
        label: 'Bought',
        value: DateFormat('d MMMM y').format(_purchase.createdAt.toLocal()),
      ),
      const SizedBox(height: 8),
      const Divider(),
      const SizedBox(height: 8),
      // A refusal says why itself, so the rule isn't repeated above it.
      if (!_refused)
        Text(
          closedReason ?? WalletCopy.refundRule,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      if (_message != null) ...[
        if (!_refused) const SizedBox(height: 12),
        Text(_message!, style: textTheme.bodyMedium?.copyWith(color: AppColors.error)),
      ],
      if (canAsk) ...[
        const SizedBox(height: 16),
        AppButton(
          label: WalletCopy.requestRefund,
          kind: AppButtonKind.secondary,
          onPressed: () => setState(() {
            _step = _Step.confirming;
            _message = null;
          }),
        ),
      ],
    ];
  }

  List<Widget> _confirmation(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return [
      Text(WalletCopy.refundConfirmTitle, style: textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
        WalletCopy.refundConfirmBody(
          _purchase.formattedTokens,
          _purchase.formattedMoneyAmount,
        ),
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      AppButton(
        label: WalletCopy.confirmRefund,
        kind: AppButtonKind.destructive,
        loading: _submitting,
        onPressed: _refund,
      ),
      const SizedBox(height: 4),
      TextButton(
        onPressed: _submitting ? null : () => setState(() => _step = _Step.details),
        style: AppTheme.quietLink,
        child: const Text(WalletCopy.goBack),
      ),
    ];
  }

  List<Widget> _outcome(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return [
      Text(WalletCopy.refundDoneTitle, style: textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(
        WalletCopy.refundDoneBody(
          _purchase.formattedTokens,
          _purchase.formattedMoneyAmount,
        ),
        style: textTheme.bodyLarge,
      ),
      const SizedBox(height: 16),
      AppButton(label: WalletCopy.done, onPressed: () => Navigator.of(context).pop()),
    ];
  }
}

/// One line of the purchase's details: what it is on the left, its value on the right.
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
