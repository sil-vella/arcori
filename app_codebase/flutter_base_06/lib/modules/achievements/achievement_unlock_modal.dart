import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/http/media_url.dart';
import '../../core/modal/modal.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'achievements_catalog_store.dart';
import 'achievements_models.dart';
import 'post_achieve_action_executor.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Sequential unlock celebrations (AppModal shells) — kept for non-notify paths.
Future<void> showAchievementUnlockSequence(
  BuildContext context, {
  required List<AchievementEntry> unlocked,
}) async {
  if (unlocked.isEmpty) return;
  AchievementsCatalogStore.markUnlocked(unlocked.map((e) => e.id));

  for (final entry in unlocked) {
    if (!context.mounted) return;
    if (LOGGING_SWITCH) {
      customlog('achievements: celebrate id=${entry.id}');
    }
    await AppModal.showCenteredShell<void>(
      context,
      title: 'Achievement unlocked',
      barrierDismissible: false,
      showCloseButton: false,
      child: AchievementUnlockCelebrateBody(
        entry: entry,
        onContinue: () async {
          AppModal.dismiss(context);
          final action = entry.postAchieveAction;
          final hasNav = action.type != PostAchieveActionTypes.none &&
              ((action.screen?.isNotEmpty ?? false) ||
                  (action.toPath?.isNotEmpty ?? false));
          if (hasNav && context.mounted) {
            await executePostAchieveAction(
              context: context,
              action: action,
            );
          }
        },
        onDismiss: () => AppModal.dismiss(context),
      ),
    );
  }
}

AchievementEntry? achievementEntryFromNotificationData(
  Map<String, dynamic> data,
) {
  final raw = data['achievement'];
  if (raw is! Map) return null;
  final entry = AchievementEntry.fromJson(Map<String, dynamic>.from(raw));
  if (entry.id.isEmpty) return null;
  return entry;
}

/// Rich celebrate body (media + title + description + optional CTAs).
class AchievementUnlockCelebrateBody extends StatelessWidget {
  const AchievementUnlockCelebrateBody({
    required this.entry,
    this.onContinue,
    this.onDismiss,
    this.actions,
    super.key,
  });

  final AchievementEntry entry;

  /// When set (legacy sequence), builds Continue/Dismiss from post-achieve action.
  final Future<void> Function()? onContinue;
  final VoidCallback? onDismiss;

  /// When set (notification host), replaces default CTA row.
  final List<Widget>? actions;

  CatalogMediaRef? get _animatedBackground {
    final flat = entry.mediaSlot('animated_background') ??
        entry.mediaSlot('animatedBackground');
    if (flat != null && flat.isValid) return flat;
    final post = entry.postTaskMedia('animation') ??
        entry.postTaskMedia('animated_background') ??
        entry.postTaskMedia('primary');
    if (post != null && post.isValid) return post;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = entry.postAchieveAction;
    final cta = action.ctaLabel.trim().isEmpty ? 'Continue' : action.ctaLabel;
    final hasNav = action.type != PostAchieveActionTypes.none &&
        ((action.screen?.isNotEmpty ?? false) ||
            (action.toPath?.isNotEmpty ?? false));
    final anim = _animatedBackground;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _UnlockMedia(ref: anim),
          ),
        ),
        AppSpacing.gapSm,
        Text(
          entry.achievementName,
          style: context.appTypography.h3,
          textAlign: TextAlign.center,
        ),
        AppSpacing.gapXs,
        Text(
          entry.description,
          style: context.appTypography.body,
          textAlign: TextAlign.center,
        ),
        if (actions != null) ...[
          AppSpacing.gapLg,
          ...actions!,
        ] else if (onContinue != null || onDismiss != null) ...[
          AppSpacing.gapLg,
          if (hasNav && onContinue != null)
            FilledButton(
              onPressed: () => unawaited(onContinue!()),
              child: Text(cta),
            ),
          if (hasNav && onContinue != null) AppSpacing.gapSm,
          if (onDismiss != null)
            OutlinedButton(
              onPressed: onDismiss,
              child: Text(hasNav ? 'Dismiss' : cta),
            ),
        ],
      ],
    );
  }
}


/// Renders catalog media using existing resolve + Lottie/image helpers only.
class _UnlockMedia extends StatelessWidget {
  const _UnlockMedia({this.ref});

  final CatalogMediaRef? ref;

  @override
  Widget build(BuildContext context) {
    final media = ref;
    if (media == null || !media.isValid) {
      return ColoredBox(
        color: context.appColorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.emoji_events,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    final url = resolveMediaUrl(media.value);
    if (url.isEmpty) {
      return Icon(
        Icons.emoji_events,
        size: 48,
        color: context.appColorScheme.primary,
      );
    }

    if (media.type == 'lottie') {
      if (isBundleAssetMedia(media.value)) {
        return Lottie.asset(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.emoji_events,
            size: 48,
            color: context.appColorScheme.primary,
          ),
        );
      }
      return Lottie.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.emoji_events,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    if (media.type == 'image') {
      if (isBundleAssetMedia(media.value)) {
        return Image.asset(url, fit: BoxFit.cover);
      }
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.emoji_events,
          size: 48,
          color: context.appColorScheme.primary,
        ),
      );
    }

    return Icon(
      Icons.emoji_events,
      size: 48,
      color: context.appColorScheme.primary,
    );
  }
}
