import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_policy.dart';
import '../../core/state/auth/auth_providers.dart';
import 'velora_api.dart';
import 'velora_models.dart';

final veloraApiClientProvider = Provider<VeloraApiClient>(
  (ref) => VeloraApiClient(),
);

class VeloraState {
  const VeloraState({
    this.themes = const [],
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final List<CatalogThemeEntry> themes;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  VeloraState copyWith({
    List<CatalogThemeEntry>? themes,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearError = false,
  }) {
    return VeloraState(
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

  Future<void> loadThemes({bool force = false}) async {
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
    final outcome = await _api.fetchThemes(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
        loaded: false,
      );
      return;
    }
    final themes = List<CatalogThemeEntry>.from(outcome.data!)
      ..sort((a, b) => a.label.compareTo(b.label));
    state = state.copyWith(
      themes: themes,
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

final veloraProvider = NotifierProvider<VeloraNotifier, VeloraState>(
  VeloraNotifier.new,
);

class VeloraThemeBrowseState {
  const VeloraThemeBrowseState({
    this.seriesGroups = const [],
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final List<VeloraSeriesGroup> seriesGroups;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  VeloraThemeBrowseState copyWith({
    List<VeloraSeriesGroup>? seriesGroups,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearError = false,
  }) {
    return VeloraThemeBrowseState(
      seriesGroups: seriesGroups ?? this.seriesGroups,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class VeloraThemeBrowseNotifier
    extends FamilyNotifier<VeloraThemeBrowseState, String> {
  @override
  VeloraThemeBrowseState build(String themeCode) {
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
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchIndex(
      accessToken: token,
      theme: arg,
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
      seriesGroups: groupBySeries(outcome.data!.items),
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
    VeloraThemeBrowseNotifier, VeloraThemeBrowseState, String>(
  VeloraThemeBrowseNotifier.new,
);

/// Group circulating designs by seriesKey (single theme already filtered).
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
