import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';

/// The signed-in user's own profile, as values, for the profile editor (RFC-004 §6.2).
///
/// Loads `GET /users/me`. [MyProfileNotifier.saveSection] sends one section's fields with
/// `PATCH /users/me`.
class MyProfileNotifier extends AsyncNotifier<MyProfile> {
  @override
  Future<MyProfile> build() {
    return ref.watch(profileRepositoryProvider).getCurrentUser();
  }

  /// Saves [request], which should hold only one section's fields.
  ///
  /// On success the state becomes the server's response, not a local merge, and
  /// [userProfileProvider] is invalidated so the Profile tab shows the change. On failure the
  /// previous state is kept and the error is rethrown for the section screen to show.
  Future<MyProfile> saveSection(UpdateUserRequest request) async {
    final saved = await ref.read(profileRepositoryProvider).updateUser(request);
    state = AsyncData(saved);
    ref.invalidate(userProfileProvider);
    return saved;
  }

  /// Reloads from the server.
  Future<void> refresh() async {
    state = const AsyncLoading<MyProfile>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => ref.read(profileRepositoryProvider).getCurrentUser());
  }
}

/// Provider for the signed-in user's own profile.
final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier, MyProfile>(
  MyProfileNotifier.new,
);
