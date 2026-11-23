import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/domain/models/signup_consent.dart';
import 'package:eros_app/features/profile/presentation/providers/profile_creation_provider.dart';

/// What the user agreed to during sign-up, before `POST /users` sends it (RFC-009 §5.11).
///
/// Each kind maps to the version shown, or null when the region had no document of that kind in
/// effect (nothing to record then, so nothing is sent for it).
@immutable
class SignupConsents {
  final Map<DocumentKind, String?> agreed;

  const SignupConsents([this.agreed = const {}]);

  bool has(DocumentKind kind) => agreed.containsKey(kind);

  /// The consents `POST /users` carries: every kind agreed to on a version that was shown.
  List<SignupConsent> toRequest() => [
        for (final kind in DocumentKind.values)
          if (agreed[kind] case final version?) SignupConsent(kind: kind, version: version),
      ];
}

/// Holds [SignupConsents], kept on the device beside the profile draft so a restart mid sign-up
/// doesn't lose them. Only kinds and versions are kept; sign-out clears them with the rest.
class SignupConsentsNotifier extends StateNotifier<SignupConsents> {
  SignupConsentsNotifier(this._prefs) : super(_load(_prefs));

  static const storageKey = 'signup_consents';

  final SharedPreferences _prefs;

  static SignupConsents _load(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(storageKey);
      if (raw == null) return const SignupConsents();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SignupConsents({
        for (final entry in json.entries)
          ?DocumentKind.fromBackend(entry.key): entry.value as String?,
      });
    } catch (_) {
      return const SignupConsents();
    }
  }

  /// Records agreement to each kind in [versions], at the version shown (null: no document).
  Future<void> agree(Map<DocumentKind, String?> versions) =>
      _save({...state.agreed, ...versions});

  /// Forgets [kinds]: unticked, or sent back by the server to be shown again.
  Future<void> forget(Iterable<DocumentKind> kinds) {
    final remaining = {...state.agreed}..removeWhere((kind, _) => kinds.contains(kind));
    return _save(remaining);
  }

  /// After the profile exists: the consents are on the server now.
  Future<void> clear() => _save(const {});

  Future<void> _save(Map<DocumentKind, String?> agreed) async {
    state = SignupConsents(Map.unmodifiable(agreed));
    if (agreed.isEmpty) {
      await _prefs.remove(storageKey);
    } else {
      await _prefs.setString(
        storageKey,
        jsonEncode({for (final e in agreed.entries) e.key.backendValue: e.value}),
      );
    }
  }
}

final signupConsentsProvider =
    StateNotifierProvider<SignupConsentsNotifier, SignupConsents>((ref) {
  return SignupConsentsNotifier(ref.watch(sharedPreferencesProvider));
});

/// The kinds the server sent the user back to agree to again (400 `CONSENT_REQUIRED` from
/// `POST /users`). The step showing them says why the user is back.
final consentsToReviewProvider = StateProvider<Set<DocumentKind>>((ref) => const {});
