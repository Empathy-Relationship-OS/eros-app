import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:eros_app/core/widgets/app_button.dart';
import 'package:eros_app/core/theme/app_colors.dart';

/// Welcome/Onboarding screen shown after profile is complete
/// Based on Screenshot_Catalogue.md line 659-663
/// Final screen before user enters the main app (Match tab)
class WelcomeOnboardingScreen extends StatelessWidget {
  const WelcomeOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Success icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 70,
                  color: AppColors.primaryDeep,
                ),
              ),

              const SizedBox(height: 40),

              // Welcome message
              Text(
                'You\'re all set!',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Your profile is live and we\'re finding your perfect matches.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Features list
              _FeatureItem(
                icon: Icons.favorite_border,
                title: 'Quality Matches',
                description: 'Receive up to 21 curated matches per day',
              ),
              const SizedBox(height: 24),
              _FeatureItem(
                icon: Icons.schedule,
                title: 'Daily Batches',
                description: 'New matches delivered 3 times daily',
              ),
              const SizedBox(height: 24),
              _FeatureItem(
                icon: Icons.local_cafe,
                title: 'Real Dates',
                description: 'Skip the small talk, meet in person',
              ),

              const Spacer(),

              // Start dating button
              AppButton(label: 'Start dating', onPressed: () => _handleStartDating(context)),

              const SizedBox(height: 16),

              // Helpful tip
              Text(
                'Your first batch will be ready soon!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleStartDating(BuildContext context) {
    // Navigate to main app - Match tab
    // TODO: Replace with actual main app route/navigation
    // For now, we'll use a placeholder route
    // In production, this would likely use Navigator.pushAndRemoveUntil
    // to clear the entire profile creation stack
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/match', // Main app route
      (route) => false, // Remove all previous routes
    );
  }
}

/// Feature item widget
class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(AppRadius.input),
          ),
          child: Icon(
            icon,
            size: 28,
            color: AppColors.primaryDeep,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
