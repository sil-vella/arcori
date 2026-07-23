import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/http/media_url.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/state/user/user_profile_provider.dart';
import '../../../core/theme/theme.dart';

const int _avatarMaxUploadBytes = 2 * 1024 * 1024;
const Set<String> _allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};

/// Profile header with avatar, username, email, and account type (full accounts only).
class AccountProfileCard extends ConsumerWidget {
  const AccountProfileCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated || auth.isGuest) return const SizedBox.shrink();

    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;

    return Container(
      margin: AppSpacing.screenPaddingCompact.copyWith(top: AppSpacing.md),
      padding: AppSpacing.screenPaddingCompact,
      decoration: BoxDecoration(
        color: context.appColorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        border: Border.all(color: context.appColorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (profileState.isLoading && profile == null)
            const Center(child: CircularProgressIndicator())
          else if (profile != null)
            _ProfileBody(
              username: profile.username,
              email: profile.email,
              accountType: profile.accountType,
              avatarUrl: profile.avatarUrl,
              isUploading: profileState.isUploading,
              onAvatarTap: () => _pickAndUploadAvatar(context, ref),
            )
          else
            Text(
              profileState.errorMessage ?? 'Could not load profile',
              style: context.appTypography.body.copyWith(
                color: context.appColors.red,
              ),
            ),
          if (profileState.errorMessage != null && profile != null) ...[
            AppSpacing.gapSm,
            Text(
              profileState.errorMessage!,
              style: context.appTypography.bodySmall.copyWith(
                color: context.appColors.red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null) return;

    final bytes = await _readPickedImageBytes(picked);
    var filename = picked.name.isNotEmpty ? picked.name : 'avatar.jpg';
    if (!_allowedExtensions.contains(_extensionForFilename(filename))) {
      filename = '$filename.jpg';
    }
    final ext = _extensionForFilename(filename);
    if (bytes.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected image')),
        );
      }
      return;
    }
    if (!_allowedExtensions.contains(ext)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPEG, PNG, and WebP images are allowed'),
          ),
        );
      }
      return;
    }
    if (bytes.length > _avatarMaxUploadBytes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image exceeds maximum size (2 MB)')),
        );
      }
      return;
    }

    await ref.read(userProfileProvider.notifier).uploadAvatar(
          bytes: bytes,
          filename: filename,
        );
  }

  String _extensionForFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0) return '.jpg';
    return filename.substring(dot).toLowerCase();
  }

  Future<List<int>> _readPickedImageBytes(XFile picked) async {
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}
    final path = picked.path;
    if (path.isNotEmpty) {
      return File(path).readAsBytes();
    }
    return const [];
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.username,
    required this.email,
    required this.accountType,
    required this.avatarUrl,
    required this.isUploading,
    required this.onAvatarTap,
  });

  final String username;
  final String email;
  final String accountType;
  final String? avatarUrl;
  final bool isUploading;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = resolveMediaUrl(avatarUrl);
    final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isUploading ? null : onAvatarTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.appColorScheme.secondaryContainer,
                backgroundImage:
                    resolvedUrl.isNotEmpty ? NetworkImage(resolvedUrl) : null,
                child: resolvedUrl.isEmpty
                    ? Text(initials, style: context.appTypography.title)
                    : null,
              ),
              if (isUploading)
                Positioned.fill(
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.black38,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: context.appColorScheme.primary,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    size: 16,
                    color: context.appColorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        AppSpacing.gapMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(username, style: context.appTypography.subtitle),
              AppSpacing.gapXxs,
              Text(email, style: context.appTypography.bodyMuted),
              AppSpacing.gapSm,
              _AccountTypeChip(label: accountType),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTypeChip extends StatelessWidget {
  const _AccountTypeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isGuest = label.toLowerCase() == 'guest';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: isGuest
            ? context.appColorScheme.secondaryContainer
            : context.appColorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppButtonMetrics.radius),
        border: Border.all(color: context.appColorScheme.outline),
      ),
      child: Text(
        label,
        style: context.appTypography.bodySmall,
      ),
    );
  }
}
