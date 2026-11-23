import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/legal/presentation/screens/reconsent_screen.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// Wraps the signed-in home: on launch and whenever the app resumes, reads `GET /users/me` and,
/// if `outstandingConsents` isn't empty, opens the [ReconsentScreen] over everything (RFC-009
/// §5.2). A failed check shows nothing; the next resume asks again.
class ReconsentGate extends ConsumerStatefulWidget {
  final Widget child;

  const ReconsentGate({super.key, required this.child});

  @override
  ConsumerState<ReconsentGate> createState() => _ReconsentGateState();
}

class _ReconsentGateState extends ConsumerState<ReconsentGate> {
  AppLifecycleListener? _lifecycle;

  /// True from the check until the screen it opened closes, so a resume can't open a second.
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final profile = await ref.read(profileRepositoryProvider).getCurrentUser();
      if (!mounted || profile.outstandingConsents.isEmpty) return;
      await Navigator.of(context, rootNavigator: true).push(
        ReconsentScreen.route(outstanding: profile.outstandingConsents, cityName: profile.city),
      );
    } catch (_) {
      // Offline or signed out: nothing to show now.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
