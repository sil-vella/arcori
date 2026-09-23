import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_policy.dart';
import '../../core/state/auth/auth_providers.dart';
import 'velora_api.dart';
import 'velora_models.dart';

final veloraApiClientProvider = Provider<VeloraApiClient>(
  (ref) => VeloraApiClient(),
);

// ── Velora home: series list ─────────────────────────────────────────────────

class VeloraState {
  const VeloraState({
    this.series = const [],
    this.themes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final List<CatalogSeriesEntry> series;
  final List<CatalogThemeEntry> themes;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  VeloraState copyWith({
    List<CatalogSeriesEntry>? series,
    List<CatalogThemeEntry>? themes,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearError = false,
  }) {
    return VeloraState(
      series: series ?? this.series,
      themes: themes ?? this.themes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class VeloraNotifier extends Notifier<VeloraState> {
  @override
  VeloraState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        state = const VeloraState();
      }
    });
    return const VeloraState();
  }

  VeloraApiClient get _api => ref.read(veloraApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> loadSeries({bool force = false}) async {
    if (!force && state.loaded && state.errorMessage == null) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in to browse Velora',
        loaded: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final seriesOutcome = await _api.fetchSeries(accessToken: token);
    if (!seriesOutcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(seriesOutcome),
        loaded: false,
      );
      return;
    }
    // Meta themes are optional (lore labels on theme screens).
    final themesOutcome = await _api.fetchThemes(accessToken: token);
    final themes = themesOutcome.isSuccess
        ? List<CatalogThemeEntry>.from(themesOutcome.data!)
        : const <CatalogThemeEntry>[];
    themes.sort((a, b) => a.label.compareTo(b.label));
    state = state.copyWith(
      series: List.unmodifiable(seriesOutcome.data!),
      themes: themes,
      isLoading: false,
      loaded: true,
      clearError: true,
    );
  }

  /// @deprecated Prefer [loadSeries]; kept for call sites that still say themes.
  Future<void> loadThemes({bool force = false}) => loadSeries(force: force);

  String? _messageForOutcome(VeloraApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }
}

final veloraProvider = NotifierProvider<VeloraNotifier, VeloraState>(
  VeloraNotifier.new,
);

// ── Series → themes ──────────────────────────────────────────────────────────

class VeloraSeriesBrowseState {
  const VeloraSeriesBrowseState({
    this.themes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final List<VeloraThemeInSeries> themes;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  VeloraSeriesBrowseState copyWith({
    List<VeloraThemeInSeries>? themes,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearError = false,
  }) {
    return VeloraSeriesBrowseState(
      themes: themes ?? this.themes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class VeloraSeriesBrowseNotifier
    extends FamilyNotifier<VeloraSeriesBrowseState, String> {
  @override
  VeloraSeriesBrowseState build(String seriesKey) {
    return const VeloraSeriesBrowseState();
  }

  VeloraApiClient get _api => ref.read(veloraApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> load({bool force = false}) async {
    if (!force && state.loaded && state.errorMessage == null) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in to browse Velora',
        loaded: false,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchIndex(
      accessToken: token,
      series: arg,
    );
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
        loaded: false,
      );
      return;
    }
    state = state.copyWith(
      themes: groupByTheme(outcome.data!.items),
      isLoading: false,
      loaded: true,
      clearError: true,
    );
  }

  String? _messageForOutcome(VeloraApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }
}

final veloraSeriesBrowseProvider = NotifierProvider.family<
    VeloraSeriesBrowseNotifier, VeloraSeriesBrowseState, String>(
  VeloraSeriesBrowseNotifier.new,
);

/// Group circulating designs by themeCode within one series.
List<VeloraThemeInSeries> groupByTheme(List<DesignSummary> items) {
  final byTheme = <String, List<DesignSummary>>{};
  final labels = <String, String>{};
  for (final item in items) {
    final code = (item.themeCode != null && item.themeCode!.isNotEmpty)
        ? item.themeCode!
        : (item.theme != null && item.theme!.isNotEmpty)
            ? item.theme!
            : 'Unknown';
    byTheme.putIfAbsent(code, () => []).add(item);
    final name = item.theme?.trim() ?? '';
    if (name.isNotEmpty) {
      labels.putIfAbsent(code, () => name);
    }
  }
  final keys = byTheme.keys.toList()
    ..sort((a, b) {
      final la = labels[a] ?? a;
      final lb = labels[b] ?? b;
      return la.compareTo(lb);
    });
  return [
    for (final key in keys)
      VeloraThemeInSeries(
        theme: labels[key] ?? key,
        themeCode: key,
        designs: List.unmodifiable(byTheme[key]!),
      ),
  ];
}

// ── Theme browse (series + theme) + featured ─────────────────────────────────

@immutable
class VeloraThemeBrowseArgs {
  const VeloraThemeBrowseArgs({
    required this.seriesKey,
    required this.themeCode,
  });

  final String seriesKey;
  final String themeCode;

  @override
  bool operator ==(Object other) =>
      other is VeloraThemeBrowseArgs &&
      other.seriesKey == seriesKey &&
      other.themeCode == themeCode;

  @override
  int get hashCode => Object.hash(seriesKey, themeCode);
}

class VeloraThemeBrowseState {
  const VeloraThemeBrowseState({
    this.designs = const [],
    this.featured,
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final List<DesignSummary> designs;
  final DesignSummary? featured;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  VeloraThemeBrowseState copyWith({
    List<DesignSummary>? designs,
    DesignSummary? featured,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearFeatured = false,
    bool clearError = false,
  }) {
    return VeloraThemeBrowseState(
      designs: designs ?? this.designs,
      featured: clearFeatured ? null : (featured ?? this.featured),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class VeloraThemeBrowseNotifier
    extends FamilyNotifier<VeloraThemeBrowseState, VeloraThemeBrowseArgs> {
  @override
  VeloraThemeBrowseState build(VeloraThemeBrowseArgs args) {
    return const VeloraThemeBrowseState();
  }

  VeloraApiClient get _api => ref.read(veloraApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> load({bool force = false}) async {
    if (!force && state.loaded && state.errorMessage == null) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in to browse Velora',
        loaded: false,
        clearFeatured: true,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchIndex(
      accessToken: token,
      theme: arg.themeCode,
      series: arg.seriesKey,
    );
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
        loaded: false,
        clearFeatured: true,
      );
      return;
    }
    final designs = List<DesignSummary>.from(outcome.data!.items)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    state = state.copyWith(
      designs: List.unmodifiable(designs),
      featured: pickFeaturedDesign(designs),
      isLoading: false,
      loaded: true,
      clearError: true,
    );
  }

  String? _messageForOutcome(VeloraApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }
}

final veloraThemeBrowseProvider = NotifierProvider.family<
    VeloraThemeBrowseNotifier, VeloraThemeBrowseState, VeloraThemeBrowseArgs>(
  VeloraThemeBrowseNotifier.new,
);

DesignSummary? pickFeaturedDesign(List<DesignSummary> candidates) {
  if (candidates.isEmpty) return null;
  if (candidates.length == 1) return candidates.first;
  return candidates[Random().nextInt(candidates.length)];
}

/// Group circulating designs by seriesKey (legacy helper).
List<VeloraSeriesGroup> groupBySeries(List<DesignSummary> items) {
  final bySeries = <String, List<DesignSummary>>{};
  for (final item in items) {
    final seriesKey = (item.seriesKey != null && item.seriesKey!.isNotEmpty)
        ? item.seriesKey!
        : 'Unknown';
    bySeries.putIfAbsent(seriesKey, () => []).add(item);
  }
  final keys = bySeries.keys.toList()..sort();
  return [
    for (final key in keys)
      VeloraSeriesGroup(
        seriesKey: key,
        designs: List.unmodifiable(bySeries[key]!),
      ),
  ];
}

// ── Arcori detail ────────────────────────────────────────────────────────────

class ArcoriDetailState {
  const ArcoriDetailState({
    this.design,
    this.isLoading = false,
    this.errorMessage,
  });

  final DesignDetail? design;
  final bool isLoading;
  final String? errorMessage;

  ArcoriDetailState copyWith({
    DesignDetail? design,
    bool? isLoading,
    String? errorMessage,
    bool clearDesign = false,
    bool clearError = false,
  }) {
    return ArcoriDetailState(
      design: clearDesign ? null : (design ?? this.design),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ArcoriDetailNotifier extends Notifier<ArcoriDetailState> {
  @override
  ArcoriDetailState build() => const ArcoriDetailState();

  VeloraApiClient get _api => ref.read(veloraApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> load(String internalId) async {
    final id = internalId.trim();
    if (id.isEmpty) {
      state = const ArcoriDetailState(
        errorMessage: 'Missing design id',
      );
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = const ArcoriDetailState(
        errorMessage: 'Sign in to view this Arcori',
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearDesign: true,
    );
    final outcome = await _api.fetchDesign(
      accessToken: token,
      internalId: id,
    );
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
      );
      return;
    }
    state = state.copyWith(
      design: outcome.data,
      isLoading: false,
      clearError: true,
    );
  }

  String? _messageForOutcome(VeloraApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }
}

final arcoriDetailProvider =
    NotifierProvider<ArcoriDetailNotifier, ArcoriDetailState>(
  ArcoriDetailNotifier.new,
);

class ArcoriStandingsState {
  const ArcoriStandingsState({
    this.standings,
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final DesignStandings? standings;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  ArcoriStandingsState copyWith({
    DesignStandings? standings,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearStandings = false,
    bool clearError = false,
  }) {
    return ArcoriStandingsState(
      standings: clearStandings ? null : (standings ?? this.standings),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class ArcoriStandingsNotifier
    extends FamilyNotifier<ArcoriStandingsState, String> {
  @override
  ArcoriStandingsState build(String internalId) => const ArcoriStandingsState();

  VeloraApiClient get _api => ref.read(veloraApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> load({bool force = false}) async {
    if (!force && state.loaded && state.errorMessage == null) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in to view standings',
        loaded: false,
      );
      return;
    }
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearStandings: true,
    );
    final outcome = await _api.fetchStandings(
      accessToken: token,
      internalId: arg,
    );
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
        loaded: false,
      );
      return;
    }
    state = state.copyWith(
      standings: outcome.data,
      isLoading: false,
      loaded: true,
      clearError: true,
    );
  }

  String? _messageForOutcome(VeloraApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Network error — check your connection';
    }
    final error = outcome.error;
    if (error == null) {
      return null;
    }
    actionForApiError(error, isWebSocket: false);
    return error.message;
  }
}

final arcoriStandingsProvider = NotifierProvider.family<
    ArcoriStandingsNotifier, ArcoriStandingsState, String>(
  ArcoriStandingsNotifier.new,
);
