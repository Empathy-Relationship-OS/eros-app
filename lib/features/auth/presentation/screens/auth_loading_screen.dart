import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
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

      // User is authenticated - check if they have a backend profile
      _logger.i('👤 Checking backend profile...');
      final profileRepository = ref.read(profileRepositoryProvider);
      final userExistsResponse = await profileRepository.checkUserExists();

      if (userExistsResponse.exists) {
        // User has completed profile - navigate to home/match screen
        _logger.i('✅ Profile exists - navigating to match screen');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/match');
        }
      } else {
        // User authenticated but no backend profile - navigate to profile creation
        _logger.i('📝 No profile - navigating to profile creation');
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/profile-creation/name');
        }
      }
    } catch (e) {
      // On error, default to welcome screen
      _logger.e('❌ Error determining route', error: e);
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't watch auth state - we only check it once in initState
    // Watching would cause unnecessary rebuilds on token refresh, etc.

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo or branding
            Icon(
              Icons.favorite_rounded,
              size: 80,
              color: AppColors.primaryOrange,
            ),
            const SizedBox(height: 24),
            const Text(
              'Muse',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 48),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
          ],
        ),
      ),
    );
  }
}
