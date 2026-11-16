import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preferences.dart';
import 'package:eros_app/features/date_preferences/domain/models/section_patch.dart';
import 'package:eros_app/features/date_preferences/presentation/providers/date_preferences_provider.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/preference_level_selector.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';

/// Every string this screen shows that isn't from the options.
abstract final class _Copy {
  static const title = 'Date types';
  static const keepOne = 'Keep at least one kind of date';
  static const comingSoon = 'Coming soon';

  /// "0.5 token deposit", "1 token deposit": no trailing zeros.
  static String deposit(double tokens) {
    final amount =
        tokens == tokens.truncateToDouble() ? tokens.toInt().toString() : tokens.toString();
    return '$amount token deposit';
  }
}

/// The activity statuses from `GET /date-preferences/options`.
const _active = 'ACTIVE';
const _comingSoon = 'COMING_SOON';

/// Date types (RFC-005 §6.2): one [PreferenceLevelSelector] per activity, in the order of
/// [activities] (from the options, D-8), starting from the user's saved levels in [preferences].
///
/// Save sends every activity's level as one [ActivitiesPatch] (D-2). It stays disabled while
/// every `ACTIVE` activity is "Not for me", because the server rejects that; the server's 400
/// still shows in the banner if it disagrees. A `COMING_SOON` activity can be set too (D-7), and
/// an activity's `ageNote` is shown as the server wrote it (D-25).
class EditDateTypesScreen extends ConsumerStatefulWidget {
  final List<DateActivityOption> activities;
  final DatePreferences preferences;

  const EditDateTypesScreen({super.key, required this.activities, required this.preferences});

  @override
  ConsumerState<EditDateTypesScreen> createState() => _EditDateTypesScreenState();
}

class _EditDateTypesScreenState extends ConsumerState<EditDateTypesScreen> {
  late final Map<int, PreferenceLevel> _initial = {
    for (final activity in widget.activities)
      activity.activityId: widget.preferences.levelFor(activity.activityId),
  };
  late final Map<int, PreferenceLevel> _levels = {..._initial};

  bool get _isDirty => widget.activities.any((a) => _levels[a.activityId] != _initial[a.activityId]);

  /// True when every `ACTIVE` activity is "Not for me".
  bool get _noneKept {
    final active = widget.activities.where((a) => a.status == _active);
    return active.isNotEmpty && active.every((a) => _levels[a.activityId] == PreferenceLevel.no);
  }

  Future<void> _save() async {
    await ref.read(datePreferencesProvider.notifier).saveSection(ActivitiesPatch([
      for (final activity in widget.activities)
        ActivityPreference(activityId: activity.activityId, level: _levels[activity.activityId]!),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final noneKept = _noneKept;
    return EditSectionScaffold(
      title: _Copy.title,
      isDirty: _isDirty,
      canSave: _isDirty && !noneKept,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (noneKept) ...[
            const _KeepOneNotice(),
            const SizedBox(height: 16),
          ],
          for (final activity in widget.activities) ...[
            _ActivityRow(
              activity: activity,
              level: _levels[activity.activityId]!,
              onChanged: (level) => setState(() => _levels[activity.activityId] = level),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Shown while every `ACTIVE` activity is "Not for me".
class _KeepOneNotice extends StatelessWidget {
  const _KeepOneNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('keep-one-notice'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.accentOrange),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                _Copy.keepOne,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One activity: its icon, name (with a "Coming soon" tag), age note, description and deposit,
/// then the level selector.
class _ActivityRow extends StatelessWidget {
  final DateActivityOption activity;
  final PreferenceLevel level;
  final ValueChanged<PreferenceLevel> onChanged;

  const _ActivityRow({required this.activity, required this.level, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final description = activity.description;
    final ageNote = activity.ageNote;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActivityIcon(url: activity.iconUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          activity.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (activity.status == _comingSoon) const _ComingSoonTag(),
                      ],
                    ),
                    if (ageNote != null) ...[
                      const SizedBox(height: 4),
                      Text(ageNote, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                    if (description != null) ...[
                      const SizedBox(height: 4),
                      Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _Copy.deposit(activity.tokenCost),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PreferenceLevelSelector(
            key: ValueKey('level-${activity.activityId}'),
            value: level,
            onChanged: onChanged,
            semanticLabel: activity.name,
          ),
        ],
      ),
    );
  }
}

/// The activity's icon from the options, or a generic one when it has none or fails to load.
/// Decorative: the name next to it says what it is.
class _ActivityIcon extends StatelessWidget {
  final String? url;

  const _ActivityIcon({required this.url});

  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    const fallback = Icon(Icons.local_activity_outlined, size: 28, color: AppColors.accentOrange);
    final url = this.url;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _size,
        child: Center(
          child: url == null
              ? fallback
              : CachedNetworkImage(
                  imageUrl: url,
                  width: _size,
                  height: _size,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}

class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.secondaryOrange.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Text(
        _Copy.comingSoon,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}
