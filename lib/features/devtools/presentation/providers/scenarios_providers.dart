import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';

/// `GET /dev/scenarios` for the Scenarios tab, in the order the backend
/// returns them (pipeline order). The app never hard-codes scenario names.
final devtoolsScenariosProvider =
    FutureProvider.autoDispose<List<ScenarioInfo>>((ref) {
      return ref.watch(devtoolsApiProvider).listScenarios();
    });

/// What the last scenario run produced: a [result], or the backend's
/// [error] message (which names the step that failed).
class ScenarioRunOutcome {
  /// Name of the scenario that was run.
  final String scenario;
  final ScenarioResult? result;
  final String? error;

  ScenarioRunOutcome.success(ScenarioResult this.result)
    : scenario = result.scenario,
      error = null;

  const ScenarioRunOutcome.failure(this.scenario, String this.error)
    : result = null;

  bool get isSuccess => result != null;
}

/// The last scenario run, kept in memory (not `autoDispose`) so closing and
/// reopening the dev menu, or switching persona, still shows it. Cleared by
/// "Reset all dev data".
final lastScenarioRunProvider = StateProvider<ScenarioRunOutcome?>(
  (ref) => null,
);

/// Name of the scenario running now, or null. Kept outside the tab so a run
/// started before the dev menu was closed still shows as running, and a
/// second run cannot start meanwhile.
final runningScenarioProvider = StateProvider<String?>((ref) => null);
