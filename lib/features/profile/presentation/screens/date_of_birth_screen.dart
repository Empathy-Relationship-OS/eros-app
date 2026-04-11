import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/utils/validators.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Date of birth input screen
/// Matches screenshot: @screenshots/login/create-user/836BFF48-D008-40B9-A568-2E32E2580C72.png
/// Requirements:
/// - DD/MM/YYYY format
/// - 18+ only
/// - Max age 120
class DateOfBirthScreen extends ConsumerStatefulWidget {
  const DateOfBirthScreen({super.key});

  @override
  ConsumerState<DateOfBirthScreen> createState() => _DateOfBirthScreenState();
}

class _DateOfBirthScreenState extends ConsumerState<DateOfBirthScreen> {
  final _dayController = TextEditingController();
  final _monthController = TextEditingController();
  final _yearController = TextEditingController();
  bool _isValid = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
    _dayController.addListener(_validateDate);
    _monthController.addListener(_validateDate);
    _yearController.addListener(_validateDate);
  }

  void _loadExistingData() {
    final draft = ref.read(profileCreationProvider);
    if (draft.dateOfBirth != null) {
      final dob = draft.dateOfBirth!;
      _dayController.text = dob.day.toString().padLeft(2, '0');
      _monthController.text = dob.month.toString().padLeft(2, '0');
      _yearController.text = dob.year.toString();
    }
  }

  void _validateDate() {
    final dayText = _dayController.text;
    final monthText = _monthController.text;
    final yearText = _yearController.text;

    if (dayText.isEmpty || monthText.isEmpty || yearText.isEmpty) {
      setState(() {
        _isValid = false;
        _errorMessage = null;
      });
      return;
    }

    final day = int.tryParse(dayText);
    final month = int.tryParse(monthText);
    final year = int.tryParse(yearText);

    if (day == null || month == null || year == null) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Please enter valid numbers';
      });
      return;
    }

    // Validate ranges
    if (day < 1 || day > 31) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Day must be between 1 and 31';
      });
      return;
    }

    if (month < 1 || month > 12) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Month must be between 1 and 12';
      });
      return;
    }

    // Create date
    DateTime? dob;
    try {
      dob = DateTime(year, month, day);
    } catch (e) {
      setState(() {
        _isValid = false;
        _errorMessage = 'Invalid date';
      });
      return;
    }

    // Check age
    final now = DateTime.now();
    final age = now.year - dob.year - (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day) ? 1 : 0);

    final ageError = Validators.validateAge(age);
    if (ageError != null) {
      setState(() {
        _isValid = false;
        _errorMessage = ageError;
      });
      return;
    }

    setState(() {
      _isValid = true;
      _errorMessage = null;
    });
  }

  DateTime _getDateOfBirth() {
    final day = int.parse(_dayController.text);
    final month = int.parse(_monthController.text);
    final year = int.parse(_yearController.text);
    return DateTime(year, month, day);
  }

  Future<void> _continue() async {
    if (!_isValid) {
      return;
    }

    final dob = _getDateOfBirth();

    // Update the draft
    final currentDraft = ref.read(profileCreationProvider);
    final updatedDraft = currentDraft.copyWith(dateOfBirth: dob);
    await ref.read(profileCreationProvider.notifier).updateDraft(updatedDraft);

    // Navigate to next screen
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/languages');
    }
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
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
              // Progress indicator
              _buildProgressBar(5, 11),
              const SizedBox(height: 32),

              // Title
              Text(
                'When\'s your birthday?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You must be 18 or older to use Muse',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 32),

              // Date input fields
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _dayController,
                      decoration: InputDecoration(
                        labelText: 'DD',
                        hintText: '01',
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
                      maxLength: 2,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _monthController,
                      decoration: InputDecoration(
                        labelText: 'MM',
                        hintText: '01',
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
                      maxLength: 2,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _yearController,
                      decoration: InputDecoration(
                        labelText: 'YYYY',
                        hintText: '2000',
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
                      maxLength: 4,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      onSubmitted: (_) {
                        if (_isValid) {
                          _continue();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your age will be visible on your profile and cannot be changed later',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

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
