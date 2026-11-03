import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:flutter/widgets.dart';

/// Tabs of the dev menu, in display order.
enum DevMenuTab {
  personas('Personas'),
  time('Time'),
  scenarios('Scenarios');

  final String label;

  const DevMenuTab(this.label);
}

/// Route name of the dev menu. Registered in `main.dart` only when
/// `DevtoolsConfig.enabled`.
const String devMenuRoute = '/dev';

/// Opens the dev menu on [tab].
///
/// Pass [context] from any screen inside the app's navigator. Without it,
/// the dev menu is opened through [appNavigatorKey], which works from
/// overlays placed by `MaterialApp.builder`.
///
/// If the dev menu is already the top route (for example the "time shifted"
/// banner is tapped while the menu is open), it is replaced rather than
/// stacked, so there is only ever one copy and it shows [tab].
Future<void> openDevMenu({
  DevMenuTab tab = DevMenuTab.personas,
  BuildContext? context,
}) async {
  final navigator = context != null
      ? Navigator.of(context)
      : appNavigatorKey.currentState;
  if (navigator == null) return;
  if (topRouteName(navigator) == devMenuRoute) {
    await navigator.pushReplacementNamed(devMenuRoute, arguments: tab);
    return;
  }
  await navigator.pushNamed(devMenuRoute, arguments: tab);
}

/// Name of [navigator]'s top route, or null for unnamed routes (dialogs,
/// bottom sheets).
///
/// [NavigatorState] has no public accessor for its history. `popUntil` with
/// a predicate that is true for the first route it sees reads the top route
/// without popping anything.
String? topRouteName(NavigatorState navigator) {
  String? name;
  navigator.popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}
