import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/match_preferences/data/match_preferences_repository.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_filter.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preference_options.dart';
import 'package:eros_app/features/match_preferences/domain/models/match_preferences.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preference_options_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_banner_providers.dart';
import 'package:eros_app/features/match_preferences/presentation/providers/match_preferences_provider.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_filter_editors.dart';
import 'package:eros_app/features/match_preferences/presentation/screens/match_filter_summary.dart';

/// Every string this screen shows that isn't a summary.
abstract final class _Copy {
  static const title = 'Match preferences';
  static const intro = 'Tell us who you\'d like to meet. Only you can see this page.';
  static const banner = 'Only people who fit a dealbreaker are shown. Everything else just '
      'decides who you see first.';
  static const dismiss = 'Dismiss';
  static const dealbreaker = 'Dealbreaker';
  static String editHint(String filter) => 'Edit $filter';

  static const loadError = 'We couldn\'t load your match preferences. Please try again.';
  static const retry = 'Try again';
  static const back = 'Back';
}

/// Match preferences (RFC-007 §6.2, D-17): every filter in §4.1's order with its summary, and
/// "Dealbreaker" on the right of the hard ones. From `GET /users/me/match-preferences`
/// ([matchPreferencesProvider]) and `GET /match-preferences/options`
/// ([matchPreferenceOptionsProvider]). Tapping a row opens its editor ([matchFilterEditor]).
///
/// Every filter is free (D-3), so there are no locks, and it never shows a count of people
/// (D-16).
class MatchPreferencesScreen extends ConsumerWidget {
  const MatchPreferencesScreen({super.key});

  /// Fetches the preferences and the options again, for retry and pull-to-refresh.
  static Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.read(matchPreferencesProvider.notifier).load(),
      // A failure shows through the provider's error state, so it isn't rethrown here.
      ref.refresh(matchPreferenceOptionsProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(matchPreferencesProvider);
    final options = ref.watch(matchPreferenceOptionsProvider);

    // A failed load or refresh shows the error, even though the providers still hold the old
    // values, so the hub never shows summaries the server didn't just confirm.
    final Widget body;
    if (preferences.hasError && !preferences.isLoading) {
      body = _LoadError(error: preferences.error!, onRetry: () => _refresh(ref));
    } else if (options.hasError && !options.isLoading) {
      body = _LoadError(error: options.error!, onRetry: () => _refresh(ref));
    } else if ((preferences.valueOrNull, options.valueOrNull) case (final p?, final o?)) {
      body = RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: _Hub(preferences: p, options: o),
      );
    } else {
      body = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: _Copy.back,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(_Copy.title, style: TextStyle(color: Colors.black)),
      ),
      body: body,
    );
  }
}

class _Hub extends ConsumerWidget {
  final MatchPreferences preferences;
  final MatchPreferenceOptions options;

  const _Hub({required this.preferences, required this.options});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannerDismissed = ref.watch(matchPreferencesBannerDismissedProvider);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(_Copy.intro, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        if (!bannerDismissed) ...[
          const SizedBox(height: 16),
          _DealbreakersBanner(
            onDismiss: () => ref.read(matchPreferencesBannerDismissedProvider.notifier).dismiss(),
          ),
        ],
        const SizedBox(height: 16),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final filter in MatchFilter.values) ...[
                if (filter.index > 0) const Divider(height: 1, indent: 16),
                _FilterRow(
                  title: filter.label,
                  summary: matchFilterSummary(filter, preferences, options),
                  dealbreaker: isMatchFilterDealbreaker(filter, preferences),
                  onTap: () => openMatchFilterEditor(
                    context,
                    filter: filter,
                    preferences: preferences,
                    options: options,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Explains dealbreakers until the user closes it, remembered per user on this device
/// (RFC-007 §4.9).
class _DealbreakersBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _DealbreakersBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppColors.secondaryOrange.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: AppColors.accentOrange),
          const SizedBox(width: 12),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _Copy.banner,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            tooltip: _Copy.dismiss,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// One filter: its title over its summary, "Dealbreaker" when it is one, and a chevron. The whole
/// row opens the filter's editor.
class _FilterRow extends StatelessWidget {
  final String title;
  final String summary;
  final bool dealbreaker;
  final VoidCallback onTap;

  const _FilterRow({
    required this.title,
    required this.summary,
    required this.dealbreaker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // One button node reading the title, the summary and the marker, so it is named with hints
    // off.
    return Semantics(
      container: true,
      button: true,
      label: [title, summary, if (dealbreaker) _Copy.dealbreaker].join(', '),
      hint: _Copy.editHint(title),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                if (dealbreaker) ...[
                  const SizedBox(width: 8),
                  const Text(
                    _Copy.dealbreaker,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOrange,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _LoadError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is MatchPreferencesRepositoryException
        ? (error as MatchPreferencesRepositoryException).message
        : _Copy.loadError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text(_Copy.retry)),
          ],
        ),
      ),
    );
  }
}
