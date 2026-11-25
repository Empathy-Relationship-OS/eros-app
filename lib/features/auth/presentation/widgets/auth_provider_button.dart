import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';

/// One way in on the method screen ("Continue with Google", "Continue with Email"). Every option
/// is the same height as [AppButton] (RFC-011 primer rule 15). The theme's outlined button with a
/// white fill: Google's branding asks for its light button to be white whatever the page colour,
/// and the email option matches it.
class AuthProviderButton extends StatelessWidget {
  /// The provider's mark or an icon, before the label.
  final Widget leading;
  final String label;

  /// Null turns the button off.
  final VoidCallback? onPressed;

  /// Shows a spinner in place of the label and turns the button off.
  final bool loading;

  const AuthProviderButton({
    super.key,
    required this.leading,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  /// Google's standard "G" mark, from Google's own sign-in button.
  static Widget googleMark() => SvgPicture.asset(
        'assets/images/google_g_logo.svg',
        width: 20,
        height: 20,
        excludeFromSemantics: true,
      );

  static const _style = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(AppButton.minHeight)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
    backgroundColor: WidgetStatePropertyAll(AppColors.cardBackground),
  );

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: _style,
      child: loading
          ? Semantics(
              label: '$label, signing in',
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary),
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: 20, height: 20, child: Center(child: leading)),
                  const SizedBox(width: 12),
                  Text(label, maxLines: 1),
                ],
              ),
            ),
    );
  }
}

/// "Continue with Apple" in Apple's own black style (`SignInWithAppleButton`, RFC-011 primer
/// rule 15), the same height and corners as [AuthProviderButton]. iOS only: the screen shows it
/// only where `appleSignInSupported()` (D-2).
class AppleProviderButton extends StatelessWidget {
  static const label = 'Continue with Apple';

  /// Null turns the button off (Apple's grey disabled style).
  final VoidCallback? onPressed;

  /// Shows a spinner on Apple's black in place of the label.
  final bool loading;

  const AppleProviderButton({super.key, required this.onPressed, this.loading = false});

  static const _radius = BorderRadius.all(Radius.circular(AppRadius.button));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      // Apple's black and white, as SignInWithAppleButton draws them, not the Muse palette.
      return Semantics(
        label: '$label, signing in',
        child: const SizedBox(
          height: AppButton.minHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.black, borderRadius: _radius),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
              ),
            ),
          ),
        ),
      );
    }
    return SignInWithAppleButton(
      text: label,
      height: AppButton.minHeight,
      borderRadius: _radius,
      onPressed: onPressed,
    );
  }
}
