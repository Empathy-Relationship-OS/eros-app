import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// Shown once a report or safety cancel is filed (CH-F5 step 3).
///
/// Calm: what happens next, what happened to the deposit by `yourRefund`, and the local
/// emergency number for the date's city.
class ReportResultScreen extends StatelessWidget {
  final ReportResult result;
  final String cityName;

  const ReportResultScreen({super.key, required this.result, required this.cityName});

  @override
  Widget build(BuildContext context) {
    final refundLine = SafetyCopy.refundLine(result.yourRefund);
    const bodyStyle = TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.5);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.shield_outlined, size: 56, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                SafetyCopy.resultHeading,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                SafetyCopy.resultBody(dateEnded: result.dateEnded),
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
              if (refundLine != null) ...[
                const SizedBox(height: 12),
                Text(refundLine, style: bodyStyle, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 24),
              Text(
                SafetyCopy.emergencyLine(cityName),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(SafetyCopy.done),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
