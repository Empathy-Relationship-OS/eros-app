import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/legal/presentation/age_signal_copy.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// Ends sign-up for someone under 18 (CF-F6): drops the draft and the signal, and signs out.
/// Sign-out also clears SharedPreferences, where the draft was saved. Tests replace it.
final underageSignOutProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    ref.read(signupAgeCheckProvider.notifier).state = null;
    await ref.read(profileCreationProvider.notifier).clearDraft();
    await ref.read(authStateProvider.notifier).signOut();
  };
});

/// The plain screen sign-up ends on when the store's band is under 18, or the backend answers
/// 403 `UNDERAGE` (RFC-009 §5.3.1). It signs out as it opens; OK goes back to the welcome screen.
class UnderageScreen extends ConsumerStatefulWidget {
  const UnderageScreen({super.key});

  /// Replaces the whole stack with this screen, so Back can't return to sign-up.
  static void show(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const UnderageScreen()),
      (route) => false,
    );
  }

  @override
  ConsumerState<UnderageScreen> createState() => _UnderageScreenState();
}

class _UnderageScreenState extends ConsumerState<UnderageScreen> {
  late final Future<void> _signedOut;

  @override
  void initState() {
    super.initState();
    _signedOut = _signOut();
  }

  Future<void> _signOut() async {
    try {
      await ref.read(underageSignOutProvider)();
    } catch (e) {
      // The screen still stops sign-up; the type only, as elsewhere.
      debugPrint('Underage sign-out failed (${e.runtimeType})');
    }
  }

  Future<void> _done() async {
    await _signedOut;
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AgeSignalCopy.underageTitle,
                  style: textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  AgeSignalCopy.underageBody,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                AppButton(label: AgeSignalCopy.underageDone, onPressed: _done),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
