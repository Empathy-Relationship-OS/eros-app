import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'phone_number_screen.dart';
import 'email_entry_screen.dart';

/// Auth Method Selection Screen
/// Allows user to choose between phone or email authentication
/// Reference: screenshots/login/create-user/C66338AB-087A-4FD1-8A50-1B183B02E8A5_1_105_c.jpeg
class AuthMethodSelectionScreen extends StatelessWidget {
  const AuthMethodSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Title
              Text(
                'How would you like to\nsign up?',
                style: Theme.of(context).textTheme.displayMedium,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Choose your preferred method to get started',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: 48),

              // Phone Number Option - Hidden for now
              // TODO: Re-enable when phone auth backend is ready
              // _AuthMethodCard(
              //   icon: Icons.phone_outlined,
              //   title: 'Continue with Phone',
              //   description: 'We\'ll send you a verification code via SMS',
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const PhoneNumberScreen(),
              //       ),
              //     );
              //   },
              // ),
              //
              // const SizedBox(height: 16),

              // Email Option
              _AuthMethodCard(
                icon: Icons.email_outlined,
                title: 'Continue with Email',
                description: 'We\'ll send you a verification code via email',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmailEntryScreen(),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Privacy notice
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'By continuing, you agree to our Terms & Conditions\nand Privacy Policy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auth Method Card Widget
class _AuthMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AuthMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.border,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: AppColors.primaryOrange,
              ),
            ),

            const SizedBox(width: 16),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),

            // Arrow Icon
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
