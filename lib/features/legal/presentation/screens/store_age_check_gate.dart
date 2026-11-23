import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/legal/data/services/age_signal_service.dart';
import 'package:eros_app/features/legal/presentation/age_signal_copy.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/legal/presentation/screens/underage_screen.dart';

/// Asks the app store for the age signal before the date of birth step (RFC-009 §5.3.1, CF-F6).
///
/// Once per sign-up: a minor band ends sign-up on [UnderageScreen]; an adult band or no signal
/// shows [child], and the result is kept in [signupAgeCheckProvider] for `POST /users`.
class StoreAgeCheckGate extends ConsumerStatefulWidget {
  final Widget child;

  const StoreAgeCheckGate({super.key, required this.child});

  @override
  ConsumerState<StoreAgeCheckGate> createState() => _StoreAgeCheckGateState();
}

class _StoreAgeCheckGateState extends ConsumerState<StoreAgeCheckGate> {
  late bool _checked;

  String? get _uid => ref.read(authServiceProvider).currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final check = ref.read(signupAgeCheckProvider);
    _checked = check != null && check.uid == _uid;
    if (!_checked) _check();
  }

  Future<void> _check() async {
    final uid = _uid;
    final signal = await ref.read(ageSignalServiceProvider).read();
    if (!mounted) return;
    if (signal != null && signal.isMinor) {
      UnderageScreen.show(context);
      return;
    }
    if (uid != null) ref.read(signupAgeCheckProvider.notifier).state = SignupAgeCheck(uid, signal);
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checked) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AgeSignalCopy.checking, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
