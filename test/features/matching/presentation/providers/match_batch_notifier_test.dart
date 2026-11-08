import 'dart:async';

import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/features/matching/data/repositories/match_repository.dart';
import 'package:eros_app/features/matching/data/services/match_storage_service.dart';
import 'package:eros_app/features/matching/domain/models/match_models.dart';
import 'package:eros_app/features/matching/presentation/providers/match_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds each `GET /match/` until the test answers it, so answers can land out of order.
class _HeldMatchRepository implements MatchRepository {
  final held = <Completer<DailyBatchResponse?>>[];

  @override
  Future<DailyBatchResponse?> fetchDailyBatch() {
    final answer = Completer<DailyBatchResponse?>();
    held.add(answer);
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MatchBatchNotifier.fetchDailyBatch', () {
    test('an error that lands after an older 204 isn\'t hidden as an empty batch', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = MatchStorageService(await SharedPreferences.getInstance());
      final matches = _HeldMatchRepository();
      final notifier = MatchBatchNotifier(matches, storage);
      addTearDown(notifier.dispose);

      final older = notifier.fetchDailyBatch();
      final newer = notifier.fetchDailyBatch();
      matches.held.first.complete(null);
      await older;
      expect(notifier.state.isBatchEmpty, isTrue);

      matches.held.last.completeError(const ServerException('Something went wrong'));
      await newer;

      expect(notifier.state.isBatchEmpty, isFalse);
      expect(notifier.state.errorMessage, 'Something went wrong');
    });
  });
}
