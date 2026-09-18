import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';
import 'api_client.dart';
import 'package:eros_app/features/auth/presentation/providers/auth_state_provider.dart';

/// Provides ApiClient instance that recreates on auth state changes
/// This ensures no stale auth tokens or cached state persist after sign-out
final apiClientProvider = Provider<ApiClient>((ref) {
  // Watch currentUserProvider to recreate API client when user changes
  // This is CRITICAL - forces new Dio instance with fresh interceptors
  final currentUser = ref.watch(currentUserProvider);

  final authService = ref.watch(authServiceProvider);
  final client = ApiClient(authService);

  // Log API client creation for debugging
  if (currentUser != null) {
    // ignore: avoid_print
    print('🔄 API Client created for user: ${currentUser.uid}');
  } else {
    // ignore: avoid_print
    print('🔄 API Client created (no authenticated user)');
  }

  return client;
});
