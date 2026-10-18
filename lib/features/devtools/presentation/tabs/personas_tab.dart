import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';
import '../../data/persona_session_service.dart';
import '../providers/devtools_providers.dart';
import '../providers/personas_providers.dart';

/// Route that shows `AuthLoadingScreen` (`MaterialApp.home`). After a
/// persona switch the app restarts from here, so the normal "profile exists
/// -> /match" routing decides where to land.
const String authLoadingRoute = '/';

/// Message shown when `DELETE /dev/personas/{uid}` returns 404 (DT-B5 not
/// on this backend yet).
const String deleteUnavailableMessage = 'Delete not available on this backend';

/// Persona handles: the uid becomes `dev_<handle>` (RFC-003 §5.3).
final RegExp personaHandlePattern = RegExp(r'^[a-z0-9_]{2,32}$');

/// Validator for the create persona form's handle field.
String? validatePersonaHandle(String? value) {
  final handle = value?.trim() ?? '';
  if (handle.isEmpty) return 'Handle is required';
  if (!personaHandlePattern.hasMatch(handle)) {
    return 'Use 2 to 32 of a-z, 0-9 and _';
  }
  return null;
}

/// Backend `Gender` enum names offered by the create form.
const List<String> personaGenders = ['FEMALE', 'MALE', 'NON_BINARY', 'OTHER'];

/// Backend `Role` enum names offered by the create form.
const List<String> personaRoles = ['USER', 'ADMIN', 'EMPLOYEE'];

/// Personas tab of the dev menu (DT-F3): "Log in as..." test users.
///
/// - who is signed in now
/// - create the standard cast, or a single persona
/// - recently used personas
/// - every persona, with "Log in as" and delete
///
/// Logging in goes through [PersonaSessionService], then restarts the app at
/// [authLoadingRoute].
class PersonasTab extends ConsumerStatefulWidget {
  const PersonasTab({super.key});

  @override
  ConsumerState<PersonasTab> createState() => _PersonasTabState();
}

class _PersonasTabState extends ConsumerState<PersonasTab> {
  /// Persona being signed into. While set, every "Log in as" is disabled.
  String? _signingInUid;
  bool _creatingStandard = false;
  bool _creatingPersona = false;
  final Set<String> _deleting = {};

  bool get _signingIn => _signingInUid != null;

  DevtoolsApi get _api => ref.read(devtoolsApiProvider);

  // ====================
  // ACTIONS
  // ====================

  Future<void> _refresh() async {
    ref.invalidate(devtoolsPersonasProvider);
    ref.invalidate(recentPersonaUidsProvider);
    try {
      await ref.read(devtoolsPersonasProvider.future);
    } catch (_) {
      // Shown by the list's error state.
    }
  }

  Future<void> _signInAs(String uid) async {
    if (_signingIn) return;
    final navigator = Navigator.of(context);
    setState(() => _signingInUid = uid);

    try {
      await ref.read(personaSessionServiceProvider).signInAs(uid);
    } catch (e) {
      if (!mounted) return;
      setState(() => _signingInUid = null);
      _showError(e);
      return;
    }

    // The dev menu and every screen under it belonged to the previous user.
    navigator.pushNamedAndRemoveUntil(authLoadingRoute, (_) => false);
  }

  Future<void> _createStandardCast() async {
    setState(() => _creatingStandard = true);
    try {
      final personas = await _api.createStandardPersonas();
      ref.invalidate(devtoolsPersonasProvider);
      _showMessage('Standard cast ready: ${personas.length} personas');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _creatingStandard = false);
    }
  }

  Future<void> _createPersona() async {
    final request = await showDialog<CreatePersonaRequest>(
      context: context,
      builder: (_) => const CreatePersonaDialog(),
    );
    if (request == null || !mounted) return;

    setState(() => _creatingPersona = true);
    try {
      final persona = await _api.createPersona(request);
      ref.invalidate(devtoolsPersonasProvider);
      _showMessage('Persona ready: ${persona.uid}');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _creatingPersona = false);
    }
  }

  Future<void> _deletePersona(Persona persona) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${persona.uid}?'),
        content: const Text(
          'Deletes the persona, its Firebase user and all of its data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting.add(persona.uid));
    try {
      await _api.deletePersona(persona.uid);
      await ref.read(recentPersonasStoreProvider).remove(persona.uid);
      ref.invalidate(devtoolsPersonasProvider);
      ref.invalidate(recentPersonaUidsProvider);
      _showMessage('Deleted ${persona.uid}');
    } on NotFoundException {
      _showMessage(deleteUnavailableMessage);
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _deleting.remove(persona.uid));
    }
  }

  // ====================
  // FEEDBACK
  // ====================

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) => _showMessage(describePersonaError(error));

  // ====================
  // UI
  // ====================

  @override
  Widget build(BuildContext context) {
    final signedInUid = ref.watch(devtoolsSignedInUidProvider);
    final recent = ref.watch(recentPersonaUidsProvider);
    final personas = ref.watch(devtoolsPersonasProvider);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SignedInAs(uid: signedInUid),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _creatingStandard ? null : _createStandardCast,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                ),
                icon: _creatingStandard
                    ? const _SmallSpinner(color: Colors.white)
                    : const Icon(Icons.groups_outlined),
                label: const Text('Create standard cast'),
              ),
              OutlinedButton.icon(
                onPressed: _creatingPersona ? null : _createPersona,
                icon: _creatingPersona
                    ? const _SmallSpinner()
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create persona'),
              ),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const _SectionTitle('Recent'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final uid in recent)
                  ActionChip(
                    key: ValueKey('recentPersona-$uid'),
                    avatar: _signingInUid == uid
                        ? const _SmallSpinner()
                        : const Icon(Icons.login, size: 16),
                    label: Text(uid),
                    onPressed: _signingIn ? null : () => _signInAs(uid),
                  ),
              ],
            ),
          ],
          const _SectionTitle('Personas'),
          personas.when(
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
                      'No personas yet. Create the standard cast to get '
                      'dev_alice, dev_bob, dev_cara, dev_dan and dev_ops.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : Column(
                    children: [
                      for (final persona in list)
                        _PersonaRow(
                          persona: persona,
                          isSignedIn: persona.uid == signedInUid,
                          isSigningIn: _signingInUid == persona.uid,
                          isDeleting: _deleting.contains(persona.uid),
                          canSignIn: !_signingIn,
                          onSignIn: () => _signInAs(persona.uid),
                          onDelete: () => _deletePersona(persona),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// A snackbar message for anything the persona actions can throw. Backend
/// errors carry the backend's `message`.
String describePersonaError(Object error) {
  if (error is PersonaSwitchException) {
    return error.signedOut
        ? '${error.message}. You are now signed out.'
        : error.message;
  }
  if (error is ApiException) return error.message;
  return error.toString();
}

class _SignedInAs extends StatelessWidget {
  final String? uid;

  const _SignedInAs({required this.uid});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isPersona = uid?.startsWith('dev_') ?? false;

    return Row(
      children: [
        Expanded(
          child: Text(
            uid == null
                ? 'Currently signed out'
                : 'Currently signed in as $uid',
            key: const Key('personasSignedInAs'),
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (isPersona)
          const Chip(
            label: Text('dev persona'),
            visualDensity: VisualDensity.compact,
            backgroundColor: AppColors.secondaryOrange,
          ),
      ],
    );
  }
}

class _PersonaRow extends StatelessWidget {
  final Persona persona;
  final bool isSignedIn;
  final bool isSigningIn;
  final bool isDeleting;
  final bool canSignIn;
  final VoidCallback onSignIn;
  final VoidCallback onDelete;

  const _PersonaRow({
    required this.persona,
    required this.isSignedIn,
    required this.isSigningIn,
    required this.isDeleting,
    required this.canSignIn,
    required this.onSignIn,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = persona.firstName.isEmpty ? persona.uid : persona.firstName;

    return ListTile(
      key: ValueKey('persona-${persona.uid}'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: persona.isAdmin
            ? AppColors.textPrimary
            : AppColors.primaryOrange,
        foregroundColor: Colors.white,
        child: Text(name.characters.first.toUpperCase()),
      ),
      title: Text(isSignedIn ? '$name (signed in)' : name),
      subtitle: Text(
        '${persona.uid} | ${persona.role} | ${persona.tokenBalance} tokens',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSigningIn)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _SmallSpinner(),
            )
          else
            TextButton(
              onPressed: canSignIn && !isDeleting ? onSignIn : null,
              child: const Text('Log in as'),
            ),
          IconButton(
            tooltip: 'Delete ${persona.uid}',
            icon: isDeleting
                ? const _SmallSpinner()
                : const Icon(Icons.delete_outline),
            onPressed: isDeleting || isSigningIn ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

/// Form for `POST /dev/personas`. Pops a [CreatePersonaRequest], or null if
/// cancelled.
class CreatePersonaDialog extends StatefulWidget {
  const CreatePersonaDialog({super.key});

  @override
  State<CreatePersonaDialog> createState() => _CreatePersonaDialogState();
}

class _CreatePersonaDialogState extends State<CreatePersonaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _handle = TextEditingController();
  final _tokens = TextEditingController();

  /// Null means "backend default".
  String? _gender;
  String _role = personaRoles.first;

  @override
  void dispose() {
    _handle.dispose();
    _tokens.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final tokens = _tokens.text.trim();
    Navigator.of(context).pop(
      CreatePersonaRequest(
        handle: _handle.text.trim(),
        gender: _gender,
        role: _role,
        tokens: tokens.isEmpty ? null : int.parse(tokens),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create persona'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('createPersonaHandle'),
                controller: _handle,
                autofocus: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Handle',
                  prefixText: 'dev_',
                  helperText: 'a-z, 0-9 and _, 2 to 32 characters',
                ),
                validator: validatePersonaHandle,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: const Key('createPersonaGender'),
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Backend default'),
                  ),
                  for (final g in personaGenders)
                    DropdownMenuItem<String?>(value: g, child: Text(g)),
                ],
                onChanged: (g) => setState(() => _gender = g),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('createPersonaRole'),
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in personaRoles)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (r) => setState(() => _role = r ?? _role),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('createPersonaTokens'),
                controller: _tokens,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Tokens',
                  hintText: 'Backend default',
                ),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  return int.tryParse(text) == null ? 'Whole number' : null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
          ),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 4),
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
            'Could not load personas: $message',
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
