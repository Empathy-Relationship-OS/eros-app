import 'package:flutter/material.dart';

/// How much weight a button carries on its screen.
enum AppButtonKind {
  /// The one thing the screen wants you to do: coral with ink text.
  primary,

  /// A real choice that isn't the main one: a quiet tint fill.
  secondary,

  /// The way out, or the lesser of two: an ink outline.
  outline,
}

/// The app's button. Its colours, shape and text come from [AppTheme]; this adds the things a
/// themed button doesn't give on its own: one height, a loading state, and a label that shrinks
/// instead of being cut off.
///
/// Use it instead of an [ElevatedButton] restyled with `styleFrom`. For a link, use a plain
/// [TextButton].
class AppButton extends StatelessWidget {
  final String label;

  /// Null turns the button off.
  final VoidCallback? onPressed;
  final AppButtonKind kind;

  /// Shown before the label.
  final IconData? icon;

  /// Shown after the label.
  final IconData? trailingIcon;

  /// Shows a spinner in place of the label and turns the button off.
  final bool loading;

  /// Fills the width it is given. Turn it off for a button that hugs its label.
  final bool expand;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = true,
  });

  static const double minHeight = 52;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        expand ? const Size.fromHeight(minHeight) : const Size(64, minHeight),
      ),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
    );
    final action = loading ? null : onPressed;
    final child = loading ? const _Spinner() : _label();

    switch (kind) {
      case AppButtonKind.primary:
        return ElevatedButton(onPressed: action, style: style, child: child);
      case AppButtonKind.secondary:
        return FilledButton.tonal(onPressed: action, style: style, child: child);
      case AppButtonKind.outline:
        return OutlinedButton(onPressed: action, style: style, child: child);
    }
  }

  Widget _label() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Text(label, maxLines: 1),
          if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 20)],
        ],
      ),
    );
  }
}

/// A spinner in the button's own text colour.
class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: DefaultTextStyle.of(context).style.color,
      ),
    );
  }
}
