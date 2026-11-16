import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/features/dates/data/models/date_models.dart';
import 'package:eros_app/features/dates/presentation/providers/dates_repository_provider.dart';
import 'package:eros_app/features/dates/presentation/widgets/venue_price_and_menu.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';

/// Bottom sheet that displays full venue details
///
/// Shows:
/// - Venue image
/// - Name
/// - Price band and menu link
/// - Address (tappable - opens maps)
/// - Description
/// - Dress code
/// - Website/social links
class VenueDetailSheet extends ConsumerStatefulWidget {
  final String dateId;

  const VenueDetailSheet({
    super.key,
    required this.dateId,
  });

  @override
  ConsumerState<VenueDetailSheet> createState() => _VenueDetailSheetState();

  /// Show the venue detail sheet
  static Future<void> show(BuildContext context, String dateId) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VenueDetailSheet(dateId: dateId),
    );
  }
}

class _VenueDetailSheetState extends ConsumerState<VenueDetailSheet> {
  VenuePublicInfo? _venueInfo;
  bool _isLoading = true;
  String? _error;
  String? _cachedAuthToken;

  @override
  void initState() {
    super.initState();
    _loadVenueDetails();
  }

  Future<void> _loadVenueDetails() async {
    try {
      // Load auth token and venue details in parallel
      final results = await Future.wait([
        ref.read(authServiceProvider).getIdToken(),
        ref.read(datesRepositoryProvider).getVenueDetails(widget.dateId),
      ]);

      if (mounted) {
        setState(() {
          _cachedAuthToken = results[0] as String?;
          _venueInfo = results[1] as VenuePublicInfo;
          _isLoading = false;
        });
      }
    } on ConflictException {
      if (mounted) {
        setState(() {
          _error = 'Venue hasn\'t been assigned yet';
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load venue details';
          _isLoading = false;
        });
      }
    }
  }

  TextTheme get _textTheme => Theme.of(context).textTheme;

  /// An address or web link: deep coral and underlined.
  TextStyle? get _linkStyle => _textTheme.bodyMedium?.copyWith(
        color: AppColors.primaryDeep,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.primaryDeep,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return _buildError();
          }

          if (_venueInfo == null) {
            return const Center(child: Text('No venue information available'));
          }

          return _buildContent(scrollController);
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: _textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ScrollController scrollController) {
    final venue = _venueInfo!;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),

        // Venue image
        if (venue.imageUrl != null)
          _buildVenueImage(venue.imageUrl!)
        else
          _buildPlaceholderImage(),

        // Content
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Venue name
              Text(
                venue.name,
                style: _textTheme.displaySmall,
              ),

              // Price band and menu link
              VenuePriceAndMenu(
                priceRange: venue.priceRange,
                menuUrl: venue.menuUrl,
              ),

              const SizedBox(height: 16),

              // Address (tappable)
              InkWell(
                onTap: () => _openMaps(venue.address),
                borderRadius: BorderRadius.circular(AppRadius.input),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 20,
                        color: AppColors.primaryDeep,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          venue.address,
                          style: _linkStyle,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Description
              Text('About', style: _textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                venue.description,
                style: _textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 24),

              // Dress code
              _buildInfoRow(
                icon: Icons.checkroom_outlined,
                label: 'Dress Code',
                value: venue.dressCode.displayName,
              ),

              // Website/social links
              if (venue.websiteUrl != null) ...[
                const SizedBox(height: 16),
                _buildLinkRow(
                  icon: Icons.language,
                  label: 'Website',
                  url: venue.websiteUrl!,
                ),
              ],

              const SizedBox(height: 32),

              // Open in Maps button
              AppButton(
                label: 'Get Directions',
                icon: Icons.directions,
                onPressed: () => _openMaps(venue.address),
              ),

              // Bottom safe area padding
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVenueImage(String imageUrl) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      child: _cachedAuthToken != null
          ? CachedNetworkImage(
              imageUrl: imageUrl,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholderImage(),
              errorWidget: (context, url, error) => _buildPlaceholderImage(),
              httpHeaders: {
                'Authorization': 'Bearer $_cachedAuthToken',
              },
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 250,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 64,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: _textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: _textTheme.titleSmall,
        ),
      ],
    );
  }

  Widget _buildLinkRow({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return InkWell(
      onTap: () => _openUrl(url),
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.primaryDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: _linkStyle,
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMaps(String address) async {
    final encodedAddress = Uri.encodeComponent(address);
    final url = Uri.parse('https://maps.apple.com/?q=$encodedAddress');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps')),
      );
    }
  }

  Future<void> _openUrl(String urlString) async {
    final url = Uri.parse(urlString);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}
