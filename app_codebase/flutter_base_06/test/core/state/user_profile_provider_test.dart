import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arcori/core/http/contracts/user_api_contract.dart';
import 'package:arcori/core/http/media_url.dart';
import 'package:arcori/core/ws/ws_config.dart';
import 'package:arcori/core/state/auth/auth_providers.dart';
import 'package:arcori/core/state/auth/auth_state.dart';
import 'package:arcori/core/state/auth/contracts/auth_storage_contract.dart';
import 'package:arcori/core/state/user/user_profile_provider.dart';

class _MemoryAuthStorage implements AuthStorageContract {
  @override
  Future<void> clear() async {}

  @override
  Future<StoredAuthSession?> read() async => null;

  @override
  Future<void> write({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {}
}

class _FakeUserApi implements UserApiContract {
  UserProfile profile = const UserProfile(
    userId: 'user-1',
    username: 'testuser',
    email: 'test@example.com',
    isGuest: false,
    accountType: 'Regular',
    avatarUrl: '/media/avatars/user-1.webp',
  );

  int fetchCalls = 0;
  int uploadCalls = 0;

  @override
  Future<UserApiOutcome<UserProfile>> fetchProfile({
    required String accessToken,
  }) async {
    fetchCalls++;
    return UserApiOutcome.success(profile);
  }

  @override
  Future<UserApiOutcome<AvatarUploadResult>> uploadAvatar({
    required String accessToken,
    required List<int> bytes,
    required String filename,
  }) async {
    uploadCalls++;
    profile = UserProfile(
      userId: profile.userId,
      username: profile.username,
      email: profile.email,
      isGuest: profile.isGuest,
      emailVerified: profile.emailVerified,
      accountType: profile.accountType,
      avatarUrl: '/media/avatars/user-1.webp',
    );
    return UserApiOutcome.success(
      AvatarUploadResult(avatarUrl: profile.avatarUrl!, profile: profile),
    );
  }

  @override
  Future<UserApiOutcome<UserProfile>> deleteAvatar({
    required String accessToken,
  }) async {
    profile = UserProfile(
      userId: profile.userId,
      username: profile.username,
      email: profile.email,
      isGuest: profile.isGuest,
      emailVerified: profile.emailVerified,
      accountType: profile.accountType,
    );
    return UserApiOutcome.success(profile);
  }

  @override
  Future<UserApiOutcome<bool>> resendEmailVerification({
    required String accessToken,
  }) async {
    return const UserApiOutcome.success(true);
  }
}

void main() {
  group('UserProfile', () {
    test('fromJson maps account_type and avatar_url', () {
      final profile = UserProfile.fromJson({
        'user_id': 'abc',
        'username': 'alice',
        'email': 'alice@example.com',
        'is_guest': true,
        'account_type': 'Guest',
        'avatar_url': '/media/avatars/abc.webp',
      });
      expect(profile.accountType, 'Guest');
      expect(profile.avatarUrl, '/media/avatars/abc.webp');
    });
  });

  group('resolveMediaUrl', () {
    test('prefixes relative media path with api base', () {
      final url = resolveMediaUrl('/media/avatars/u.webp');
      expect(url.contains('/media/avatars/u.webp'), isTrue);
      if (WsConfig.apiRestBase.isNotEmpty) {
        expect(url.startsWith('http'), isTrue);
      }
    });
  });

  group('UserProfileNotifier', () {
    test('refresh loads profile when authenticated', () async {
      final api = _FakeUserApi();
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          userApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider.notifier).state = const AuthState(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'user-1',
        sessionStatus: SessionStatus.authenticated,
      );

      await container.read(userProfileProvider.notifier).refresh();
      final state = container.read(userProfileProvider);
      expect(state.profile?.username, 'testuser');
      expect(state.profile?.accountType, 'Regular');
      expect(api.fetchCalls, greaterThanOrEqualTo(1));
    });

    test('uploadAvatar updates profile', () async {
      final api = _FakeUserApi()
        ..profile = const UserProfile(
          userId: 'user-1',
          username: 'testuser',
          email: 'test@example.com',
          isGuest: false,
          accountType: 'Regular',
        );
      final container = ProviderContainer(
        overrides: [
          authStorageProvider.overrideWithValue(_MemoryAuthStorage()),
          userApiClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider.notifier).state = const AuthState(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'user-1',
        sessionStatus: SessionStatus.authenticated,
      );

      final ok = await container.read(userProfileProvider.notifier).uploadAvatar(
            bytes: utf8.encode('fake'),
            filename: 'avatar.png',
          );
      expect(ok, isTrue);
      expect(container.read(userProfileProvider).profile?.avatarUrl, isNotNull);
      expect(api.uploadCalls, 1);
    });
  });
}
