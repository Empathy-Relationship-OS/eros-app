import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/widgets/auth_error_boundary.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:logger/logger.dart';

/// Loading screen that determines initial app route based on auth state
///
/// This screen checks:
/// 1. Firebase authentication state
/// 2. Whether user has a backend profile
/// 3. Routes to appropriate screen based on state
///
/// Uses Riverpod's ref.watch to reactively listen to Firebase auth state,
/// ensuring we wait for Firebase to fully restore the session before routing.
class AuthLoadingScreen extends ConsumerStatefulWidget {
  const AuthLoadingScreen({super.key});

  /// Where a sign-in that doesn't know whether the user has a profile goes next (Google and
  /// Apple, RFC-011 D-3). The app's home is this screen too.
  static const routeName = '/auth-loading';

  @override
  ConsumerState<AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends ConsumerState<AuthLoadingScreen> {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  bool _hasNavigated = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defer route determination to after the first frame is built
    // This ensures providers are initialized and context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineInitialRoute();
    });
  }

  Future<void> _determineInitialRoute() async {
    // Prevent multiple navigations
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    try {
      _logger.i('🔍 Determining initial route...');

      // Read auth state once - don't listen for changes
      // We only care about the initial auth state when the app launches
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.isAuthenticated;

      _logger.i('🔐 Firebase authenticated: $isAuthenticated');

      if (!isAuthenticated) {
        // No Firebase user - navigate to welcome screen
        _logger.i('➡️  No auth - navigating to welcome screen');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
        return;
      }

      // An Apple user who removed Muse in their Apple ID settings is signed out (RFC-011 §5.3)
      if (await _appleCredentialRevoked()) {
        _logger.i('➡️  Apple sign-in revoked - signing out to the welcome screen');
        await ref.read(authStateProvider.notifier).signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/welcome');
        }
        return;
      }

      // User is authenticated - check if they have a backend profile
      _logger.i('👤 Checking backend profile...');
      final profileRepository = ref.read(profileRepositoryProvider);
      final userExistsResponse = await profileRepository.checkUserExists();

      if (userExistsResponse.exists) {
        // User has completed profile - navigate to home/match screen
        _logger.i('✅ Profile exists - navigating to match screen');
        final sendAgeSignal = _existingUserAgeSignal();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/match');
        }
        sendAgeSignal?.call();
      } else {
        // User authenticated but no backend profile - navigate to profile creation
        _logger.i('📝 No profile - navigating to profile creation');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/profile-creation/name');
        }
      }
    } catch (e) {
      // Handle specific error types
      _logger.e('❌ Error determining route', error: e);

      String errorMsg = 'An unexpected error occurred. Please try signing out and back in.';

      // Check for permission/auth errors
      if (e is ForbiddenException || e is UnauthorizedException) {
        errorMsg = 'You do not have permission to view this account. This may be caused by signing in with a different account. Please sign out and try again.';
      } else if (e is NetworkException) {
        errorMsg = 'Network error. Please check your connection and try again.';
      }

      // Show error screen with sign-out option instead of auto-navigating
      if (mounted) {
        setState(() {
          _errorMessage = errorMsg;
        });
      }
    }
  }

  /// Whether the signed-in user's Apple ID no longer lets Muse in. Always false on Android and for
  /// users without Apple. Any failure counts as not revoked: nobody is signed out because Apple
  /// couldn't be reached.
  Future<bool> _appleCredentialRevoked() async {
    try {
      return await ref.read(authStateProvider.notifier).hasRevokedAppleCredential();
    } catch (e) {
      _logger.w('Apple credential check skipped (${e.runtimeType})');
      return false;
    }
  }

  /// The once-per-user app-store age check (RFC-009 CF-F6): sends the store's answer to
  /// `POST /users/me/age-signal`. Read here, before navigating away, because it outlives this
  /// screen. Null when it can't be set up; nothing about it may stop the app from opening.
  void Function()? _existingUserAgeSignal() {
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid == null) return null;
      final ageSignal = ref.read(existingUserAgeSignalProvider);
      return () => unawaited(ageSignal.sendOnce(uid));
    } catch (e) {
      _logger.w('Age signal check skipped (${e.runtimeType})');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't watch auth state - we only check it once in initState
    // Watching would cause unnecessary rebuilds on token refresh, etc.

    // Show error screen if we encountered an error
    return AuthErrorBoundary(
      errorMessage: _errorMessage,
      onRetry: () {
        setState(() {
          _errorMessage = null;
          _hasNavigated = false;
        });
        _determineInitialRoute();
      },
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo or branding
              Icon(
                Icons.favorite_rounded,
                size: 80,
                color: AppColors.primaryDeep,
              ),
              const SizedBox(height: 24),
              Text(
                'Muse',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 48),
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
