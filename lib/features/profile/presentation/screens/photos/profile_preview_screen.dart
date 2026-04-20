import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/features/profile/domain/models/public_profile.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';

/// Screen to preview what the user's profile will look like to others
/// Based on screenshots/users/create-profile/6F692A85-9439-4D16-BC71-1FC49E6EB3D1_1_105_c.jpeg
/// Line 656-658 in Screenshot_Catalogue.md
class ProfilePreviewScreen extends ConsumerStatefulWidget {
  const ProfilePreviewScreen({super.key});

  @override
  ConsumerState<ProfilePreviewScreen> createState() => _ProfilePreviewScreenState();
}

class _ProfilePreviewScreenState extends ConsumerState<ProfilePreviewScreen> {
  bool _consentChecked = false;
  late final Future<PublicProfileDTO> _profileFuture;

  @override
  void initState() {
    super.initState();
    // Fetch profile once during initialization
    final authService = ref.read(authServiceProvider);
    try {
      final userId = authService.getUserId();
      _profileFuture = ref.read(profileRepositoryProvider).getPublicProfile(userId);
    } catch (e) {
      _profileFuture = Future.error(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Preview your profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: FutureBuilder<PublicProfileDTO>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (profileSnapshot.hasError) {
            final errorMessage = profileSnapshot.error.toString().contains('sign in')
                ? 'Please sign in to preview your profile'
                : 'Unable to load profile preview';

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profileSnapshot.error.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!profileSnapshot.hasData) {
            return const Center(
              child: Text('No profile data available'),
            );
          }

          final profile = profileSnapshot.data!;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _ProfilePreviewContent(profile: profile),
                ),
              ),
              _ConsentBottomBar(
                consentChecked: _consentChecked,
                onConsentChanged: (value) {
                  setState(() {
                    _consentChecked = value;
                  });
                },
                onContinue: _handleContinue,
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleContinue() {
    // Navigate to loading/completion screen
    // This will handle photo upload + profile creation if needed
    Navigator.of(context).pushNamed('/profile/complete-loading');
  }
}

/// Content widget showing the profile preview
class _ProfilePreviewContent extends StatelessWidget {
  final PublicProfileDTO profile;

  const _ProfilePreviewContent({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo gallery
        _PhotoGallery(photos: profile.profile.photos),

        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name, Age, Height
              Text(
                '${profile.name}, ${profile.age}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Location & Height
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    profile.city,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.height, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${profile.height} cm',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Bio (if available)
              if (profile.profile.bio != null && profile.profile.bio!.isNotEmpty) ...[
                Text(
                  profile.profile.bio!,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Traits/Personality
              if (profile.profile.traits.isNotEmpty) ...[
                _SectionHeader('Personality'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.profile.traits.map((trait) {
                    return _Chip(label: trait);
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Hobbies/Interests
              if (profile.profile.hobbies.isNotEmpty) ...[
                _SectionHeader('Interests'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.profile.hobbies.map((hobby) {
                    return _Chip(label: hobby);
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Relationship Goals
              _SectionHeader('Looking for'),
              const SizedBox(height: 12),
              if (profile.profile.relationshipGoals.intention != null)
                _InfoRow(
                  icon: Icons.favorite_outline,
                  label: profile.profile.relationshipGoals.intention!,
                ),
              if (profile.profile.relationshipGoals.relationshipType != null)
                _InfoRow(
                  icon: Icons.people_outline,
                  label: profile.profile.relationshipGoals.relationshipType!,
                ),
              if (profile.profile.relationshipGoals.kidsPreference != null)
                _InfoRow(
                  icon: Icons.child_care,
                  label: profile.profile.relationshipGoals.kidsPreference!,
                ),

              const SizedBox(height: 24),

              // Lifestyle/Habits
              if (profile.profile.habits.alcoholConsumption != null ||
                  profile.profile.habits.smokingStatus != null ||
                  profile.profile.habits.diet != null) ...[
                _SectionHeader('Lifestyle'),
                const SizedBox(height: 12),
                if (profile.profile.habits.alcoholConsumption != null)
                  _InfoRow(
                    icon: Icons.local_bar,
                    label: 'Alcohol: ${profile.profile.habits.alcoholConsumption}',
                  ),
                if (profile.profile.habits.smokingStatus != null)
                  _InfoRow(
                    icon: Icons.smoking_rooms,
                    label: 'Smoking: ${profile.profile.habits.smokingStatus}',
                  ),
                if (profile.profile.habits.diet != null)
                  _InfoRow(
                    icon: Icons.restaurant,
                    label: 'Diet: ${profile.profile.habits.diet}',
                  ),
                const SizedBox(height: 24),
              ],

              // Education & Occupation
              _SectionHeader('About'),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.school,
                label: profile.education,
              ),
              if (profile.occupation != null)
                _InfoRow(
                  icon: Icons.work,
                  label: profile.occupation!,
                ),
              _InfoRow(
                icon: Icons.language,
                label: profile.language,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

/// Photo gallery widget
class _PhotoGallery extends StatefulWidget {
  final List<String> photos;

  const _PhotoGallery({required this.photos});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SizedBox(height: 400);
    }

    return SizedBox(
      height: 500,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                widget.photos[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.cardBackground,
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.cardBackground,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
              );
            },
          ),
          // Page indicators
          if (widget.photos.length > 1)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consent checkbox and continue button at bottom
class _ConsentBottomBar extends StatelessWidget {
  final bool consentChecked;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onContinue;

  const _ConsentBottomBar({
    required this.consentChecked,
    required this.onConsentChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Consent checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: consentChecked,
                  onChanged: (value) => onConsentChanged(value ?? false),
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onConsentChanged(!consentChecked),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            height: 1.5,
                          ),
                          children: [
                            const TextSpan(
                              text: 'I agree that my profile, including ',
                            ),
                            TextSpan(
                              text: 'sensitive details',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(
                              text: ', will be published on the app and used for matching.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Continue button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: consentChecked ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.textSecondary.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
