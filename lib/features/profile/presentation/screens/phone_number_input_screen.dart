import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/constants/profile_creation.dart';
import 'package:eros_app/features/profile/presentation/widgets/profile_progress_bar.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Phone number step of profile creation.
///
/// A country picker (searchable, with flags and dial codes) sits inside the field, and the number
/// is formatted for that country as it's typed (a UK number typed with its leading 0 is accepted
/// but left unformatted: the package formats "+44" plus what was typed). Continue is enabled only for a number that's valid
/// for the chosen country (libphonenumber), and the draft stores it in E.164 (`+447911123456`), so
/// the country code is never left out.
///
/// The country starts as the one of the number already known (the Firebase account's, else the
/// draft's), else the device's region, else [PhoneNumberInputScreen.fallbackIsoCode].
///
/// The number is optional (RFC-010 D-3): it's kept only so the user can share it with a date if
/// they choose, and **Skip** continues without one. If the backend refuses the number at the end
/// of sign-up, the user is brought back here ([phoneNumberRejectedProvider]) to fix it or skip.
class PhoneNumberInputScreen extends ConsumerStatefulWidget {
  /// The country used when neither a saved number nor the device's region gives one.
  static const String fallbackIsoCode = 'GB';

  /// The device's region, e.g. `US`. Replaceable in tests.
  final String? Function() deviceRegion;

  const PhoneNumberInputScreen({super.key, this.deviceRegion = _platformRegion});

  static String? _platformRegion() => PlatformDispatcher.instance.locale.countryCode;

  @override
  ConsumerState<PhoneNumberInputScreen> createState() => _PhoneNumberInputScreenState();
}

class _PhoneNumberInputScreenState extends ConsumerState<PhoneNumberInputScreen> {
  final _phoneController = TextEditingController();

  /// What the field starts with. Null while a saved number is being parsed for its country.
  PhoneNumber? _initial;
  PhoneNumber? _current;
  bool _isValid = false;
  bool _isPhoneFromFirebase = false;

  /// The user has typed something, so an invalid number gets an error under the field.
  bool _hasTyped = false;

  /// The field's text last time it changed, to tell a real edit from the package reporting the
  /// initial value.
  String? _lastText;

  @override
  void initState() {
    super.initState();
    _loadPhoneData();
  }

  Future<void> _loadPhoneData() async {
    final firebasePhone = ref.read(authServiceProvider).currentUser?.phoneNumber;
    final draftPhone = ref.read(profileCreationProvider).phoneNumber;
    _isPhoneFromFirebase = firebasePhone != null && firebasePhone.isNotEmpty;
    final known = _isPhoneFromFirebase ? firebasePhone : draftPhone;

    // Awaited before anything touches the draft: initState may not modify a provider while the
    // tree builds.
    final initial = await _parse(known) ?? PhoneNumber(isoCode: _defaultIsoCode());
    if (!mounted) return;
    setState(() => _initial = _current = initial);

    if (_isPhoneFromFirebase) {
      // Saved to the draft straight away, as the user may not change it.
      await ref.read(profileCreationProvider.notifier).updateFields(phoneNumber: firebasePhone);
    }
  }

  /// [phone] with its country, or null when there's none or it can't be parsed (an older draft
  /// may hold free text without a country code).
  Future<PhoneNumber?> _parse(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return null;
    try {
      final parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(phone.trim());
      return parsed.isoCode == null ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  String _defaultIsoCode() {
    final region = widget.deviceRegion()?.toUpperCase();
    return region != null && RegExp(r'^[A-Z]{2}$').hasMatch(region)
        ? region
        : PhoneNumberInputScreen.fallbackIsoCode;
  }

  Future<void> _continue() async {
    final phoneNumber = _current?.phoneNumber;
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
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initial;
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
              if (initial == null)
                const Center(child: CircularProgressIndicator())
              else
                InternationalPhoneNumberInput(
                  initialValue: initial,
                  textFieldController: _phoneController,
                  onInputChanged: (number) {
                    _current = number;
                    final text = _phoneController.text;
                    final typed = text.isNotEmpty;
                    if (typed != _hasTyped) setState(() => _hasTyped = typed);
                    // An edit after the backend refused the number clears the message.
                    if (_lastText != null && text != _lastText && ref.read(phoneNumberRejectedProvider)) {
                      ref.read(phoneNumberRejectedProvider.notifier).state = false;
                    }
                    _lastText = text;
                  },
                  onInputValidated: (valid) {
                    if (valid != _isValid) setState(() => _isValid = valid);
                  },
                  onSubmit: _continue,
                  selectorConfig: const SelectorConfig(
                    selectorType: PhoneInputSelectorType.BOTTOM_SHEET,
                    useBottomSheetSafeArea: true,
                    setSelectorButtonAsPrefixIcon: true,
                    leadingPadding: 12,
                    trailingSpace: false,
                  ),
                  searchBoxDecoration: const InputDecoration(
                    labelText: 'Search by country name or dial code',
                    prefixIcon: Icon(Icons.search),
                  ),
                  formatInput: true,
                  // The package's own validator calls setState after every frame it runs in, so
                  // with autovalidation frames never stop. The error is shown through errorText.
                  autoValidateMode: AutovalidateMode.disabled,
                  keyboardType: const TextInputType.numberWithOptions(signed: true),
                  keyboardAction: TextInputAction.done,
                  selectorTextStyle: Theme.of(context).textTheme.bodyLarge,
                  inputDecoration: InputDecoration(
                    labelText: 'Phone number',
                    errorText: rejected
                        ? 'That number didn\'t work. Check it, or skip this step.'
                        : (_hasTyped && !_isValid ? 'Enter a valid number for this country' : null),
                    helperText: _isPhoneFromFirebase
                        ? 'You can edit this if needed'
                        : 'Pick your country, then enter your number',
                  ),
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
