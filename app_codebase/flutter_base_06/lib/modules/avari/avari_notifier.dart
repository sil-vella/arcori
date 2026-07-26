import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_policy.dart';
import '../../core/state/auth/auth_providers.dart';
import 'avari_api.dart';
import 'avari_models.dart';

final avariApiClientProvider = Provider<AvariApiClient>(
  (ref) => AvariApiClient(),
);

class AvariProfileState {
  const AvariProfileState({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
    this.loaded = false,
  });

  final AvariProfile? profile;
  final bool isLoading;
  final String? errorMessage;
  final bool loaded;

  AvariProfileState copyWith({
    AvariProfile? profile,
    bool? isLoading,
    String? errorMessage,
    bool? loaded,
    bool clearProfile = false,
    bool clearError = false,
  }) {
    return AvariProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      loaded: loaded ?? this.loaded,
    );
  }
}

class AvariProfileNotifier extends Notifier<AvariProfileState> {
  @override
  AvariProfileState build() {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        state = const AvariProfileState();
      }
    });
    return const AvariProfileState();
  }

  AvariApiClient get _api => ref.read(avariApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> load({bool force = false}) async {
    if (!force && state.loaded && state.errorMessage == null) {
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Sign in to view your Avari profile',
        loaded: false,
        clearProfile: true,
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchProfile(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForOutcome(outcome),
        loaded: false,
      );
      return;
    }
    state = state.copyWith(
      profile: outcome.data,
      isLoading: false,
      loaded: true,
      clearError: true,
    );
  }

  String? _messageForOutcome(AvariApiOutcome<dynamic> outcome) {
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

final avariProfileProvider =
    NotifierProvider<AvariProfileNotifier, AvariProfileState>(
  AvariProfileNotifier.new,
);
