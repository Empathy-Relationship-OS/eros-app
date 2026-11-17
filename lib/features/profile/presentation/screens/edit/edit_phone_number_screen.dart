import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/phone_number_field.dart';

/// Add, change or remove the user's phone number (RFC-010 PH-F2), with `PUT /users/me/phone`.
///
/// Same field as sign-up ([PhoneNumberField]). **Save** is enabled for a valid number that differs
/// from the saved one; **Remove number** appears when there is one and asks first. The number is
/// optional and only shared with a date if the user chooses (#263).
class EditPhoneNumberScreen extends ConsumerStatefulWidget {
  /// The device's region, e.g. `US`. Replaceable in tests.
  final String? Function() deviceRegion;

  const EditPhoneNumberScreen({super.key, this.deviceRegion = PhoneNumberField.platformRegion});

  @override
  ConsumerState<EditPhoneNumberScreen> createState() => _EditPhoneNumberScreenState();
}

class _EditPhoneNumberScreenState extends ConsumerState<EditPhoneNumberScreen> {
  /// The number saved when the screen opened.
  late final String? _saved = ref.read(myProfileProvider).valueOrNull?.phoneNumber;

  /// The field's number in E.164. Starts as [_saved], so nothing counts as changed until the user
  /// edits it.
  late String? _e164 = _saved;
  bool _valid = false;
  bool _removing = false;

  /// Set once the number is removed, so the discard guard lets the screen close.
  bool _removed = false;

  bool get _changed => !_removed && _e164 != _saved;

  Future<void> _save() async {
    await ref.read(myProfileProvider.notifier).savePhoneNumber(_e164);
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove your phone number?'),
        content: const Text(
          'You won\'t be able to share it with a date until you add it again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removing = true);
    try {
      await ref.read(myProfileProvider.notifier).savePhoneNumber(null);
      if (!mounted) return;
      setState(() => _removed = true);
      // After the rebuild, so the discard guard sees nothing unsaved.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } on ProfileRepositoryException catch (e) {
      _failRemove(e.message);
    } on ProfileValidationException catch (e) {
      _failRemove(e.getUserMessage());
    }
  }

  void _failRemove(String message) {
    if (!mounted) return;
    setState(() => _removing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: 'Phone number',
      canSave: _valid && _e164 != null && _changed && !_removing,
      isDirty: _changed,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Only shared with a date if you choose. Nobody else sees it.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          PhoneNumberField(
            initialNumber: _saved,
            deviceRegion: widget.deviceRegion,
            onChanged: (e164, valid) {
              if (e164 != _e164 || valid != _valid) {
                setState(() {
                  _e164 = e164;
                  _valid = valid;
                });
              }
            },
            helperText: 'Pick your country, then enter your number',
          ),
          if (_saved != null) ...[
            const SizedBox(height: 32),
            Center(
              child: TextButton.icon(
                onPressed: _removing ? null : _remove,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                label: const Text('Remove number', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
