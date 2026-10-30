import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/widgets/dates_copy.dart';

/// A venue's price band and "See menu" link, shown under its name (RFC-005 §6.4, D-28)
///
/// - The band's symbol is shown as the server sent it, never derived from the device's currency
/// - The server resolves [menuUrl] (menu link, else website, else null); no link when it's null
/// - Takes no space when there is nothing to show
class VenuePriceAndMenu extends StatelessWidget {
  final PriceRange? priceRange;
  final String? menuUrl;

  const VenuePriceAndMenu({
    super.key,
    required this.priceRange,
    required this.menuUrl,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = priceRange?.symbol;
    final url = menuUrl;

    if (symbol == null && url == null) {
      return const SizedBox.shrink();
    }

    // Wrap, because the symbol's length varies by currency and these sit in narrow columns
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (symbol != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              symbol,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        if (url != null)
          TextButton(
            onPressed: () => _openMenu(context, url),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryOrange,
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              DatesCopy.venueSeeMenu,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
      ],
    );
  }

  /// Opens the menu in the external browser. Unlike the maps links, this doesn't ask
  /// canLaunchUrl first: without a `<queries>` entry for https in AndroidManifest.xml, that
  /// returns false on Android 11+ even though the browser would open.
  Future<void> _openMenu(BuildContext context, String menuUrl) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = Uri.tryParse(menuUrl);

    var opened = false;
    if (url != null) {
      try {
        opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      } on PlatformException {
        opened = false;
      }
    }

    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(content: Text(DatesCopy.venueMenuOpenFailed)),
      );
    }
  }
}
