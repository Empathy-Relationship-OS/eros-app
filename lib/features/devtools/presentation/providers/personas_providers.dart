import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/devtools_api.dart';
import '../../data/models/devtools_models.dart';
import '../../data/persona_session_service.dart';

/// `GET /dev/personas` for the Personas tab.
///
/// Invalidate it after anything that creates or deletes personas (the tab
/// does; scenarios should too).
final devtoolsPersonasProvider = FutureProvider.autoDispose<List<Persona>>((
  ref,
) {
  return ref.watch(devtoolsApiProvider).listPersonas();
});

/// uids of the last personas signed in as, most recent first.
///
/// Invalidate it after `PersonaSessionService.signInAs`.
final recentPersonaUidsProvider = Provider.autoDispose<List<String>>((ref) {
  return ref.watch(recentPersonasStoreProvider).read();
});
