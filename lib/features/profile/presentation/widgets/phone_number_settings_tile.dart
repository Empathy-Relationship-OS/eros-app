import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_phone_number_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/phone_number_field.dart';

/// The "Phone number" row in settings (RFC-010 PH-F2): the user's own number, formatted for its
/// country, or "Not added". Opens [EditPhoneNumberScreen].
class PhoneNumberSettingsTile extends ConsumerWidget {
  const PhoneNumberSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    final number = profile.valueOrNull?.phoneNumber;

    final Widget subtitle;
    if (profile.hasValue) {
      subtitle = number == null
          ? const Text('Not added')
          : FutureBuilder<String>(
              future: formatPhoneNumberForDisplay(number),
              builder: (context, snapshot) => Text(snapshot.data ?? number),
            );
    } else if (profile.hasError) {
      subtitle = const Text('Couldn\'t load your number');
    } else {
      subtitle = const Text('Loading…');
    }

    return ListTile(
      leading: const Icon(Icons.phone_outlined, color: AppColors.textPrimary),
      title: const Text('Phone number'),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: () {
        if (profile.hasError) {
          ref.read(myProfileProvider.notifier).refresh();
          return;
        }
        if (!profile.hasValue) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EditPhoneNumberScreen()),
        );
      },
    );
  }
}
