import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../http/contracts/user_api_contract.dart';
import '../../http/user_api_client.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_state.dart';

final userApiClientProvider = Provider<UserApiContract>(
  (ref) => UserApiClient(),
);

class UserProfileState {
  const UserProfileState({
    this.profile,
    this.isLoading = false,
    this.isUploading = false,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool isLoading;
  final bool isUploading;
  final String? errorMessage;

  UserProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isUploading,
    String? errorMessage,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return UserProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfileState> {
  @override
  UserProfileState build() {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!next.isAuthenticated || next.isGuest) {
        state = const UserProfileState();
        return;
      }
      if (previous?.userId != next.userId ||
          previous?.isGuest != next.isGuest ||
          (previous != null && !previous.isAuthenticated && next.isAuthenticated)) {
        refresh();
      }
    });
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && !auth.isGuest) {
      Future.microtask(refresh);
    }
    return const UserProfileState();
  }

  UserApiContract get _api => ref.read(userApiClientProvider);

  String? get _accessToken => ref.read(authProvider).accessToken;

  Future<void> refresh() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) {
      state = const UserProfileState();
      return;
    }
    final token = _accessToken;
    if (token == null || token.isEmpty) {
      state = const UserProfileState();
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    final outcome = await _api.fetchProfile(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _messageForFailure(outcome),
      );
      return;
    }
    state = UserProfileState(profile: outcome.value, isLoading: false);
  }

  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) return false;
    final token = _accessToken;
    if (token == null || token.isEmpty) return false;
    state = state.copyWith(isUploading: true, clearError: true);
    final outcome = await _api.uploadAvatar(
      accessToken: token,
      bytes: bytes,
      filename: filename,
    );
    if (!outcome.isSuccess) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: _messageForFailure(outcome),
      );
      return false;
    }
    state = UserProfileState(
      profile: outcome.value!.profile,
      isUploading: false,
    );
    return true;
  }

  Future<bool> resendEmailVerification() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) return false;
    final token = _accessToken;
    if (token == null || token.isEmpty) return false;
    final outcome = await _api.resendEmailVerification(accessToken: token);
    if (!outcome.isSuccess) {
      state = state.copyWith(errorMessage: _messageForFailure(outcome));
      return false;
    }
    state = state.copyWith(clearError: true);
    return true;
  }

  String _messageForFailure(UserApiOutcome<dynamic> outcome) {
    if (outcome.isNetworkError) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return outcome.error?.message ?? 'Request failed';
  }
}

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, UserProfileState>(
  UserProfileNotifier.new,
);
