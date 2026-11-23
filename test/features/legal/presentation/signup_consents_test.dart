import 'package:eros_app/features/legal/domain/models/legal_document.dart';
import 'package:eros_app/features/legal/domain/models/signup_consent.dart';
import 'package:eros_app/features/legal/presentation/legal_routes.dart';
import 'package:eros_app/features/legal/presentation/providers/legal_documents_provider.dart';
import 'package:eros_app/features/legal/presentation/providers/signup_consents_provider.dart';
import 'package:eros_app/features/legal/presentation/screens/sensitive_data_consent_screen.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_copy.dart';
import 'package:eros_app/features/legal/presentation/widgets/legal_document_tile.dart';
import 'package:eros_app/features/date_preferences/domain/models/dating_city.dart';
import 'package:eros_app/features/profile/presentation/screens/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../profile/presentation/screens/onboarding_harness.dart';
import '../legal_test_support.dart';

StubHttp _http(List<Map<String, dynamic>> documents) => StubHttp()
  ..responses['GET $citiesPath'] = reply(200, cities)
  ..responses['GET $documentsPath'] = reply(200, documents);

Future<void> _tick(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String label) {
  final button = tester.widget<ButtonStyleButton>(
    find.ancestor(of: find.text(label), matching: find.bySubtype<ButtonStyleButton>()).first,
  );
  return button.onPressed != null;
}

void main() {
  group('the terms step', () {
    testWidgets('London shows the terms, privacy and safety notice, and no Bill of Rights',
        (tester) async {
      final http = _http(londonDocuments);
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('London'), overrides: legalOverrides(http));
      await tester.pumpAndSettle();

      expect(documentCityIds(http), ['$londonId']);
      expect(find.text(LegalCopy.documentTitle(DocumentKind.terms)), findsOneWidget);
      expect(find.text(LegalCopy.documentTitle(DocumentKind.privacyNotice)), findsOneWidget);
      expect(find.text(LegalCopy.documentTitle(DocumentKind.safetyNotice)), findsOneWidget);
      expect(find.text(LegalCopy.documentTitle(DocumentKind.datingBillOfRights)), findsNothing);
      expect(find.byKey(const Key('consent-bill-of-rights')), findsNothing);
    });

    testWidgets('New York shows the Dating Bill of Rights and needs it acknowledged',
        (tester) async {
      final http = _http(newYorkDocuments);
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('new york'), overrides: legalOverrides(http));
      await tester.pumpAndSettle();

      expect(documentCityIds(http), ['$newYorkId']);
      expect(find.text(LegalCopy.documentTitle(DocumentKind.datingBillOfRights)), findsOneWidget);

      await _tick(tester, 'consent-terms');
      await _tick(tester, 'consent-safety');
      expect(_enabled(tester, LegalCopy.acceptAndContinue), isFalse);
      await _tick(tester, 'consent-bill-of-rights');
      expect(_enabled(tester, LegalCopy.acceptAndContinue), isTrue);
    });

    testWidgets('every tick starts off, and Accept needs terms and the safety notice',
        (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('London'), overrides: legalOverrides(_http(londonDocuments)));
      await tester.pumpAndSettle();

      for (final key in ['consent-terms', 'consent-safety', 'consent-marketing']) {
        expect(tester.widget<ConsentCheckbox>(find.byKey(Key(key))).value, isFalse);
      }
      expect(_enabled(tester, LegalCopy.acceptAndContinue), isFalse);
      await _tick(tester, 'consent-terms');
      expect(_enabled(tester, LegalCopy.acceptAndContinue), isFalse);
      await _tick(tester, 'consent-safety');
      expect(_enabled(tester, LegalCopy.acceptAndContinue), isTrue);
    });

    testWidgets('keeps the versions shown, marketing only when ticked', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('New York'), overrides: legalOverrides(_http(newYorkDocuments)));
      await tester.pumpAndSettle();

      await _tick(tester, 'consent-terms');
      await _tick(tester, 'consent-safety');
      await _tick(tester, 'consent-bill-of-rights');
      await _tick(tester, 'consent-marketing');
      await tester.tap(find.text(LegalCopy.acceptAndContinue));
      await tester.pumpAndSettle();

      expect(harness.pushed, ['/profile-creation/complete-basic']);
      expect(harness.container.read(signupConsentsProvider).toRequest(), const [
        SignupConsent(kind: DocumentKind.terms, version: 'ny-1'),
        SignupConsent(kind: DocumentKind.privacyNotice, version: 'ny-1'),
        SignupConsent(kind: DocumentKind.safetyNotice, version: 'ny-2'),
        SignupConsent(kind: DocumentKind.datingBillOfRights, version: 'ny-1'),
        SignupConsent(kind: DocumentKind.marketing, version: 'ny-1'),
      ]);
    });

    testWidgets('opens each document at the server\'s URL', (tester) async {
      final links = FakeLegalLinks();
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('London'),
          overrides: legalOverrides(_http(londonDocuments), links: links));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('read-TERMS')));
      await tester.pumpAndSettle();

      expect(links.opened, [Uri.parse('https://meetmymuse.com/terms?v=uk-3')]);
    });

    testWidgets('a step the server sent the user back to says so', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const TermsScreen(),
          initialDraft: draftIn('London'), overrides: legalOverrides(_http(londonDocuments)));
      harness.container.read(consentsToReviewProvider.notifier).state = {DocumentKind.terms};
      await tester.pumpAndSettle();

      expect(find.text(LegalCopy.reviewAgain), findsOneWidget);
    });
  });

  group('the sensitive data step', () {
    testWidgets('blocks sign-up until its own tick, then keeps the version shown',
        (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const SensitiveDataConsentScreen(),
          initialDraft: draftIn('London'), overrides: legalOverrides(_http(londonDocuments)));
      await tester.pumpAndSettle();

      expect(find.text(LegalCopy.sensitiveRequired), findsOneWidget);
      final tick = tester.widget<ConsentCheckbox>(find.byKey(const Key('consent-sensitive-data')));
      expect(tick.value, isFalse);
      await tester.tap(find.text(LegalCopy.continueLabel));
      await tester.pumpAndSettle();
      expect(harness.pushed, isEmpty);

      await _tick(tester, 'consent-sensitive-data');
      await tester.tap(find.text(LegalCopy.continueLabel));
      await tester.pumpAndSettle();

      expect(harness.pushed, [LegalRoutes.afterSensitiveData]);
      expect(harness.container.read(signupConsentsProvider).toRequest(), const [
        SignupConsent(kind: DocumentKind.sensitiveData, version: 'uk-4'),
      ]);
    });

    testWidgets('unticking forgets it', (tester) async {
      final harness = OnboardingHarness();
      await harness.pump(tester, const SensitiveDataConsentScreen(),
          initialDraft: draftIn('London'), overrides: legalOverrides(_http(londonDocuments)));
      await tester.pumpAndSettle();

      await _tick(tester, 'consent-sensitive-data');
      await tester.tap(find.text(LegalCopy.continueLabel));
      await tester.pumpAndSettle();
      expect(harness.container.read(signupConsentsProvider).has(DocumentKind.sensitiveData), isTrue);

      // Back from the next step, and untick.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await _tick(tester, 'consent-sensitive-data');
      expect(harness.container.read(signupConsentsProvider).has(DocumentKind.sensitiveData), isFalse);
    });
  });

  group('plumbing', () {
    test('a home city maps to its id like the backend does, else none', () {
      final list = [for (final c in cities) DatingCity.fromJson(c)];
      expect(cityIdForName(' london ', list), londonId);
      expect(cityIdForName('Paris', list), isNull);
      expect(cityIdForName(null, list), isNull);
    });

    test('a consent with no document in effect isn\'t sent', () {
      const consents = SignupConsents({
        DocumentKind.terms: 'uk-3',
        DocumentKind.safetyNotice: null,
      });
      expect(consents.has(DocumentKind.safetyNotice), isTrue);
      expect(consents.toRequest(), const [SignupConsent(kind: DocumentKind.terms, version: 'uk-3')]);
    });

    test('the first missing kind in sign-up order picks the step', () {
      expect(LegalRoutes.stepFor([DocumentKind.sensitiveData]), LegalRoutes.sensitiveData);
      expect(LegalRoutes.stepFor([DocumentKind.sensitiveData, DocumentKind.terms]),
          LegalRoutes.terms);
      expect(LegalRoutes.stepFor([DocumentKind.datingBillOfRights]), LegalRoutes.terms);
      expect(LegalRoutes.stepFor([DocumentKind.locationPin]), isNull);
    });
  });
}
