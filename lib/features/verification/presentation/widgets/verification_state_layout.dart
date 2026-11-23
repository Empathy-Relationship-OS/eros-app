import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/app_button.dart';

/// One verification state's layout on the status screen and the age check step: an icon that
/// only decorates, a heading, lines of text and up to two actions.
class VerificationStateLayout extends StatelessWidget {
  final IconData icon;
  final String? title;
  final List<String> lines;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// The action is working: it shows its progress and can't be tapped again.
  final bool actionLoading;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const VerificationStateLayout({
    super.key,
    required this.icon,
    this.title,
    this.lines = const [],
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final actionLabel = this.actionLabel;
    final secondaryLabel = this.secondaryLabel;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 56, color: AppColors.primaryDeep)),
        const SizedBox(height: 24),
        if (title != null) ...[
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final line in lines) ...[
          Text(
            line,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
        ],
        if (actionLabel != null) ...[
          const SizedBox(height: 24),
          AppButton(label: actionLabel, loading: actionLoading, onPressed: onAction),
        ],
        if (secondaryLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSecondary,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(secondaryLabel),
          ),
        ],
      ],
    );
  }
}
