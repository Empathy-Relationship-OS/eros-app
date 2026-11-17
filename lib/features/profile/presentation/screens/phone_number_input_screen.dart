import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/phone_number_field.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Phone number step of profile creation, built on [PhoneNumberField] (country picker,
/// formatting, libphonenumber validation, E.164). Continue is enabled only for a valid number.
///
/// The field starts on the number already known (the Firebase account's, else the draft's),
/// else the device's region, else [PhoneNumberInputScreen.fallbackIsoCode].
///
/// The number is optional (RFC-010 D-3): it's kept only so the user can share it with a date if
/// they choose, and **Skip** continues without one. If the backend refuses the number at the end
/// of sign-up, the user is brought back here ([phoneNumberRejectedProvider]) to fix it or skip.
class PhoneNumberInputScreen extends ConsumerStatefulWidget {
  /// The country used when neither a saved number nor the device's region gives one.
  static const String fallbackIsoCode = PhoneNumberField.fallbackIsoCode;

  /// The device's region, e.g. `US`. Replaceable in tests.
  final String? Function() deviceRegion;

  const PhoneNumberInputScreen({super.key, this.deviceRegion = PhoneNumberField.platformRegion});

  @override
  ConsumerState<PhoneNumberInputScreen> createState() => _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState extends ConsumerState<PhoneNumberInputScreen> {
  late final String? _firebasePhone;
  late final String? _known;
  String? _e164;
  bool _isValid = false;

  bool get _isPhoneFromFirebase => _firebasePhone != null && _firebasePhone.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _firebasePhone = ref.read(authServiceProvider).currentUser?.phoneNumber;
    _known = _isPhoneFromFirebase ? _firebasePhone : ref.read(profileCreationProvider).phoneNumber;
    if (_isPhoneFromFirebase) {
      // Saved to the draft straight away, as the user may not change it. After the first frame:
      // initState may not modify a provider while the tree builds.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(profileCreationProvider.notifier).updateFields(phoneNumber: _firebasePhone);
        }
      });
    }
  }

  Future<void> _continue() async {
    final phoneNumber = _e164;
    if (!_isValid || phoneNumber == null) return;

    // Auto-populate email from Firebase in the background
    final email = ref.read(authServiceProvider).currentUser?.email;

    await ref.read(profileCreationProvider.notifier).updateFields(
          phoneNumber: phoneNumber,
          email: email,
        );
    _next();
  }

  /// Continues with no number in the draft, removing one typed or saved earlier.
  Future<void> _skip() async {
    final notifier = ref.read(profileCreationProvider.notifier);
    await notifier.clearPhoneNumber();
    // The email is filled in here whichever way the user leaves the step.
    final email = ref.read(authServiceProvider).currentUser?.email;
    if (email != null) await notifier.updateFields(email: email);
    _next();
  }

  void _next() {
    ref.read(phoneNumberRejectedProvider.notifier).state = false;
    if (mounted) {
      Navigator.pushNamed(context, '/profile-creation/terms');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = ref.watch(phoneNumberRejectedProvider);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileProgressBar(
                currentStep: ProfileCreationConstants.basicInfoStepPhoneNumber,
                totalSteps: ProfileCreationConstants.basicInfoTotalSteps,
              ),
              const SizedBox(height: 32),
              Text(
                _isPhoneFromFirebase
                    ? 'Confirm your phone number'
                    : 'What\'s your phone number?',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                _isPhoneFromFirebase
                    ? 'We\'ve pulled this from your account'
                    : 'Add your number so you can share it with a date if you choose. '
                        'Nobody sees it unless you do.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 32),
              PhoneNumberField(
                initialNumber: _known,
                deviceRegion: widget.deviceRegion,
                onChanged: (e164, valid) {
                  _e164 = e164;
                  if (valid != _isValid) setState(() => _isValid = valid);
                },
                // An edit after the backend refused the number clears the message.
                onEdited: () {
                  if (ref.read(phoneNumberRejectedProvider)) {
                    ref.read(phoneNumberRejectedProvider.notifier).state = false;
                  }
                },
                onSubmit: _continue,
                errorText: rejected ? 'That number didn\'t work. Check it, or skip this step.' : null,
                helperText: _isPhoneFromFirebase
                    ? 'You can edit this if needed'
                    : 'Pick your country, then enter your number',
              ),
              const Spacer(),
              AppButton(label: 'Continue', onPressed: _isValid ? _continue : null),
              const SizedBox(height: 8),
              Center(
                child: TextButton(onPressed: _skip, child: const Text('Skip')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
