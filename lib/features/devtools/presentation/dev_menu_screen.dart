import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:eros_app/core/network/api_config.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import '../data/devtools_api.dart';
import '../data/devtools_exceptions.dart';
import 'dev_menu_navigation.dart';
import 'providers/devtools_providers.dart';
import 'tabs/personas_tab.dart';
import 'tabs/scenarios_tab.dart';
import 'tabs/time_tab.dart';

/// Developer tools menu (route `/dev`).
///
/// Header: backend health (devtools on/off, server time, clock offset) and
/// the signed-in uid. Body: the Personas, Time and Scenarios tabs. Each tab
/// lives in its own file under `tabs/` and is owned by one ticket
/// (DT-F3, DT-F4, DT-F5).
///
/// Open it with [openDevMenu], or
/// `Navigator.pushNamed(context, devMenuRoute, arguments: DevMenuTab.time)`.
class DevMenuScreen extends ConsumerWidget {
  final DevMenuTab initialTab;

  const DevMenuScreen({super.key, this.initialTab = DevMenuTab.personas});

  /// Reads the initial tab from route arguments (a [DevMenuTab]), if any.
  factory DevMenuScreen.fromRoute(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return DevMenuScreen(
      initialTab: args is DevMenuTab ? args : DevMenuTab.personas,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasKey = ref.watch(devtoolsKeyProvider).isNotEmpty;

    return DefaultTabController(
      length: DevMenuTab.values.length,
      initialIndex: initialTab.index,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Developer tools',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
          actions: [
            if (hasKey)
              IconButton(
                tooltip: 'Refresh backend status',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(devtoolsHealthProvider),
              ),
          ],
          bottom: hasKey
              ? TabBar(
                  labelColor: AppColors.textPrimary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryOrange,
                  tabs: [
                    for (final tab in DevMenuTab.values) Tab(text: tab.label),
                  ],
                )
              : null,
        ),
        body: hasKey
            ? const Column(
                children: [
                  DevMenuHeader(),
                  Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      children: [
                        PersonasTab(),
                        TimeTab(),
                        ScenariosTab(),
                      ],
                    ),
                  ),
                ],
              )
            : const _MissingKeyMessage(),
      ),
    );
  }
}

/// Backend health and signed-in uid, above the tabs.
class DevMenuHeader extends ConsumerWidget {
  const DevMenuHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(devtoolsHealthProvider);
    final uid = ref.watch(devtoolsSignedInUidProvider);
    final textTheme = Theme.of(context).textTheme;
    final secondary =
        textTheme.bodySmall?.copyWith(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          health.when(
            loading: () => const _StatusLine(
              color: AppColors.textTertiary,
              title: 'Checking backend...',
            ),
            error: (error, _) => _errorLine(error),
            data: (h) => _StatusLine(
              color: h.enabled ? AppColors.success : AppColors.error,
              title: h.enabled ? 'Devtools on' : 'Devtools off',
              lines: [
                'Server time: ${formatServerTime(h.serverTime)}',
                'Clock offset: ${formatOffset(h.offset)}',
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            uid == null ? 'Signed out' : 'Signed in as $uid',
            key: const Key('devMenuSignedInUid'),
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text('Backend: ${ApiConfig.baseUrl}', style: secondary),
        ],
      ),
    );
  }

  Widget _errorLine(Object error) {
    if (error is DevtoolsDisabledException) {
      return const _StatusLine(
        color: AppColors.error,
        title: 'Devtools off',
        lines: ['Backend has devtools turned off (DEVTOOLS_ENABLED=true).'],
      );
    }
    if (error is UnauthorizedException) {
      return _StatusLine(
        color: AppColors.error,
        title: 'Dev key rejected',
        lines: [
          'DEVTOOLS_KEY does not match the backend.',
          error.message,
        ],
      );
    }
    return _StatusLine(
      color: AppColors.warning,
      title: 'Backend unreachable',
      lines: [error is ApiException ? error.message : error.toString()],
    );
  }
}

/// `Sat 17 Oct 13:00:00 UTC`
String formatServerTime(DateTime t) =>
    '${DateFormat('EEE d MMM HH:mm:ss').format(t.toUtc())} UTC';

/// `none`, or e.g. `+1d 1h 0m`.
String formatOffset(Duration offset) {
  if (offset == Duration.zero) return 'none';
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final days = abs.inDays;
  final hours = abs.inHours % 24;
  final minutes = abs.inMinutes % 60;
  return days > 0 ? '$sign${days}d ${hours}h ${minutes}m' : '$sign${hours}h ${minutes}m';
}

class _StatusLine extends StatelessWidget {
  final Color color;
  final String title;
  final List<String> lines;

  const _StatusLine({
    required this.color,
    required this.title,
    this.lines = const [],
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 10, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              for (final line in lines)
                Text(
                  line,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown instead of the tabs when the app was built without DEVTOOLS_KEY,
/// so no request is sent only to fail with 401.
class _MissingKeyMessage extends StatelessWidget {
  const _MissingKeyMessage();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.key_off, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('DEVTOOLS_KEY not set', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Rebuild the app with --dart-define=DEVTOOLS_KEY=<same as backend>. '
              'Dev requests are not sent without it.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
