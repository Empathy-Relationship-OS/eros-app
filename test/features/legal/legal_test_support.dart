import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/api_client_provider.dart';
import 'package:eros_app/features/legal/presentation/legal_links.dart';
import 'package:eros_app/features/profile/domain/models/profile_creation_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../verification/fake_verification_http.dart';

export '../verification/fake_verification_http.dart' show StubHttp, reply, apiClientOver;

const String documentsPath = '/legal/documents';
const String consentsPath = '/users/me/consents';
const String citiesPath = '/city/all';

const int londonId = 1;
const int newYorkId = 2;

/// `GET /city/all`.
final List<Map<String, dynamic>> cities = [
  {'cityId': londonId, 'cityName': 'London'},
  {'cityId': newYorkId, 'cityName': 'New York'},
];

Map<String, dynamic> documentJson(String kind, String version, {bool required = true}) => {
      'kind': kind,
      'version': version,
      'url': 'https://meetmymuse.com/${kind.toLowerCase()}?v=$version',
      'effectiveAt': '2026-11-01T00:00:00Z',
      'required': required,
    };

/// London's (`UK`) documents.
final List<Map<String, dynamic>> londonDocuments = [
  documentJson('TERMS', 'uk-3'),
  documentJson('PRIVACY_NOTICE', 'uk-2'),
  documentJson('SAFETY_NOTICE', 'uk-1'),
  documentJson('SENSITIVE_DATA', 'uk-4'),
  documentJson('LOCATION_PIN', 'uk-1', required: false),
  documentJson('MARKETING', 'uk-1', required: false),
];

/// New York's (`US-NY`) documents, with the Dating Bill of Rights.
final List<Map<String, dynamic>> newYorkDocuments = [
  documentJson('TERMS', 'ny-1'),
  documentJson('PRIVACY_NOTICE', 'ny-1'),
  documentJson('SAFETY_NOTICE', 'ny-2'),
  documentJson('DATING_BILL_OF_RIGHTS', 'ny-1'),
  documentJson('SENSITIVE_DATA', 'ny-1'),
  documentJson('MARKETING', 'ny-1', required: false),
];

/// Records the links opened instead of opening them.
class FakeLegalLinks extends LegalLinks {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

/// The network for legal screens: the real repositories over [http].
List<Override> legalOverrides(StubHttp http, {FakeLegalLinks? links}) => [
      apiClientProvider.overrideWith((ref) => apiClientOver(http)),
      authServiceProvider.overrideWithValue(FakeAuthService()),
      legalLinksProvider.overrideWithValue(links ?? FakeLegalLinks()),
    ];

/// A draft as far as the terms step, living in [city].
ProfileCreationDraft draftIn(String city) =>
    ProfileCreationDraft(firstName: 'Alex', lastName: 'Smith', city: city);

/// The `cityId` query parameter of the documents requests [http] received.
List<String?> documentCityIds(StubHttp http) =>
    [for (final r in http.sent('GET', documentsPath)) r.uri.queryParameters['cityId']];
