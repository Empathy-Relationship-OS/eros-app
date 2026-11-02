import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/notifications/messaging_client.dart';
import 'package:eros_app/core/notifications/push_prompt_store.dart';
import 'package:eros_app/core/notifications/push_service.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';

/// Asks for push permission once per user, straight after they confirm presence (RFC-006 §6.4),
/// the moment the reason is clear. Never at launch.
///
/// "Shown" is stored per uid as soon as the sheet opens, so it never shows twice for that user on
/// this device, however it is closed. If notifications are already on, it is stored without
/// showing.
Future<void> maybeShowPushPermissionPrompt(
  BuildContext context,
  WidgetRef ref, {
  required String uid,
  required String partnerName,
}) async {
  final store = ref.read(pushPromptStoreProvider);
  if (store.hasShown(uid)) return;
  final push = ref.read(pushServiceProvider);
  if (await push.permissionStatus() == PushPermission.granted) {
    await store.markShown(uid);
    return;
  }
  await store.markShown(uid);
  if (!context.mounted) return;
  final turnOn = await showModalBottomSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => PushPermissionSheet(partnerName: partnerName),
  );
  if (turnOn == true) await push.requestPermission();
}

class PushPermissionSheet extends StatelessWidget {
  const PushPermissionSheet({super.key, required this.partnerName});

  final String partnerName;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.notifications_active_outlined, size: 36, color: AppColors.accentOrange),
            const SizedBox(height: 16),
            Text(
              DatesCopy.pushPromptBody(partnerName),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                DatesCopy.pushPromptTurnOn,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text(DatesCopy.pushPromptLater, style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
