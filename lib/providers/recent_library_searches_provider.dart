import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kRecentLibrarySearchesKey = 'recent_library_searches';
const _maxRecentSearches = 10;

/// Library searches the user submitted, newest first.
final recentLibrarySearchesProvider =
    NotifierProvider<RecentLibrarySearchesNotifier, List<String>>(
      RecentLibrarySearchesNotifier.new,
    );

class RecentLibrarySearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    unawaited(_load());
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(kRecentLibrarySearchesKey);
      if (saved != null && state.isEmpty) state = saved;
    } catch (_) {
      // Recent searches are a convenience; a storage failure leaves none.
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kRecentLibrarySearchesKey, state);
    } catch (_) {}
  }

  void add(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    state = [
      trimmed,
      for (final item in state)
        if (item.toLowerCase() != trimmed.toLowerCase()) item,
    ].take(_maxRecentSearches).toList(growable: false);
    unawaited(_save());
  }

  void remove(String query) {
    state = [
      for (final item in state)
        if (item != query) item,
    ];
    unawaited(_save());
  }

  void clear() {
    state = const [];
    unawaited(_save());
  }
}
