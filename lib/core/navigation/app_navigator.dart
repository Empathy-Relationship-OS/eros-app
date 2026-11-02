import 'package:flutter/widgets.dart';

/// Navigator key attached to `MaterialApp.navigatorKey` in every build.
///
/// Code that runs outside the widget tree, or in widgets overlaid through `MaterialApp.builder`
/// (the push banner, the devtools DEV button and "time shifted" banner), sits above the app's
/// [Navigator] and cannot use `Navigator.of(context)`. It navigates through this key: a
/// notification tap (RFC-006 §6.4) and the dev menu both do.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'appNavigator');

/// Route name of the signed-in home screen.
const String homeRoute = '/match';

/// Attached to `MaterialApp.navigatorObservers`. Tracks whether [homeRoute] is in the stack, so a
/// notification tap that arrives while the app is still deciding where to go (cold start) waits
/// until the user has reached home instead of being replaced by the auth screen's
/// `pushReplacementNamed`.
final HomeRouteObserver appRouteObserver = HomeRouteObserver();

/// Counts [homeRoute] routes in the navigator's stack. [isHomeInStack] is true while there is one.
class HomeRouteObserver extends NavigatorObserver {
  int _homeRoutes = 0;

  /// True while [homeRoute] is somewhere in the stack.
  final ValueNotifier<bool> isHomeInStack = ValueNotifier<bool>(false);

  static bool _isHome(Route<dynamic>? route) => route?.settings.name == homeRoute;

  void _adjust(int delta) {
    _homeRoutes = (_homeRoutes + delta).clamp(0, 1 << 30);
    isHomeInStack.value = _homeRoutes > 0;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isHome(route)) _adjust(1);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isHome(route)) _adjust(-1);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isHome(route)) _adjust(-1);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (_isHome(oldRoute)) _adjust(-1);
    if (_isHome(newRoute)) _adjust(1);
  }
}

/// [navigator]'s top route, or null if it has none.
///
/// [NavigatorState] has no public accessor for its history. `popUntil` with a predicate that is
/// true for the first route it sees reads the top route without popping anything.
Route<dynamic>? topRoute(NavigatorState navigator) {
  Route<dynamic>? top;
  navigator.popUntil((route) {
    top = route;
    return true;
  });
  return top;
}
