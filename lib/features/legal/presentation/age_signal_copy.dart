/// Short app copy for the app-store age check (RFC-009 §5.3.1, CF-F6). No em dashes.
///
/// Kept apart from CF-F5's `widgets/legal_copy.dart` so the two branches don't both add the
/// same file; fold it in once both have merged.
abstract final class AgeSignalCopy {
  /// While the store is asked. Apple or Google may show their own sheet over it.
  static const String checking = 'Just a moment';

  /// The screen a minor band, or the backend's 403 `UNDERAGE`, ends on.
  static const String underageTitle = 'You need to be 18 or over to use Muse.';

  static const String underageBody =
      "Muse is only for adults, so we can't create an account for you. We've signed you out "
      "and haven't kept what you entered.";

  static const String underageDone = 'OK';
}
