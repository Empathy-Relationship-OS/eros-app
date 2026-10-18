/// Compile-time switch for every piece of developer tooling in the app.
///
/// Dev tooling (persona switcher, time travel, scenarios) must never ship in
/// a beta or store build (RFC-003 §6). Everything in `features/devtools` is
/// reached only through code guarded by `if (DevtoolsConfig.enabled)`.
/// Because [DevtoolsConfig.enabled] is a `const` built from `--dart-define`
/// values, the compiler folds the guard to `if (false)` in any other build and
/// tree-shakes the dev menu, its routes and its HTTP client out of the binary.
///
/// Never replace this with a runtime setting, a remote flag or a hidden
/// gesture.
///
/// Enable it with:
/// ```bash
/// flutter run --dart-define=ENV=local --dart-define=DEVTOOLS=true \
///   --dart-define=DEVTOOLS_KEY=<same as backend>
/// ```
library;

/// Environments in which dev tooling may be compiled in.
const Set<String> devtoolsAllowedEnvironments = {'local', 'develop'};

/// The gating rule, as a pure function so it can be unit tested.
///
/// Dev tooling is on only when the `DEVTOOLS` flag is set *and* the build
/// targets a local or develop backend.
bool isEnabled(bool flag, String env) =>
    flag && devtoolsAllowedEnvironments.contains(env);

class DevtoolsConfig {
  DevtoolsConfig._();

  static const bool _flag = bool.fromEnvironment('DEVTOOLS');
  static const String _env =
      String.fromEnvironment('ENV', defaultValue: 'local');

  /// True only for `ENV=local` or `ENV=develop` builds with `DEVTOOLS=true`.
  ///
  /// This must stay a `const` expression (it mirrors [isEnabled]) so that the
  /// compiler can strip dev tooling from every other build.
  static const bool enabled = _flag && (_env == 'local' || _env == 'develop');

  /// Shared secret sent as `X-Dev-Key`. Must match the backend's
  /// `DEVTOOLS_KEY`. Empty when not passed with `--dart-define`.
  static const String key = String.fromEnvironment('DEVTOOLS_KEY');
}
