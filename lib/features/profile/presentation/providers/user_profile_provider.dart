import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';

/// State for user profile
class UserProfileState {
  final PublicProfileDTO? profile;
  final bool isLoading;
  final String? errorMessage;

  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  });

  UserProfileState copyWith({
    PublicProfileDTO? profile,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  UserProfileState clearError() {
    return UserProfileState(
      profile: profile,
      isLoading: isLoading,
      errorMessage: null,
    );
  }
}

/// Notifier for managing current user's public profile
class UserProfileNotifier extends StateNotifier<UserProfileState> {
  final ProfileRepository _profileRepository;
  final String _userId;
  final Logger _logger;

  UserProfileNotifier({
    required ProfileRepository profileRepository,
    required String userId,
  })  : _profileRepository = profileRepository,
        _userId = userId,
        _logger = Logger(
          printer: PrettyPrinter(
            methodCount: 0,
            errorMethodCount: 5,
            lineLength: 80,
            colors: true,
            printEmojis: true,
            dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
          ),
        ),
        super(const UserProfileState()) {
    // Auto-load profile on initialization
    loadProfile();
  }

  /// Load the user's public profile
  Future<void> loadProfile() async {
    if (state.isLoading) {
      _logger.d('🔄 Profile already loading, skipping duplicate request');
      return;
    }

    _logger.i('📥 Loading user profile for: $_userId');
    state = state.copyWith(isLoading: true).clearError();

    try {
      final profile = await _profileRepository.getPublicProfile(_userId);
      _logger.i('✅ Profile loaded successfully');
      state = UserProfileState(profile: profile, isLoading: false);
    } on ProfileRepositoryException catch (e) {
      _logger.e('❌ Failed to load profile', error: e);
      state = UserProfileState(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      _logger.e('💥 Unexpected error loading profile', error: e);
      state = UserProfileState(
        isLoading: false,
        errorMessage: 'Failed to load profile. Please try again.',
      );
    }
  }

  /// Refresh the profile (force reload)
  Future<void> refresh() async {
    _logger.i('🔄 Refreshing user profile');
    await loadProfile();
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }
}

/// Provider for current user's public profile
/// Automatically loads the profile when the user is authenticated
final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>((ref) {
  // Watch the current user from auth state
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) {
    throw Exception('User must be authenticated to access profile');
  }

  final profileRepository = ref.watch(profileRepositoryProvider);

  return UserProfileNotifier(
    profileRepository: profileRepository,
    userId: currentUser.uid,
  );
});

/// Convenience provider for just the profile data
final currentUserProfileProvider = Provider<PublicProfileDTO?>((ref) {
  return ref.watch(userProfileProvider).profile;
});

/// Convenience provider to check if profile is loading
final isProfileLoadingProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider).isLoading;
});

/// Convenience provider for profile error message
final profileErrorProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider).errorMessage;
});
