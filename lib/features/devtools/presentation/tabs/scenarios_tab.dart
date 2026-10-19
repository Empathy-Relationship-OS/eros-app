import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/widgets/date_status_pill.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';
import '../../data/persona_session_service.dart';
import '../providers/devtools_providers.dart';
import '../providers/personas_providers.dart';
import '../providers/scenarios_providers.dart';
import '../scenario_navigation.dart';
import '../time_travel.dart';
import 'personas_tab.dart' show authLoadingRoute, describePersonaError;

/// Scenarios tab of the dev menu (DT-F5): one tap to a known backend state.
///
/// - the scenarios from `GET /dev/scenarios`, in the order returned
/// - tap one to choose personas and run it (`POST /dev/scenarios/{name}`)
/// - the last result: notes, "Log in as" per persona, and "Log in as A and
///   open date"
/// - "Reset all dev data" (`POST /dev/reset`)
///
/// Scenario names are never hard-coded here; the backend owns the list.
class ScenariosTab extends ConsumerStatefulWidget {
  const ScenariosTab({super.key});

  @override
  ConsumerState<ScenariosTab> createState() => _ScenariosTabState();
}

class _ScenariosTabState extends ConsumerState<ScenariosTab> {
  /// Persona being signed into. While set, every sign-in button is disabled.
  String? _signingInUid;
  bool _resetting = false;

  DevtoolsApi get _api => ref.read(devtoolsApiProvider);

  // ====================
  // ACTIONS
  // ====================

  Future<void> _refresh() async {
    ref.invalidate(devtoolsScenariosProvider);
    try {
      await ref.read(devtoolsScenariosProvider.future);
    } catch (_) {
      // Shown by the list's error state.
    }
  }

  Future<void> _openRunSheet(ScenarioInfo scenario) async {
    final choice = await showModalBottomSheet<ScenarioRunChoice>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ScenarioRunSheet(scenario: scenario),
    );
    if (choice == null || !mounted) return;
    await _run(scenario, choice.handles);
  }

  Future<void> _run(ScenarioInfo scenario, List<String>? handles) async {
    final running = ref.read(runningScenarioProvider.notifier);
    if (running.state != null) return;
    // Captured up front: the run takes seconds and the dev menu may be
    // closed meanwhile. These providers are not autoDispose, so the result
    // still lands where the reopened tab will find it.
    final last = ref.read(lastScenarioRunProvider.notifier);
    final container = ProviderScope.containerOf(context, listen: false);

    running.state = scenario.name;
    try {
      final result = await _api.runScenario(scenario.name, handles: handles);
      last.state = ScenarioRunOutcome.success(result);
    } catch (e) {
      last.state = ScenarioRunOutcome.failure(
        scenario.name,
        describePersonaError(e),
      );
    } finally {
      running.state = null;
    }

    // Even a failed run may have created personas and changed state (no
    // rollback, RFC-003 D-7), and a scenario may have moved the clock. The
    // response itself already updated ServerClock (and so the "time
    // shifted" banner) through ServerTimeInterceptor; this makes open
    // screens and the dev menu header refetch.
    if (mounted) {
      invalidateTimeSensitiveState(ref);
      ref.invalidate(devtoolsPersonasProvider);
    } else {
      for (final provider in [
        ...timeSensitiveProviders,
        devtoolsPersonasProvider,
      ]) {
        container.invalidate(provider);
      }
    }
  }

  /// Signs in as [uid] and restarts the app at `AuthLoadingScreen`, like
  /// the Personas tab. With [openResult], also waits for the auth routing to
  /// finish and opens the result's date (or stays on the match screen when
  /// the scenario ends before a date exists).
  Future<void> _signInAs(String uid, {ScenarioResult? openResult}) async {
    if (_signingInUid != null) return;
    // Captured before the switch: the restart removes the dev menu, and
    // with it this tab's context.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _signingInUid = uid);

    try {
      await ref.read(personaSessionServiceProvider).signInAs(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() => _signingInUid = null);
      _showMessage(describePersonaError(e));
      return;
    }

    if (openResult == null) {
      navigator.pushNamedAndRemoveUntil(authLoadingRoute, (_) => false);
      return;
    }

    final landing = await restartAndOpen(navigator, dateId: openResult.dateId);
    final problem = describeLandingProblem(
      landing,
      uid: uid,
      dateId: openResult.dateId,
    );
    if (problem != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all dev data?'),
        content: const Text(resetConfirmationText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final signedInUid = ref.read(devtoolsSignedInUidProvider);
    setState(() => _resetting = true);

    final ResetResult result;
    try {
      result = await _api.reset();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      _showMessage(describePersonaError(e));
      return;
    }
    if (!mounted) return;

    ref.read(lastScenarioRunProvider.notifier).state = null;
    ref.invalidate(devtoolsPersonasProvider);
    ref.invalidate(recentPersonaUidsProvider);
    invalidateTimeSensitiveState(ref);
    final summary = describeReset(result);

    if (signedInUid == null || !signedInUid.startsWith('dev_')) {
      setState(() => _resetting = false);
      _showMessage(summary);
      return;
    }

    // The signed-in persona has just been deleted.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(personaSessionServiceProvider).signOut();
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      _showMessage('$summary Signing out of $signedInUid failed: $e');
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$summary Signed out of $signedInUid.')),
      );
    navigator.pushNamedAndRemoveUntil(authLoadingRoute, (_) => false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ====================
  // UI
  // ====================

  @override
  Widget build(BuildContext context) {
    final scenarios = ref.watch(devtoolsScenariosProvider);
    final running = ref.watch(runningScenarioProvider);
    final last = ref.watch(lastScenarioRunProvider);
    final busy = running != null || _resetting || _signingInUid != null;

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (running != null) _RunningBanner(scenario: running),
          if (last != null && running == null) ...[
            const _SectionTitle('Last result'),
            if (last.result case final result?)
              _ResultCard(
                result: result,
                signingInUid: _signingInUid,
                enabled: !busy,
                onSignIn: (uid) => _signInAs(uid),
                onSignInAndOpen: () =>
                    _signInAs(result.loginAs, openResult: result),
              )
            else
              _FailureCard(outcome: last),
          ],
          const _SectionTitle('Scenarios'),
          scenarios.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _ListError(
              message: describePersonaError(error),
              onRetry: _refresh,
            ),
            data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'The backend has no scenarios.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      for (final scenario in list)
                        _ScenarioTile(
                          scenario: scenario,
                          isRunning: running == scenario.name,
                          enabled: !busy,
                          onTap: () => _openRunSheet(scenario),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : _reset,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: _resetting
                ? const _SmallSpinner(color: AppColors.error)
                : const Icon(Icons.delete_sweep_outlined),
            label: const Text('Reset all dev data'),
          ),
        ],
      ),
    );
  }
}

/// Body of the "Reset all dev data" confirm dialog.
const String resetConfirmationText =
    'Deletes every dev_ user (including the personas scenarios created) '
    'and all of their data: matches, dates, deposits and their Firebase '
    'users. Resets the clock to real time. Venue fixtures are kept. If you '
    'are signed in as a persona, you will be signed out.';

/// Snackbar text for a `POST /dev/reset` result.
String describeReset(ResetResult result) {
  final skipped = result.skippedDates.isEmpty
      ? ''
      : ' Kept ${result.skippedDates.length} date(s) that include a real '
            'user: ${result.skippedDates.join(', ')}.';
  return 'Reset: deleted ${result.deletedPersonas} personas, '
      '${result.deletedMatches} matches and ${result.deletedDates} dates. '
      'Clock reset.$skipped';
}

/// The dates feature's [DateState] for a backend wire name, or null if it is
/// not a date state (for example a scenario that ends at a match).
DateState? dateStateFromWire(String? wire) {
  if (wire == null) return null;
  for (final state in DateState.values) {
    if (enumToWire(state) == wire) return state;
  }
  return null;
}

/// A scenario's end state: the dates feature's [DateStatusPill], with the
/// tone the dates screens use, for a date state; a plain chip otherwise.
class ScenarioEndState extends StatelessWidget {
  final String state;

  const ScenarioEndState(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final dateState = dateStateFromWire(state);
    if (dateState == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text(state),
          visualDensity: VisualDensity.compact,
          backgroundColor: AppColors.secondaryOrange,
        ),
      );
    }
    final (_, tone) = DatesCopy.statusPill(
      state: dateState,
      partnerName: '',
      tokenCost: '',
      youSubmitted: false,
      youPaid: false,
      youRanked: false,
      youConfirmed: false,
    );
    return DateStatusPill(text: state, tone: tone);
  }
}

class _ScenarioTile extends StatelessWidget {
  final ScenarioInfo scenario;
  final bool isRunning;
  final bool enabled;
  final VoidCallback onTap;

  const _ScenarioTile({
    required this.scenario,
    required this.isRunning,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final endState = scenario.endState;

    return Card(
      key: ValueKey('scenario-${scenario.name}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: AppColors.cardBackground,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scenario.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (isRunning)
                    const _SmallSpinner()
                  else
                    Icon(
                      Icons.play_arrow,
                      color: enabled
                          ? AppColors.primaryOrange
                          : AppColors.textTertiary,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                scenario.description,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (endState != null) ...[
                const SizedBox(height: 8),
                ScenarioEndState(endState),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// What [ScenarioRunSheet] pops: persona handles to reuse (A then B), or
/// null for fresh personas.
class ScenarioRunChoice {
  final List<String>? handles;

  const ScenarioRunChoice(this.handles);
}

/// Bottom sheet for running one scenario, with an optional "use existing
/// personas" picker. Pops a [ScenarioRunChoice], or null if dismissed.
class ScenarioRunSheet extends ConsumerStatefulWidget {
  final ScenarioInfo scenario;

  const ScenarioRunSheet({super.key, required this.scenario});

  @override
  ConsumerState<ScenarioRunSheet> createState() => _ScenarioRunSheetState();
}

class _ScenarioRunSheetState extends ConsumerState<ScenarioRunSheet> {
  /// Persona uids for A and B. Both null means fresh personas.
  String? _a;
  String? _b;

  /// Null when the choice can be run, else why Run is disabled.
  String? get _problem {
    if (_a == null && _b == null) return null;
    if (_a == null || _b == null) return 'Pick both personas, or neither';
    if (_a == _b) return 'Pick two different personas';
    return null;
  }

  /// `dev_alice` -> `alice`: the backend takes handles (RFC-003 §5.5).
  static String _handle(String uid) =>
      uid.startsWith('dev_') ? uid.substring(4) : uid;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final personas = ref.watch(devtoolsPersonasProvider);
    final problem = _problem;
    final a = _a;
    final b = _b;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.scenario.name,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.scenario.description,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Use existing personas (optional)',
              style: textTheme.titleSmall,
            ),
            Text(
              'Leave both empty to create fresh personas.',
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            personas.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text(
                'Could not load personas: ${describePersonaError(error)}',
                style: const TextStyle(color: AppColors.error),
              ),
              data: (list) {
                final users = list.where((p) => !p.isAdmin).toList();
                return Column(
                  children: [
                    _PersonaPicker(
                      key: const Key('scenarioPersonaA'),
                      label: 'Persona A',
                      personas: users,
                      value: a,
                      onChanged: (uid) => setState(() => _a = uid),
                    ),
                    const SizedBox(height: 8),
                    _PersonaPicker(
                      key: const Key('scenarioPersonaB'),
                      label: 'Persona B',
                      personas: users,
                      value: b,
                      onChanged: (uid) => setState(() => _b = uid),
                    ),
                  ],
                );
              },
            ),
            if (problem != null) ...[
              const SizedBox(height: 8),
              Text(problem, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('scenarioRunButton'),
              onPressed: problem != null
                  ? null
                  : () => Navigator.of(context).pop(
                      ScenarioRunChoice(
                        a == null || b == null
                            ? null
                            : [_handle(a), _handle(b)],
                      ),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonaPicker extends StatelessWidget {
  final String label;
  final List<Persona> personas;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _PersonaPicker({
    super.key,
    required this.label,
    required this.personas,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Fresh')),
        for (final p in personas)
          DropdownMenuItem<String?>(
            value: p.uid,
            child: Text('${p.firstName} (${p.uid})'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _RunningBanner extends StatelessWidget {
  final String scenario;

  const _RunningBanner({required this.scenario});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running $scenario...',
            key: const Key('scenarioRunning'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          const Text(
            'Scenarios drive the real services and take a few seconds.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const LinearProgressIndicator(color: AppColors.primaryOrange),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ScenarioResult result;
  final String? signingInUid;
  final bool enabled;
  final ValueChanged<String> onSignIn;
  final VoidCallback onSignInAndOpen;

  const _ResultCard({
    required this.result,
    required this.signingInUid,
    required this.enabled,
    required this.onSignIn,
    required this.onSignInAndOpen,
  });

  String _nameOf(String uid) {
    final ops = result.opsPersona;
    for (final p in [...result.personas, ?ops]) {
      if (p.uid == uid && p.firstName.isNotEmpty) return p.firstName;
    }
    return uid;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ids = [
      if (result.matchId != null) 'Match ${result.matchId}',
      if (result.dateId != null) 'Date ${result.dateId}',
    ].join(' | ');
    final ops = result.opsPersona;
    final dateState = result.dateState;
    final target = result.dateId == null ? 'match' : 'date';

    return Card(
      key: const Key('scenarioResult'),
      margin: EdgeInsets.zero,
      color: AppColors.cardBackground,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.scenario,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
            if (ids.isNotEmpty)
              Text(
                ids,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            if (dateState != null) ...[
              const SizedBox(height: 8),
              ScenarioEndState(dateState),
            ],
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Notes(notes: result.notes),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('scenarioLogInAndOpen'),
              onPressed: enabled ? onSignInAndOpen : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
              ),
              icon: signingInUid == result.loginAs
                  ? const _SmallSpinner(color: Colors.white)
                  : const Icon(Icons.login),
              label: Text(
                'Log in as ${_nameOf(result.loginAs)} and open $target',
              ),
            ),
            const SizedBox(height: 8),
            for (final persona in result.personas)
              _ResultPersonaRow(
                persona: persona,
                isSigningIn: signingInUid == persona.uid,
                enabled: enabled,
                onSignIn: () => onSignIn(persona.uid),
              ),
            if (ops != null)
              _ResultPersonaRow(
                persona: ops,
                isSigningIn: signingInUid == ops.uid,
                enabled: enabled,
                onSignIn: () => onSignIn(ops.uid),
                caption: 'ops',
              ),
          ],
        ),
      ),
    );
  }
}

/// The scenario's notes, verbatim and prominent: they say what to do next.
class _Notes extends StatelessWidget {
  final List<String> notes;

  const _Notes({required this.notes});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500);
    return Container(
      key: const Key('scenarioNotes'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryOrange.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryOrange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: SelectableText(note, style: style),
            ),
        ],
      ),
    );
  }
}

class _ResultPersonaRow extends StatelessWidget {
  final Persona persona;
  final bool isSigningIn;
  final bool enabled;
  final VoidCallback onSignIn;
  final String? caption;

  const _ResultPersonaRow({
    required this.persona,
    required this.isSigningIn,
    required this.enabled,
    required this.onSignIn,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final name = persona.firstName.isEmpty ? persona.uid : persona.firstName;
    return ListTile(
      key: ValueKey('scenarioPersona-${persona.uid}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(caption == null ? name : '$name ($caption)'),
      subtitle: Text('${persona.uid} | ${persona.role}'),
      trailing: isSigningIn
          ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SmallSpinner(),
            )
          : TextButton(
              onPressed: enabled ? onSignIn : null,
              child: const Text('Log in as'),
            ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  final ScenarioRunOutcome outcome;

  const _FailureCard({required this.outcome});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('scenarioFailure'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${outcome.scenario} failed',
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(outcome.error ?? '', style: textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Scenarios do not roll back: whatever ran before the failed step '
            'is still there.',
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ListError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load scenarios: $message',
            style: const TextStyle(color: AppColors.error),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _SmallSpinner extends StatelessWidget {
  final Color? color;

  const _SmallSpinner({this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
