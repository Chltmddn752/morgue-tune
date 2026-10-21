import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/services/listening_statistics.dart';
import 'package:mornye/services/listening_patterns.dart';

final listeningSummaryProvider = FutureProvider.autoDispose
    .family<ListeningSummary, ({int days, int year})>((ref, period) async {
      await listeningRecorder.flush();
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final start = period.days == 0
          ? DateTime(period.year)
          : DateTime(now.year, now.month, now.day - period.days + 1);
      final end = period.days == 0 ? DateTime(period.year + 1) : tomorrow;
      return ListeningStatisticsStore.instance.load(start, end);
    });

/// Year heatmap, weekday and hour pattern, streaks, discoveries and monthly
/// favorites across everything recorded on this device.
final listeningPatternsProvider = FutureProvider.autoDispose<ListeningPatterns>(
  (ref) async {
    await listeningRecorder.flush();
    return ListeningStatisticsStore.instance.read(
      (db) => readListeningPatterns(db, DateTime.now()),
    );
  },
);
