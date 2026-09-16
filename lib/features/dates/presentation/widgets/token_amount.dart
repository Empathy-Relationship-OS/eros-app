import 'package:flutter/material.dart';

/// Widget for displaying token amounts with proper formatting
///
/// Formats decimal string per §2 of dates-ui-tickets.md:
/// - Strip trailing ".00"
/// - Append "token" or "tokens" based on count
/// - Example: "5.00" -> "5 tokens", "1.00" -> "1 token"
class TokenAmount extends StatelessWidget {
  final String tokenCost; // Decimal string like "5.00"
  final TextStyle? style;

  const TokenAmount({
    super.key,
    required this.tokenCost,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = formatTokenAmount(tokenCost);
    return Text(
      formatted,
      style: style,
    );
  }

  /// Format a decimal string token amount to display text
  /// Examples:
  /// - "5.00" -> "5 tokens"
  /// - "1.00" -> "1 token"
  /// - "2.50" -> "2.5 tokens"
  /// - "0.00" -> "0 tokens"
  static String formatTokenAmount(String decimalString) {
    // Parse to double
    final value = double.tryParse(decimalString) ?? 0.0;

    // Format without trailing .00
    String formatted;
    if (value == value.toInt()) {
      // Whole number - strip decimals
      formatted = value.toInt().toString();
    } else {
      // Has decimal part - keep it
      formatted = value.toString();
    }

    // Pluralize
    final isPlural = value != 1.0;
    return '$formatted ${isPlural ? 'tokens' : 'token'}';
  }
}
