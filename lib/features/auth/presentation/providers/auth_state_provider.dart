import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';

/// Auth state class
class AuthState {
  final User? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({this.user, this.isLoading = false, this.errorMessage});

  bool get isAuthenticated => user != null;

  AuthState copyWith({User? user, bool? isLoading, String? errorMessage}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  AuthState clearError() {
    return AuthState(user: user, isLoading: isLoading, errorMessage: null);
  }
}

/// Auth state notifier
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthStateNotifier(this._authRepository)
      : super(AuthState(user: _authRepository.currentUser)) {
    // Initialize with current user (if any) for immediate auth state availability
    // Then listen to auth state changes for updates
    _authRepository.authStateChanges.listen((user) {
      state = AuthState(user: user);
    });
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true).clearError();

    final result = await _authRepository.signUpWithEmail(
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      state = AuthState(user: result.user, isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true).clearError();

    final result = await _authRepository.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.isSuccess) {
      state = AuthState(user: result.user, isLoading: false);
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return false;
    }
  }

  /// Continue with Google: sign-up and sign-in are the same call (RFC-011 D-3).
  ///
  /// Null when the user closed Google's sheet: nothing changes and nothing is shown. On a
  /// failure, [AuthState.errorMessage] holds the message too.
  Future<AuthResult?> signInWithGoogle() => _signInWithProvider(_authRepository.signInWithGoogle);

  /// Continue with Apple, iOS only (RFC-011 §5.3). Same results as [signInWithGoogle].
  Future<AuthResult?> signInWithApple() => _signInWithProvider(_authRepository.signInWithApple);

  /// True when the signed-in user's Apple ID no longer lets Muse in, so they should be signed out
  /// (RFC-011 §5.3). False when the check can't tell.
  Future<bool> hasRevokedAppleCredential() => _authRepository.hasRevokedAppleCredential();

  Future<AuthResult?> _signInWithProvider(Future<AuthResult?> Function() signIn) async {
    state = state.copyWith(isLoading: true).clearError();

    final result = await signIn();

    if (result == null) {
      state = state.copyWith(isLoading: false);
    } else if (result.isSuccess) {
      state = AuthState(user: result.user, isLoading: false);
    } else {
      state = state.copyWith(isLoading: false, errorMessage: result.errorMessage);
    }
    return result;
  }

  /// Sign out
  Future<void> signOut() async {
    await _authRepository.signOut();
    state = const AuthState();
  }

  /// Get Firebase ID token
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _authRepository.getIdToken(forceRefresh: forceRefresh);
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(isLoading: true).clearError();

    final result = await _authRepository.sendPasswordResetEmail(email);

    state = state.copyWith(
      isLoading: false,
      errorMessage: result.isSuccess ? null : result.errorMessage,
    );

    return result.isSuccess;
  }

  /// Clear error message
  void clearError() {
    state = state.clearError();
  }
}

/// Auth state provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  final authRepository = ref.read(authRepositoryProvider);
  return AuthStateNotifier(authRepository);
});

/// Current user provider (convenience)
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).user;
});

/// Is authenticated provider (convenience)
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).isAuthenticated;
});
