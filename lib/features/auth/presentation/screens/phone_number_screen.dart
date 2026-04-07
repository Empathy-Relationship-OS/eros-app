import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import '../../../../core/theme/app_colors.dart';
import 'otp_verification_screen.dart';

/// Phone Number Entry Screen
/// User enters phone number to receive OTP
/// Reference: screenshots/login/create-user/C66338AB-087A-4FD1-8A50-1B183B02E8A5_1_105_c.jpeg
class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'GB');
  bool _isValid = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate() || !_isValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Call backend API to send OTP
      // For now, simulate API call
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navigate to OTP verification screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              phoneNumber: _phoneNumber.phoneNumber ?? '',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Title
                Text(
                  'My number is',
                  style: Theme.of(context).textTheme.displayMedium,
                ),

                const SizedBox(height: 32),

                // Phone Number Input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InternationalPhoneNumberInput(
                    onInputChanged: (PhoneNumber number) {
                      setState(() {
                        _phoneNumber = number;
                      });
                    },
                    onInputValidated: (bool value) {
                      setState(() {
                        _isValid = value;
                      });
                    },
                    selectorConfig: const SelectorConfig(
                      selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                      useBottomSheetSafeArea: true,
                      setSelectorButtonAsPrefixIcon: true,
                      leadingPadding: 0,
                    ),
                    ignoreBlank: false,
                    autoValidateMode: AutovalidateMode.disabled,
                    selectorTextStyle: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                    initialValue: _phoneNumber,
                    textFieldController: _phoneController,
                    formatInput: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    inputDecoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Phone Number',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputBorder: InputBorder.none,
                  ),
                ),

                const SizedBox(height: 16),

                // Info text
                Text(
                  'We\'ll send you a verification code to confirm your number',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const Spacer(),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid && !_isLoading ? _sendOTP : null,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
