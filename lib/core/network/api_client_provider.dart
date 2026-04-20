import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';
import 'api_client.dart';

/// Provides singleton ApiClient instance with AuthService dependency
final apiClientProvider = Provider<ApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiClient(authService);
});
