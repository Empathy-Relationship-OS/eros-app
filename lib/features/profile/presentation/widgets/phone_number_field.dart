import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

/// The one phone number field (RFC-010 primer rule 14): sign-up, settings and, later, sharing a
/// number with a date (#263) all use it, so they agree on what a valid number is.
///
/// A country picker (searchable, with flags and dial codes) sits inside the field, and the number
/// is formatted for that country as it's typed (a UK number typed with its leading 0 is accepted
/// but left unformatted: the package formats "+44" plus what was typed). [onChanged] reports the
/// number in E.164 (`+447400123456`) and whether it's valid for the chosen country
/// (libphonenumber), so the country code is never left out.
///
/// The country starts as [initialNumber]'s, else the device's region, else [fallbackIsoCode].
/// An [initialNumber] that can't be parsed (an older draft may hold free text without a country
/// code) starts the field empty.
///
/// Never log the number.
class PhoneNumberField extends StatefulWidget {
  /// The country used when neither [initialNumber] nor the device's region gives one.
  static const String fallbackIsoCode = 'GB';

  /// The number to start with, ideally E.164, or null for an empty field.
  final String? initialNumber;

  /// The device's region, e.g. `US`. Replaceable in tests.
  final String? Function() deviceRegion;

  /// Called on every change with the number in E.164 (null while empty) and whether it's valid.
  final void Function(String? e164, bool valid) onChanged;

  /// Called when the user edits the text, but not when the field reports its initial value.
  final VoidCallback? onEdited;

  /// Called when the keyboard's done action is pressed.
  final VoidCallback? onSubmit;

  /// An error to show instead of the field's own ("Enter a valid number for this country").
  final String? errorText;

  final String? helperText;

  const PhoneNumberField({
    super.key,
    required this.onChanged,
    this.initialNumber,
    this.deviceRegion = platformRegion,
    this.onEdited,
    this.onSubmit,
    this.errorText,
    this.helperText,
  });

  static String? platformRegion() => PlatformDispatcher.instance.locale.countryCode;

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  final _controller = TextEditingController();

  /// What the field starts with. Null while [PhoneNumberField.initialNumber] is being parsed.
  PhoneNumber? _initial;
  PhoneNumber? _current;
  bool _isValid = false;

  /// The user has typed something, so an invalid number gets an error under the field.
  bool _hasTyped = false;

  /// The text last time it changed, to tell a real edit from the package reporting the initial
  /// value.
  String? _lastText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final initial = await _parse(widget.initialNumber) ?? PhoneNumber(isoCode: _defaultIsoCode());
    if (!mounted) return;
    setState(() => _initial = _current = initial);
  }

  /// [phone] with its country, or null when there's none or it can't be parsed.
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
        : PhoneNumberField.fallbackIsoCode;
  }

  void _report() {
    final e164 = _controller.text.isEmpty ? null : _current?.phoneNumber;
    widget.onChanged(e164, _isValid);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _initial;
    if (initial == null) return const Center(child: CircularProgressIndicator());

    return InternationalPhoneNumberInput(
      initialValue: initial,
      textFieldController: _controller,
      onInputChanged: (number) {
        _current = number;
        final text = _controller.text;
        final typed = text.isNotEmpty;
        if (typed != _hasTyped) setState(() => _hasTyped = typed);
        if (_lastText != null && text != _lastText) widget.onEdited?.call();
        _lastText = text;
        _report();
      },
      onInputValidated: (valid) {
        if (valid != _isValid) setState(() => _isValid = valid);
        _report();
      },
      onSubmit: widget.onSubmit,
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
      // The package's own validator calls setState after every frame it runs in, so with
      // autovalidation frames never stop. The error is shown through errorText.
      autoValidateMode: AutovalidateMode.disabled,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      keyboardAction: TextInputAction.done,
      selectorTextStyle: Theme.of(context).textTheme.bodyLarge,
      inputDecoration: InputDecoration(
        labelText: 'Phone number',
        errorText: widget.errorText ??
            (_hasTyped && !_isValid ? 'Enter a valid number for this country' : null),
        helperText: widget.helperText,
      ),
    );
  }
}

/// [e164] for showing to its owner, e.g. `+44 7400 123456` or `+1 201-555-0123`: the dial code,
/// then the number formatted for its country. [e164] itself if it can't be parsed.
Future<String> formatPhoneNumberForDisplay(String e164) async {
  try {
    final parsed = await PhoneNumber.getRegionInfoFromPhoneNumber(e164);
    final dialCode = parsed.dialCode;
    if (parsed.isoCode == null || dialCode == null) return e164;
    final national = await PhoneNumber.getParsableNumber(parsed);
    return '${dialCode.startsWith('+') ? dialCode : '+$dialCode'} $national';
  } catch (_) {
    return e164;
  }
}
