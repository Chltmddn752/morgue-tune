import 'package:mornye/services/listening_statistics.dart';
import 'package:sqflite/sqflite.dart';

/// Day number counted from 1970-01-01, independent of daylight saving time.
int listeningDayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime listeningDateOfDay(int day) {
  final utc = DateTime.fromMillisecondsSinceEpoch(
    day * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}

int _parseDay(String day) => listeningDayNumber(DateTime.parse(day));

/// A run of consecutive listening days.
class ListeningRun {
  const ListeningRun(this.days, this.start, this.end, [this.artist]);

  final int days;
  final int start;
  final int end;
  final String? artist;
}

class ListeningStreaks {
  const ListeningStreaks({
    required this.current,
    required this.listenedToday,
    this.longest,
    this.artist,
  });

  static const empty = ListeningStreaks(current: 0, listenedToday: false);

  /// Days in a row up to today, or up to yesterday if nothing played today.
  final int current;
  final bool listenedToday;
  final ListeningRun? longest;

  /// The artist heard on the most consecutive days (at least two).
  final ListeningRun? artist;
}

class ListeningDiscovery {
  const ListeningDiscovery(this.artist, this.firstDay, this.milliseconds);

  final String artist;
  final int firstDay;
  final int milliseconds;
}

class ListeningMonth {
  const ListeningMonth(this.year, this.month, this.milliseconds, this.artists);

  final int year;
  final int month;
  final int milliseconds;

  /// Most listened artists of the month, by listening time.
  final List<MapEntry<String, int>> artists;
}

/// Everything the patterns section shows, computed from the daily records.
class ListeningPatterns {
  const ListeningPatterns({
    required this.today,
    required this.dayTotals,
    required this.weekdayHours,
    required this.streaks,
    required this.discoveries,
    required this.firstDay,
    required this.months,
  });

  final int today;

  /// Listening time per day number.
  final Map<int, int> dayTotals;

  /// [weekday 0 = Monday][hour] listening time.
  final List<List<int>> weekdayHours;
  final ListeningStreaks streaks;

  /// Artists first heard during the last 30 days.
  final List<ListeningDiscovery> discoveries;
  final int? firstDay;

  /// The last twelve months, newest first, including empty months.
  final List<ListeningMonth> months;

  bool get isEmpty => dayTotals.isEmpty;

  bool get hasHourlyData =>
      weekdayHours.any((hours) => hours.any((value) => value > 0));
}

/// Maps values to five shades (0 = none) by the quartiles of the non-zero
/// values, so one long day does not wash out the rest of the year.
int Function(int) listeningHeatLevels(Iterable<int> values) {
  final nonZero = values.where((value) => value > 0).toList()..sort();
  if (nonZero.isEmpty) return (_) => 0;
  int quantile(double p) =>
      nonZero[(p * nonZero.length).floor().clamp(0, nonZero.length - 1)];
  final q1 = quantile(0.25), q2 = quantile(0.5), q3 = quantile(0.75);
  return (value) => value <= 0
      ? 0
      : value <= q1
      ? 1
      : value <= q2
      ? 2
      : value <= q3
      ? 3
      : 4;
}

ListeningRun? _longestRun(Iterable<int> days, [String? artist]) {
  final sorted = days.toSet().toList()..sort();
  if (sorted.isEmpty) return null;
  var best = ListeningRun(1, sorted.first, sorted.first, artist);
  var start = sorted.first;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] != sorted[i - 1] + 1) start = sorted[i];
    final length = sorted[i] - start + 1;
    if (length >= best.days) {
      best = ListeningRun(length, start, sorted[i], artist);
    }
  }
  return best;
}

ListeningStreaks computeListeningStreaks(
  Set<int> days,
  Map<String, Set<int>> artistDays,
  int today,
) {
  if (days.isEmpty) return ListeningStreaks.empty;
  var cursor = days.contains(today) ? today : today - 1;
  var current = 0;
  while (days.contains(cursor)) {
    current++;
    cursor--;
  }
  ListeningRun? artist;
  for (final entry in artistDays.entries) {
    final run = _longestRun(entry.value, entry.key);
    if (run == null) continue;
    if (artist == null ||
        run.days > artist.days ||
        (run.days == artist.days && run.end > artist.end)) {
      artist = run;
    }
  }
  return ListeningStreaks(
    current: current,
    listenedToday: days.contains(today),
    longest: _longestRun(days),
    artist: (artist?.days ?? 0) >= 2 ? artist : null,
  );
}

/// Builds the patterns from rows of (day, artist, milliseconds) and
/// (day, hour, milliseconds).
ListeningPatterns computeListeningPatterns({
  required List<({String day, String artist, int milliseconds})> artistRows,
  required List<({String day, int hour, int milliseconds})> hourRows,
  required DateTime now,
}) {
  final today = listeningDayNumber(now);
  final dayTotals = <int, int>{};
  final artistDays = <String, Set<int>>{};
  final firstHeard = <String, int>{};
  final recentTime = <String, int>{};
  final monthArtists = <int, Map<String, int>>{};
  for (final row in artistRows) {
    if (row.milliseconds <= 0) continue;
    final day = _parseDay(row.day);
    final artist = row.artist.trim();
    dayTotals[day] = (dayTotals[day] ?? 0) + row.milliseconds;
    if (artist.isEmpty) continue;
    artistDays.putIfAbsent(artist, () => {}).add(day);
    final first = firstHeard[artist];
    if (first == null || day < first) firstHeard[artist] = day;
    if (day > today - 30) {
      recentTime[artist] = (recentTime[artist] ?? 0) + row.milliseconds;
    }
    final date = DateTime.parse(row.day);
    final month = date.year * 12 + date.month - 1;
    final artists = monthArtists.putIfAbsent(month, () => {});
    artists[artist] = (artists[artist] ?? 0) + row.milliseconds;
  }

  final weekdayHours = List.generate(7, (_) => List.filled(24, 0));
  for (final row in hourRows) {
    if (row.milliseconds <= 0 || row.hour < 0 || row.hour > 23) continue;
    final weekday = DateTime.parse(row.day).weekday - 1;
    weekdayHours[weekday][row.hour] += row.milliseconds;
  }

  final firstDay = dayTotals.isEmpty
      ? null
      : dayTotals.keys.reduce((a, b) => a < b ? a : b);
  // A discovery means something only once there is history before it.
  final discoveries = firstDay == null || firstDay > today - 30
      ? <ListeningDiscovery>[]
      : [
          for (final entry in firstHeard.entries)
            if (entry.value > today - 30)
              ListeningDiscovery(
                entry.key,
                entry.value,
                recentTime[entry.key] ?? 0,
              ),
        ];
  discoveries.sort(
    (a, b) => b.milliseconds != a.milliseconds
        ? b.milliseconds.compareTo(a.milliseconds)
        : a.firstDay.compareTo(b.firstDay),
  );

  final thisMonth = now.year * 12 + now.month - 1;
  final months = [
    for (var month = thisMonth; month > thisMonth - 12; month--)
      () {
        final artists = (monthArtists[month] ?? const <String, int>{}).entries
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ListeningMonth(
          month ~/ 12,
          month % 12 + 1,
          artists.fold(0, (sum, entry) => sum + entry.value),
          artists.take(3).toList(),
        );
      }(),
  ];
  // Hide the empty months before listening was first recorded.
  final firstMonth = firstDay == null
      ? thisMonth
      : () {
          final date = listeningDateOfDay(firstDay);
          return date.year * 12 + date.month - 1;
        }();
  months.removeWhere((month) => month.year * 12 + month.month - 1 < firstMonth);

  return ListeningPatterns(
    today: today,
    dayTotals: dayTotals,
    weekdayHours: weekdayHours,
    streaks: computeListeningStreaks(dayTotals.keys.toSet(), artistDays, today),
    discoveries: discoveries.take(10).toList(),
    firstDay: firstDay,
    months: months,
  );
}

Future<ListeningPatterns> readListeningPatterns(
  DatabaseExecutor db,
  DateTime now,
) async {
  final artistRows = await db.rawQuery('''
    SELECT day, artist, SUM(milliseconds) AS milliseconds
    FROM listening GROUP BY day, artist
  ''');
  List<Map<String, Object?>> hourRows;
  try {
    hourRows = await db.rawQuery('''
      SELECT day, hour, SUM(milliseconds) AS milliseconds
      FROM listening_hours WHERE day >= ? GROUP BY day, hour
    ''', [listeningDay(DateTime(now.year - 1, now.month, now.day))]);
  } on DatabaseException {
    hourRows = const [];
  }
  return computeListeningPatterns(
    artistRows: [
      for (final row in artistRows)
        (
          day: row['day'] as String,
          artist: row['artist'] as String,
          milliseconds: (row['milliseconds'] as num?)?.toInt() ?? 0,
        ),
    ],
    hourRows: [
      for (final row in hourRows)
        (
          day: row['day'] as String,
          hour: (row['hour'] as num).toInt(),
          milliseconds: (row['milliseconds'] as num?)?.toInt() ?? 0,
        ),
    ],
    now: now,
  );
}
