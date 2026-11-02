import 'package:eros_app/core/navigation/app_navigator.dart';
import 'package:flutter/material.dart';

/// A tiny app with the routes a push opens. Each page shows its route name and date id.
class NotificationTestApp extends StatelessWidget {
  const NotificationTestApp({
    super.key,
    required this.navigatorKey,
    required this.observer,
    this.initialRoute = homeRoute,
    this.builder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final HomeRouteObserver observer;
  final String initialRoute;
  final TransitionBuilder? builder;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [observer],
      initialRoute: initialRoute,
      builder: builder,
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => Scaffold(
          body: Center(child: Text('${settings.name} ${settings.arguments ?? ''}'.trim())),
        ),
      ),
    );
  }
}
