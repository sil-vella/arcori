import '../../errors/api_error.dart';

/// Result of a user profile API call.
class UserApiOutcome<T> {
  const UserApiOutcome._({
    this.value,
    this.error,
    this.isNetworkError = false,
  });

  const UserApiOutcome.success(T value) : this._(value: value);

  const UserApiOutcome.failure({required ApiError error})
      : this._(error: error);

  const UserApiOutcome.networkFailure() : this._(isNetworkError: true);

  final T? value;
  final ApiError? error;
  final bool isNetworkError;

  bool get isSuccess => value != null;
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.username,
    required this.email,
    required this.isGuest,
    required this.accountType,
    this.emailVerified = false,
    this.avatarUrl,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isGuest: json['is_guest'] == true,
      emailVerified: json['email_verified'] == true,
      accountType: json['account_type']?.toString() ??
          (json['is_guest'] == true ? 'Guest' : 'Regular'),
      avatarUrl: json['avatar_url']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  final String userId;
  final String username;
  final String email;
  final bool isGuest;
  final bool emailVerified;
  final String accountType;
  final String? avatarUrl;
  final String? createdAt;
}

class AvatarUploadResult {
  const AvatarUploadResult({
    required this.avatarUrl,
    required this.profile,
  });

  factory AvatarUploadResult.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResult(
      avatarUrl: json['avatar_url']?.toString() ?? '',
      profile: UserProfile.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final String avatarUrl;
  final UserProfile profile;
}

abstract interface class UserApiContract {
  Future<UserApiOutcome<UserProfile>> fetchProfile({
    required String accessToken,
  });

  Future<UserApiOutcome<AvatarUploadResult>> uploadAvatar({
    required String accessToken,
    required List<int> bytes,
    required String filename,
  });

  Future<UserApiOutcome<UserProfile>> deleteAvatar({
    required String accessToken,
  });

  Future<UserApiOutcome<bool>> resendEmailVerification({
    required String accessToken,
  });
}
