import 'package:eros_app/core/network/exceptions/api_exception.dart';

/// `GET /dev/health` returned 404: the backend is reachable but was started
/// without `DEVTOOLS_ENABLED=true`, so no `/dev` routes exist.
///
/// It is a [NotFoundException], so code that already handles the app's
/// [ApiException] types keeps working.
class DevtoolsDisabledException extends NotFoundException {
  const DevtoolsDisabledException({
    String message =
        'Backend has devtools turned off. Start it with DEVTOOLS_ENABLED=true.',
    super.originalError,
    super.stackTrace,
  }) : super(message);

  @override
  String toString() => 'DevtoolsDisabledException: $message';
}

/// The app was built with `DEVTOOLS=true` but without `DEVTOOLS_KEY`, so
/// every `/dev` request would be rejected with 401. Thrown before any request
/// is sent.
class DevtoolsKeyMissingException extends UnauthorizedException {
  const DevtoolsKeyMissingException()
      : super(
          'DEVTOOLS_KEY not set. Rebuild with '
          '--dart-define=DEVTOOLS_KEY=<same as backend>.',
          statusCode: null,
        );

  @override
  String toString() => 'DevtoolsKeyMissingException: $message';
}
