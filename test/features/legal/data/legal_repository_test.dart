import 'package:eros_app/features/legal/data/account_repository.dart';
import 'package:eros_app/features/legal/data/legal_repository.dart';
import 'package:eros_app/features/legal/domain/models/consent.dart';
import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fake_legal_server.dart';

void main() {
  late FakeLegalServer server;
  late LegalRepository repository;

  setUp(() {
    server = FakeLegalServer();
    repository = LegalRepository(apiClientOverLegal(server));
  });

  group('documents', () {
    test('asks for the city region and parses each document', () async {
      final documents = await repository.documents(cityId: 7);

      expect(server.sent('GET', documentsPath).single.query, {'cityId': '7'});
      expect(documents.map((d) => d.kind), contains(DocumentKind.marketing));
      final marketing = documents.firstWhere((d) => d.kind == DocumentKind.marketing);
      expect(marketing.version, 'm-1');
      expect(marketing.url, 'https://meetmymuse.com/marketing');
      expect(marketing.required, isFalse);
      expect(marketing.effectiveAt, DateTime.utc(2026, 11));
    });

    test('without a city asks for ALL, and skips kinds this build does not know', () async {
      server.documents.add(documentJson('SOMETHING_NEW'));

      final documents = await repository.documents();

      expect(server.sent('GET', documentsPath).single.query, isEmpty);
      expect(documents, hasLength(6));
    });
  });

  group('consents', () {
    test('reads the newest row per kind', () async {
      final state = await repository.consents();

      expect(state.isGranted(DocumentKind.marketing), isTrue);
      expect(state.isGranted(DocumentKind.locationPin), isFalse);
      expect(state.isGranted(DocumentKind.terms), isFalse, reason: 'no row is not a grant');
      expect(state.orientationRetained, isFalse);
    });

    test('posts each choice with its version and the Settings source', () async {
      await repository.recordConsents(
        const [ConsentChoice(kind: DocumentKind.locationPin, version: 'p-2', granted: true)],
      );

      expect(server.sent('POST', consentsPath).single.body, {
        'consents': [
          {'kind': 'LOCATION_PIN', 'version': 'p-2', 'granted': true},
        ],
        'source': 'SETTINGS',
      });
    });

    test('reads orientationRetained after withdrawing sensitive data', () async {
      final state = await repository.recordConsents(
        const [ConsentChoice(kind: DocumentKind.sensitiveData, version: 's-3', granted: false)],
      );

      expect(state.orientationRetained, isTrue);
      expect(state.isGranted(DocumentKind.sensitiveData), isFalse);
    });

    test('maps 400 CONSENT_VERSION_STALE with its kinds', () async {
      server.nextConsentRefusal = (
        status: 400,
        body: {
          'error': 'CONSENT_VERSION_STALE',
          'message': 'A newer version is available',
          'kinds': ['MARKETING'],
        },
      );

      await expectLater(
        repository.recordConsents(
          const [ConsentChoice(kind: DocumentKind.marketing, version: 'old', granted: false)],
        ),
        throwsA(isA<ConsentVersionStale>()
            .having((e) => e.kinds, 'kinds', [DocumentKind.marketing])),
      );
    });

    test('maps 409 CONSENT_REQUIRED_FOR_SERVICE', () async {
      server.nextConsentRefusal = (
        status: 409,
        body: {
          'error': 'CONSENT_REQUIRED_FOR_SERVICE',
          'message': "Can't be withdrawn",
          'kinds': ['TERMS'],
        },
      );

      await expectLater(
        repository.recordConsents(
          const [ConsentChoice(kind: DocumentKind.terms, version: '2026-11', granted: false)],
        ),
        throwsA(isA<ConsentRequiredForService>()),
      );
    });

    test('passes any other refusal through as it is', () async {
      server.nextConsentRefusal = (status: 404, body: {'error': 'NOT_FOUND', 'message': 'No'});

      await expectLater(
        repository.recordConsents(
          const [ConsentChoice(kind: DocumentKind.marketing, version: 'm-1', granted: false)],
        ),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  group('AccountRepository.closeAccount', () {
    test('sends DELETE /users/me', () async {
      await AccountRepository(apiClientOverLegal(server)).closeAccount();

      expect(server.sent('DELETE', usersMePath), hasLength(1));
    });

    test('rethrows a refusal', () async {
      server.deleteStatus = 404;

      await expectLater(
        AccountRepository(apiClientOverLegal(server)).closeAccount(),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
