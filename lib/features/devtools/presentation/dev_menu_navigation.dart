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

/// Navigator key attached to `MaterialApp.navigatorKey` when devtools are
/// enabled.
///
/// Widgets overlaid through `MaterialApp.builder` (the DEV button, and later
/// the "time shifted" banner) sit above the app's [Navigator], so they cannot
/// use `Navigator.of(context)`. They open the dev menu through this key.
final GlobalKey<NavigatorState> devtoolsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'devtoolsNavigator');

/// Opens the dev menu on [tab].
///
/// Pass [context] from any screen inside the app's navigator. Without it,
/// the dev menu is opened through [devtoolsNavigatorKey], which works from
/// overlays placed by `MaterialApp.builder`.
Future<void> openDevMenu({
  DevMenuTab tab = DevMenuTab.personas,
  BuildContext? context,
}) async {
  final navigator = context != null
      ? Navigator.of(context)
      : devtoolsNavigatorKey.currentState;
  if (navigator == null) return;
  await navigator.pushNamed(devMenuRoute, arguments: tab);
}
