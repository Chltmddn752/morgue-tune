import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/providers/listening_statistics_provider.dart';
import 'package:mornye/services/listening_patterns.dart';
import 'package:mornye/theme/mornye_theme.dart';
import 'package:mornye/widgets/app_content_card.dart';
import 'package:mornye/widgets/settings_group.dart';

/// Year heatmap, weekday and hour heatmap, streaks, new artists and monthly
/// favorites, below the period summary on the statistics screen.
class ListeningPatternsSection extends ConsumerWidget {
  const ListeningPatternsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patterns = ref.watch(listeningPatternsProvider).value;
    if (patterns == null || patterns.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    String date(int day) => DateFormat.MMMd(
      locale,
    ).format(listeningDateOfDay(day));
    String minutes(int milliseconds) =>
        context.l10n.listeningStatsMinutes((milliseconds / 60000).round());
    final streaks = patterns.streaks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: context.l10n.listeningPatternsYear),
        _YearHeatmap(patterns: patterns),
        SettingsSectionHeader(title: context.l10n.listeningPatternsWeekHours),
        _WeekHourHeatmap(patterns: patterns),
        SettingsSectionHeader(title: context.l10n.listeningPatternsStreaks),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 520 ? 3 : 2;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatCard(
                    width: width,
                    title: context.l10n.listeningPatternsCurrentStreak,
                    value: context.l10n.listeningPatternsStreakDays(
                      streaks.current,
                    ),
                    caption: streaks.current == 0
                        ? null
                        : streaks.listenedToday
                        ? context.l10n.listeningPatternsListenedToday
                        : context.l10n.listeningPatternsListenToday,
                  ),
                  _StatCard(
                    width: width,
                    title: context.l10n.listeningPatternsLongestStreak,
                    value: streaks.longest == null
                        ? '–'
                        : context.l10n.listeningPatternsStreakDays(
                            streaks.longest!.days,
                          ),
                    caption: streaks.longest == null
                        ? null
                        : _range(context, streaks.longest!, date),
                  ),
                  if (streaks.artist != null)
                    _StatCard(
                      width: width,
                      title: context.l10n.listeningPatternsArtistStreak,
                      value: context.l10n.listeningPatternsStreakDays(
                        streaks.artist!.days,
                      ),
                      caption:
                          '${streaks.artist!.artist}\n'
                          '${_range(context, streaks.artist!, date)}',
                    ),
                ],
              );
            },
          ),
        ),
        if (patterns.discoveries.isNotEmpty) ...[
          SettingsSectionHeader(
            title: context.l10n.listeningPatternsDiscoveries,
          ),
          for (final discovery in patterns.discoveries)
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(discovery.artist),
              subtitle: Text(
                context.l10n.listeningPatternsFirstHeard(
                  date(discovery.firstDay),
                ),
              ),
              trailing: Text(minutes(discovery.milliseconds)),
            ),
        ],
        if (patterns.months.isNotEmpty) ...[
          SettingsSectionHeader(title: context.l10n.listeningPatternsMonthly),
          for (final month in patterns.months)
            ListTile(
              title: Text(
                DateFormat.yMMMM(
                  locale,
                ).format(DateTime(month.year, month.month)),
              ),
              subtitle: Text(
                month.artists.isEmpty
                    ? context.l10n.listeningPatternsMonthEmpty
                    : [
                        for (final (index, artist) in month.artists.indexed)
                          '${index + 1}. ${artist.key}',
                      ].join('   '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: month.milliseconds == 0
                  ? null
                  : Text(minutes(month.milliseconds)),
            ),
        ],
      ],
    );
  }

  static String _range(
    BuildContext context,
    ListeningRun run,
    String Function(int) date,
  ) => run.start == run.end
      ? date(run.start)
      : context.l10n.listeningPatternsDateRange(date(run.start), date(run.end));
}

Color _heatColor(BuildContext context, int level) {
  final colors = Theme.of(context).colorScheme;
  if (level <= 0) {
    return context.isMornye
        ? MornyeTheme.controlFill(context)
        : colors.surfaceContainerHighest;
  }
  return colors.primary.withValues(alpha: const [0, 0.3, 0.5, 0.75, 1][level]);
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(context.l10n.listeningPatternsLess, style: style),
        const SizedBox(width: 4),
        for (var level = 0; level <= 4; level++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: SizedBox.square(
              dimension: 10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _heatColor(context, level),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
          ),
        const SizedBox(width: 4),
        Text(context.l10n.listeningPatternsMore, style: style),
      ],
    );
  }
}

/// Fifty-three weeks of days, Monday at the top, the current week at the end.
class _YearHeatmap extends StatelessWidget {
  const _YearHeatmap({required this.patterns});

  final ListeningPatterns patterns;

  static const _cell = 11.0;
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    final today = patterns.today;
    // Monday of the current week, then 52 weeks before it.
    final todayWeekday = listeningDateOfDay(today).weekday - 1;
    final firstDay = today - todayWeekday - 52 * 7;
    final values = {
      for (final entry in patterns.dayTotals.entries)
        if (entry.key >= firstDay && entry.key <= today) entry.key: entry.value,
    };
    final level = listeningHeatLevels(values.values);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Start at the most recent weeks.
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var week = 0; week < 53; week++)
                      SizedBox(
                        width: _cell + _gap,
                        child: () {
                          final start = listeningDateOfDay(
                            firstDay + week * 7,
                          );
                          final previous = listeningDateOfDay(
                            firstDay + week * 7 - 7,
                          );
                          // Month names overflow to the right of their week.
                          return week > 0 && start.month != previous.month
                              ? OverflowBox(
                                  alignment: AlignmentDirectional.centerStart,
                                  maxWidth: 48,
                                  child: Text(
                                    DateFormat.MMM(locale).format(start),
                                    style: labelStyle,
                                    maxLines: 1,
                                  ),
                                )
                              : const SizedBox(height: 14);
                        }(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var week = 0; week < 53; week++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: _gap),
                        child: Column(
                          children: [
                            for (var weekday = 0; weekday < 7; weekday++)
                              () {
                                final day = firstDay + week * 7 + weekday;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: _gap),
                                  child: SizedBox.square(
                                    dimension: _cell,
                                    child: day > today
                                        ? null
                                        : Tooltip(
                                            message:
                                                '${DateFormat.yMMMd(locale).format(listeningDateOfDay(day))}'
                                                ' · ${context.l10n.listeningStatsMinutes(((values[day] ?? 0) / 60000).round())}',
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: _heatColor(
                                                  context,
                                                  level(values[day] ?? 0),
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(2.5),
                                              ),
                                            ),
                                          ),
                                  ),
                                );
                              }(),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.listeningPatternsYearDetail(values.length),
                  style: labelStyle,
                ),
              ),
              const _HeatLegend(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Seven weekday rows by twenty-four hours, fitted to the screen width.
class _WeekHourHeatmap extends StatelessWidget {
  const _WeekHourHeatmap({required this.patterns});

  final ListeningPatterns patterns;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (!patterns.hasHourlyData) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          context.l10n.listeningPatternsWeekHoursEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final matrix = patterns.weekdayHours;
    final level = listeningHeatLevels(matrix.expand((row) => row));
    var peakWeekday = 0, peakHour = 0, peak = 0;
    for (var weekday = 0; weekday < 7; weekday++) {
      for (var hour = 0; hour < 24; hour++) {
        if (matrix[weekday][hour] > peak) {
          peak = matrix[weekday][hour];
          peakWeekday = weekday;
          peakHour = hour;
        }
      }
    }
    // 2024-01-01 was a Monday.
    String weekdayName(int weekday, {bool short = true}) =>
        (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(
          DateTime(2024, 1, 1 + weekday),
        );
    String hourName(int hour) =>
        DateFormat.j(locale).format(DateTime(2024, 1, 1, hour));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 28.0;
              const gap = 2.0;
              final cell = ((constraints.maxWidth - labelWidth) / 24 - gap)
                  .clamp(6.0, 22.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var weekday = 0; weekday < 7; weekday++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: Row(
                        children: [
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              weekdayName(weekday),
                              style: labelStyle,
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                          for (var hour = 0; hour < 24; hour++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: gap,
                              ),
                              child: SizedBox(
                                width: cell,
                                height: cell,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _heatColor(
                                      context,
                                      level(matrix[weekday][hour]),
                                    ),
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: labelWidth,
                      top: 2,
                    ),
                    child: SizedBox(
                      width: (cell + gap) * 24,
                      child: Row(
                        children: [
                          for (final hour in const [0, 6, 12, 18])
                            Expanded(
                              child: Text(
                                hourName(hour),
                                style: labelStyle,
                                maxLines: 1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.listeningPatternsWeekHoursPeak(
                    weekdayName(peakWeekday, short: false),
                    hourName(peakHour),
                  ),
                  style: labelStyle,
                ),
              ),
              const _HeatLegend(),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.width,
    required this.title,
    required this.value,
    this.caption,
  });

  final double width;
  final String title;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      width: width,
      child: AppContentCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: secondary),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(caption!, style: secondary, maxLines: 3),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
