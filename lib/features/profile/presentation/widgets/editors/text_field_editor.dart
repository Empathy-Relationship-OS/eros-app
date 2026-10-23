import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// A text field with a live `n/maxLength` counter (RFC-004 §6.2).
///
/// Used for the bio (300), occupation (50) and the brain and body descriptions (100, D-11).
/// The wrapping screen owns [controller] and reads the text from it when saving. [maxLength]
/// is enforced as the user types. [validator] runs when an enclosing `Form` validates.
class TextFieldEditor extends StatelessWidget {
  final TextEditingController controller;
  final int maxLength;
  final String? hintText;
  final String? labelText;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const TextFieldEditor({
    super.key,
    required this.controller,
    required this.maxLength,
    this.hintText,
    this.labelText,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
      ),
      // With maxLength set and no counterText, the field shows its own live `n/maxLength`.
      maxLength: maxLength,
      maxLines: maxLines,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      validator: validator,
    );
  }
}
