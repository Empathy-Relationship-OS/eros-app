# eros_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Developer tools

Local and develop builds can include a developer menu for manual testing: sign in as test
users ("personas") without registering, move the backend clock forward, and run named
scenarios that put the backend into a known state. The backend side is described in
`eros-backend/docs/RFC-003-dev-tooling.md`.

Run the app with devtools compiled in:

```bash
flutter run --dart-define=ENV=local --dart-define=DEVTOOLS=true --dart-define=DEVTOOLS_KEY=<same as backend>
```

- The backend must be started with `DEVTOOLS_ENABLED=true` and the same `DEVTOOLS_KEY`
  (at least 16 characters). Otherwise the dev menu header shows "Devtools off".
- Open the menu with the draggable **DEV** button shown on every screen (it works while signed
  out), or from **App Settings > Developer tools**.
- Without `DEVTOOLS_KEY` the menu shows "DEVTOOLS_KEY not set" and sends no requests.

Devtools are gated by the compile-time constant `DevtoolsConfig.enabled`
(`lib/features/devtools/devtools_config.dart`), which is true only when `DEVTOOLS=true` and
`ENV` is `local` or `develop`. In every other build (including `ENV=beta` or
`ENV=production` with `DEVTOOLS=true`) the constant is false, so the guarded code is removed
by the compiler: there is no DEV button, no `/dev` route and no dev HTTP client in the binary.
