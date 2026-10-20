import 'dart:async';

import 'package:flutter/widgets.dart';
import 'dev_menu_navigation.dart';
import 'tabs/personas_tab.dart' show authLoadingRoute;

/// Route `AuthLoadingScreen` sends a signed-in user with a profile to
/// (`HomeScreen`, whose first tab is the match screen).
const String matchRoute = '/match';

/// `DateDetailScreen`, built by `onGenerateRoute` in `main.dart`. Its
/// argument is the date id as a **String** (`settings.arguments as String`).
const String dateDetailRoute = '/dates/detail';

/// How long to wait for `AuthLoadingScreen` to route after a persona switch
/// before giving up on opening the date. It checks `/users/exists` first,
/// so this covers a slow backend.
const Duration authRoutingTimeout = Duration(seconds: 30);

/// Where the app ended up after [restartAndOpen].
class PersonaLanding {
  /// Top route once `AuthLoadingScreen` had routed. Null if it timed out,
  /// or if the top route is unnamed.
  final String? routeName;

  /// True when the date detail screen was pushed.
  final bool openedDate;

  /// True when `AuthLoadingScreen` had not routed within the timeout (or the
  /// navigator went away).
  final bool timedOut;

  const PersonaLanding({
    required this.routeName,
    required this.openedDate,
    this.timedOut = false,
  });

  static const PersonaLanding notRouted = PersonaLanding(
    routeName: null,
    openedDate: false,
    timedOut: true,
  );

  bool get onMatchScreen => routeName == matchRoute;
}

/// Restarts the app at `AuthLoadingScreen` after a persona switch, waits for
/// it to finish routing, then opens date [dateId] on top of the match
/// screen. Without a [dateId] (scenarios that end at a match) the match
/// screen is the destination, so nothing more is pushed.
///
/// **How the wait works.** `AuthLoadingScreen` leaves `/` with
/// `pushReplacementNamed`, and replacing a route completes the future that
/// pushing it returned. So awaiting our own push of [authLoadingRoute]
/// resolves exactly when the auth routing has happened, with no polling and
/// no fixed delay. The future also completes if something else removes the
/// route (another persona switch, for example), which is why the top route
/// is checked afterwards: the date is only opened when the app landed on
/// [matchRoute]. If the persona has no profile (`/profile-creation/...`),
/// the auth check failed (error screen, never routes) or [timeout] passes,
/// nothing is pushed and the returned [PersonaLanding] says why.
///
/// Call this with the app's [NavigatorState] captured **before** the switch:
/// the dev menu that called it is removed by the restart.
Future<PersonaLanding> restartAndOpen(
  NavigatorState navigator, {
  int? dateId,
  Duration timeout = authRoutingTimeout,
}) async {
  final authRouted = navigator.pushNamedAndRemoveUntil<Object?>(
    authLoadingRoute,
    (_) => false,
  );

  try {
    await authRouted.timeout(timeout);
  } on TimeoutException {
    return PersonaLanding.notRouted;
  }

  if (!navigator.mounted) return PersonaLanding.notRouted;

  final landed = topRouteName(navigator);
  if (landed != matchRoute || dateId == null) {
    return PersonaLanding(routeName: landed, openedDate: false);
  }

  unawaited(navigator.pushNamed(dateDetailRoute, arguments: '$dateId'));
  return const PersonaLanding(routeName: matchRoute, openedDate: true);
}

/// Snackbar text when [restartAndOpen] did not reach its destination, or
/// null when it did.
String? describeLandingProblem(
  PersonaLanding landing, {
  required String uid,
  required int? dateId,
}) {
  final what = dateId == null ? 'the match screen' : 'date $dateId';
  if (landing.timedOut) {
    return 'Signed in as $uid, but the app was still loading after '
        '${authRoutingTimeout.inSeconds}s, so $what was not opened.';
  }
  if (!landing.onMatchScreen) {
    return 'Signed in as $uid, but the app went to ${landing.routeName} '
        'instead of $matchRoute, so $what was not opened.';
  }
  return null;
}
