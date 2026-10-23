import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';

/// Height in feet and inches or in centimetres, with a Feet / CM toggle (RFC-004 §6.2).
///
/// Unlike the choice editors, this keeps its own text fields and unit, because a half-typed
/// height has no value yet. It starts from [initialHeightCm] and reports through [onChanged]:
/// the height in cm once the fields hold a valid height (3 to 9 feet, or 91 to 274 cm), or null
/// while they don't. Nothing is reported until the user changes something, so a wrapper should
/// treat the initial value as not yet confirmed. [onSubmitted] fires when the keyboard's done
/// key is pressed on a valid height.
///
/// Feet and inches are converted with 2.54 cm per inch and rounded, so a stored height can come
/// back 1 cm different after a round trip through feet (for example 171 → 5'7" → 170).
class HeightEditor extends StatefulWidget {
  final int? initialHeightCm;
  final ValueChanged<int?> onChanged;
  final ValueChanged<int>? onSubmitted;

  const HeightEditor({
    super.key,
    this.initialHeightCm,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  State<HeightEditor> createState() => _HeightEditorState();
}

class _HeightEditorState extends State<HeightEditor> {
  final _formKey = GlobalKey<FormState>();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _cmController = TextEditingController();

  bool _useFeet = true; // true for Feet, false for CM
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    final heightCm = widget.initialHeightCm;
    if (heightCm != null) {
      _cmController.text = heightCm.toString();
      // Convert to feet and inches
      final totalInches = heightCm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      _feetController.text = feet.toString();
      _inchesController.text = inches.toString();
    }
    _feetController.addListener(_validateForm);
    _inchesController.addListener(_validateForm);
    _cmController.addListener(_validateForm);
  }

  void _validateForm() {
    var isValid = false;
    if (_useFeet) {
      final feet = int.tryParse(_feetController.text);
      final inches = int.tryParse(_inchesController.text);
      if (feet != null && inches != null) {
        final heightFeet = feet + (inches / 12);
        final error = Validators.validateHeightFeet(heightFeet);
        isValid = error == null && inches >= 0 && inches < 12;
      }
    } else {
      final cm = int.tryParse(_cmController.text);
      if (cm != null) {
        // Min 3ft = ~91cm, Max 9ft = ~274cm
        isValid = cm >= 91 && cm <= 274;
      }
    }
    setState(() {
      _isValid = isValid;
    });
    widget.onChanged(isValid ? _getHeightInCm() : null);
  }

  int _getHeightInCm() {
    if (_useFeet) {
      final feet = int.parse(_feetController.text);
      final inches = int.parse(_inchesController.text);
      final totalInches = (feet * 12) + inches;
      return (totalInches * 2.54).round();
    } else {
      return int.parse(_cmController.text);
    }
  }

  void _toggleUnit() {
    setState(() {
      // Store the current unit before toggling
      final wasUsingFeet = _useFeet;

      if (wasUsingFeet && _feetController.text.isNotEmpty && _inchesController.text.isNotEmpty) {
        // Convert from Feet to CM
        final heightCm = _getHeightInCm();
        _cmController.text = heightCm.toString();
      } else if (!wasUsingFeet && _cmController.text.isNotEmpty) {
        // Convert from CM to Feet
        final cm = int.parse(_cmController.text);
        final totalInches = cm / 2.54;
        final feet = totalInches ~/ 12;
        final inches = (totalInches % 12).round();
        _feetController.text = feet.toString();
        _inchesController.text = inches.toString();
      }
      _useFeet = !_useFeet;
    });
    _validateForm();
  }

  void _submit() {
    if (_isValid) widget.onSubmitted?.call(_getHeightInCm());
  }

  @override
  void dispose() {
    _feetController.dispose();
    _inchesController.dispose();
    _cmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('Feet'),
              selected: _useFeet,
              onSelected: (selected) {
                if (selected && !_useFeet) _toggleUnit();
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: _useFeet ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            ChoiceChip(
              label: const Text('CM'),
              selected: !_useFeet,
              onSelected: (selected) {
                if (selected && _useFeet) _toggleUnit();
              },
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: !_useFeet ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Input fields
        Form(
          key: _formKey,
          child: _useFeet ? _buildFeetInput() : _buildCmInput(),
        ),
      ],
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
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
      );

  Widget _buildFeetInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _feetController,
            decoration: _decoration('Feet'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _inchesController,
            decoration: _decoration('Inches'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ],
    );
  }

  Widget _buildCmInput() {
    return TextFormField(
      controller: _cmController,
      decoration: _decoration('Height (cm)'),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
    );
  }
}
