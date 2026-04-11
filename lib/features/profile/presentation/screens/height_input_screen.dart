import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Height input screen in profile creation flow
/// Matches screenshots:
/// - @screenshots/login/create-user/F6C549FC-FECF-4410-9B00-DDF6001329B2.png
/// - @screenshots/login/create-user/2B95D7A1-BF71-403E-8BFD-7B6733E633D7.png
class HeightInputScreen extends ConsumerStatefulWidget {
  const HeightInputScreen({super.key});

  @override
  ConsumerState<HeightInputScreen> createState() => _HeightInputScreenState();
}

class _HeightInputScreenState extends ConsumerState<HeightInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feetController = TextEditingController();
  final _inchesController = TextEditingController();
  final _cmController = TextEditingController();

  bool _useFeet = true; // true for Feet, false for CM
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _feetController.addListener(_validateForm);
    _inchesController.addListener(_validateForm);
    _cmController.addListener(_validateForm);
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.heightCm != null) {
      _cmController.text = draft.heightCm.toString();
      // Convert to feet and inches
      final totalInches = draft.heightCm! / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      _feetController.text = feet.toString();
      _inchesController.text = inches.toString();
    }
  }

  void _validateForm() {
    if (_useFeet) {
      final feetText = _feetController.text;
      final inchesText = _inchesController.text;
      if (feetText.isNotEmpty && inchesText.isNotEmpty) {
        final feet = int.tryParse(feetText);
        final inches = int.tryParse(inchesText);
        if (feet != null && inches != null) {
          final heightFeet = feet + (inches / 12);
          final error = Validators.validateHeightFeet(heightFeet);
          setState(() {
            _isValid = error == null && inches >= 0 && inches < 12;
          });
          return;
        }
      }
    } else {
      final cmText = _cmController.text;
      if (cmText.isNotEmpty) {
        final cm = int.tryParse(cmText);
        if (cm != null) {
          // Min 3ft = ~91cm, Max 9ft = ~274cm
          setState(() {
            _isValid = cm >= 91 && cm <= 274;
          });
          return;
        }
      }
    }
    setState(() {
      _isValid = false;
    });
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

  Future<void> _continue() async {
    if (!_isValid) {
      return;
    }

    final heightCm = _getHeightInCm();

    // Update the draft
    await ref.read(profileCreationProvider.notifier).updateFields(
          heightCm: heightCm,
        );

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/education');
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
      _validateForm();
    });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator (step 8 of 11 in basic info)
              _buildProgressBar(8, 11),
              const SizedBox(height: 32),

              // Title
              Text(
                'What\'s your height?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will be displayed on your profile',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

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

              const Spacer(),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isValid ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeetInput() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _feetController,
            decoration: InputDecoration(
              labelText: 'Feet',
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
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _inchesController,
            decoration: InputDecoration(
              labelText: 'Inches',
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
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (_isValid) {
                _continue();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCmInput() {
    return TextFormField(
      controller: _cmController,
      decoration: InputDecoration(
        labelText: 'Height (cm)',
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
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        if (_isValid) {
          _continue();
        }
      },
    );
  }

  Widget _buildProgressBar(int currentStep, int totalSteps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step $currentStep of $totalSteps',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${((currentStep / totalSteps) * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
