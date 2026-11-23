import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preference_options_provider.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/domain/models/consent.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/providers/user_profile_provider.dart';

/// What "Privacy, safety and legal" shows: the current documents for the user's region and their
/// consents, both from the server (primer rule 20).
@immutable
class PrivacySettingsData {
  /// The user's id, for the support emails.
  final String accountId;
  final List<LegalDocument> documents;
  final ConsentState consents;

  const PrivacySettingsData({
    required this.accountId,
    required this.documents,
    required this.consents,
  });

  /// The current document of [kind], whose version a choice must name, or null if there is none.
  LegalDocument? documentFor(DocumentKind kind) {
    for (final document in documents) {
      if (document.kind == kind) return document;
    }
    return null;
  }

  PrivacySettingsData copyWith({List<LegalDocument>? documents, ConsentState? consents}) {
    return PrivacySettingsData(
      accountId: accountId,
      documents: documents ?? this.documents,
      consents: consents ?? this.consents,
    );
  }
}

/// There is no current document of [kind], so there is no version to consent to.
class ConsentDocumentMissing implements Exception {
  final DocumentKind kind;

  const ConsentDocumentMissing(this.kind);

  @override
  String toString() => 'ConsentDocumentMissing(${kind.backendValue})';
}

/// Loads the documents and consents when the screen opens, and again after every change.
class PrivacySettingsNotifier extends AutoDisposeAsyncNotifier<PrivacySettingsData> {
  @override
  Future<PrivacySettingsData> build() async {
    // Read, not watched: withdrawing sensitive data refreshes the profile, and that mustn't
    // reload this screen under the dialog that follows.
    final profile = await ref.read(myProfileProvider.future);
    final cityId = await _cityIdFor(profile.city);
    final repository = ref.read(legalRepositoryProvider);
    final (documents, consents) =
        await (repository.documents(cityId: cityId), repository.consents()).wait;
    return PrivacySettingsData(accountId: profile.userId, documents: documents, consents: consents);
  }

  /// The id of the user's city, so the documents are their region's: the backend picks the
  /// region the same way, matching the profile's city name to a city case-insensitively. Null
  /// (the `ALL` region) when the cities can't be loaded or none matches.
  Future<int?> _cityIdFor(String city) async {
    try {
      final cities = await ref.read(datingCitiesProvider.future);
      final name = city.trim().toLowerCase();
      for (final candidate in cities) {
        if (candidate.cityName.trim().toLowerCase() == name) return candidate.cityId;
      }
    } catch (_) {
      // Fall through to ALL. A stale version is then refused with CONSENT_VERSION_STALE.
    }
    return null;
  }

  /// Grants or withdraws [kind] on its current document's version, then reloads the consents.
  ///
  /// Returns the `POST` answer, whose [ConsentState.orientationRetained] the screen needs after
  /// sensitive data is withdrawn. On [ConsentVersionStale] the documents and consents are
  /// reloaded before it is rethrown, so the next attempt names the new version.
  Future<ConsentState> setConsent(DocumentKind kind, {required bool granted}) async {
    final data = await future;
    final document = data.documentFor(kind);
    if (document == null) throw ConsentDocumentMissing(kind);
    final repository = ref.read(legalRepositoryProvider);
    try {
      final answer = await repository.recordConsents(
        [ConsentChoice(kind: kind, version: document.version, granted: granted)],
      );
      if (kind == DocumentKind.sensitiveData && !granted) _refreshProfileData();
      await _reloadConsents();
      return answer;
    } on ConsentVersionStale {
      await refresh();
      rethrow;
    }
  }

  /// Reloads the documents and consents.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // The screen shows the error state with a retry.
    }
  }

  Future<void> _reloadConsents() async {
    final consents = await ref.read(legalRepositoryProvider).consents();
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(consents: consents));
  }

  /// The server cleared religion, ethnicity and their filters: drop the copies already loaded.
  /// One that was never loaded is left alone, so nothing starts loading for no screen.
  void _refreshProfileData() {
    if (ref.exists(myProfileProvider)) ref.invalidate(myProfileProvider);
    if (ref.exists(userProfileProvider)) ref.invalidate(userProfileProvider);
    if (ref.exists(matchPreferencesProvider)) ref.invalidate(matchPreferencesProvider);
  }
}

final privacySettingsProvider =
    AsyncNotifierProvider.autoDispose<PrivacySettingsNotifier, PrivacySettingsData>(
  PrivacySettingsNotifier.new,
);
