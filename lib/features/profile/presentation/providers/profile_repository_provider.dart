import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// Provider for ProfileRepository
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});
