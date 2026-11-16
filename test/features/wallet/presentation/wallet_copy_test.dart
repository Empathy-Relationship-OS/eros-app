import 'package:eros_app/features/wallet/domain/models/wallet_models.dart';
import 'package:eros_app/features/wallet/presentation/screens/wallet_info_screen.dart';
import 'package:eros_app/features/wallet/presentation/widgets/wallet_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('package savings', () {
    test('a single token saves nothing, and each bigger package saves more', () {
      expect(TokenPackageType.starter.savingPercent, 0);
      expect(TokenPackageType.popular.savingPercent, 5);
      expect(TokenPackageType.premium.savingPercent, 7);
      expect(TokenPackageType.mega.savingPercent, 36);
    });

    test('the best saving is the biggest package saving', () {
      expect(TokenPackageType.bestSavingPercent, TokenPackageType.mega.savingPercent);
      expect(WalletCopy.packSaving, contains('36%'));
    });
  });

  group('refund wording', () {
    test('every refund line gives the same number of days', () {
      expect(WalletCopy.refundRule, contains('${WalletCopy.refundDays} days'));
      expect(WalletCopy.acceptTerms, contains(WalletCopy.refundRule));
    });

    testWidgets('the token explainer shows the shared rule and the computed saving', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: WalletInfoScreen()));

      expect(find.text(WalletCopy.refundRule), findsOneWidget);
      expect(find.text(WalletCopy.packageRefundRule), findsOneWidget);
      expect(find.text(WalletCopy.packSaving), findsOneWidget);
      expect(find.textContaining('32%'), findsNothing);
      expect(find.textContaining('unless you cancel the date yourself'), findsNothing);
    });
  });
}
