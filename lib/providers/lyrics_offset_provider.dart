import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mornye/providers/music_player_provider.dart';
import 'package:mornye/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kLyricsOffsetsKey = 'lyrics_offsets_ms';
const kLyricsOffsetStep = Duration(milliseconds: 500);
const _maxStoredOffsets = 500;

/// Per-track lyrics timing corrections in milliseconds, keyed by queue item
/// id. Positive values show the lyrics later.
final lyricsOffsetsProvider =
    NotifierProvider<LyricsOffsetsNotifier, Map<String, int>>(
      LyricsOffsetsNotifier.new,
    );

class LyricsOffsetsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    unawaited(_load());
    return const {};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kLyricsOffsetsKey);
      if (raw == null || state.isNotEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        state = {
          for (final entry in decoded.entries)
            if (entry.value is num)
              entry.key.toString(): (entry.value as num).toInt(),
        };
      }
    } catch (_) {
      // A damaged value only loses timing corrections.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kLyricsOffsetsKey, jsonEncode(state));
    } catch (_) {}
  }

  void adjust(String trackId, Duration delta) {
    final next = (state[trackId] ?? 0) + delta.inMilliseconds;
    set(trackId, next);
  }

  void set(String trackId, int milliseconds) {
    final updated = Map<String, int>.of(state)..remove(trackId);
    if (milliseconds != 0) updated[trackId] = milliseconds.clamp(-30000, 30000);
    // Keep the newest corrections; insertion order is the edit order.
    while (updated.length > _maxStoredOffsets) {
      updated.remove(updated.keys.first);
    }
    state = Map.unmodifiable(updated);
    unawaited(_save());
  }
}

/// The current track's lyrics offset.
final currentLyricsOffsetProvider = Provider<Duration>((ref) {
  final id = ref.watch(
    currentMediaItemProvider.select((item) => item.value?.id),
  );
  if (id == null) return Duration.zero;
  return Duration(
    milliseconds: ref.watch(
      lyricsOffsetsProvider.select((offsets) => offsets[id] ?? 0),
    ),
  );
});

/// How the synced lyrics view adjusts lines before showing them.
final lyricsDisplayAdjustmentProvider =
    Provider<({bool estimateWords, Duration offset})>(
      (ref) => (
        estimateWords: ref.watch(
          settingsProvider.select((s) => s.lyricsEstimateWordTiming),
        ),
        offset: ref.watch(currentLyricsOffsetProvider),
      ),
    );
