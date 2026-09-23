import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/navigation/app_router.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../../avari/avari_models.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/practice_ai_pool.dart';
import '../../match/state/match_notifier.dart';
import '../../match/state/match_snapshot_state.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../play_models.dart';
import '../play_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Single post-match shell: celebration stubs + summary + actions.
Future<void> showPostMatchModal(BuildContext context, WidgetRef ref) {
  return AppModal.showCentered<void>(
    context,
    barrierDismissible: false,
    builder: (ctx) => Theme(
      data: AppTheme.dark,
      child: const AppCenteredModal(
        title: 'Match complete',
        showCloseButton: false,
        child: _PostMatchBody(),
      ),
    ),
  );
}

class _PostMatchBody extends ConsumerStatefulWidget {
  const _PostMatchBody();

  @override
  ConsumerState<_PostMatchBody> createState() => _PostMatchBodyState();
}

class _PostMatchBodyState extends ConsumerState<_PostMatchBody> {
  bool _exiting = false;
  /// Absorb residual slam/pointer-up so it cannot tap Done the frame we open.
  bool _actionsArmed = false;

  /// Freeze at open so late WS / clear races cannot swap in a prior match.
  MatchSnapshotState? _frozenSnap;
  Map<String, Map<String, int>> _frozenFlipsByActor = const {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final snap = ref.read(matchSnapshotProvider);
      final flips =
          ref.read(matchFlowProvider.notifier).flipsByActorDesignSnapshot();
      setState(() {
        _frozenSnap = snap;
        _frozenFlipsByActor = flips;
      });
      if (LOGGING_SWITCH) {
        customlog(
          'postMatchModal: freeze matchId=${snap.matchId} '
          'phase=${snap.phase} seats=${snap.seats.length} '
          'type=${snap.matchType} flipActors=${flips.length}',
        );
      }
      unawaited(
        ref.read(matchFlowProvider.notifier).requestPostMatchFinalize(),
      );
    });
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || _exiting) return;
      setState(() => _actionsArmed = true);
    });
  }

  Future<void> _exit(void Function() complete) async {
    if (_exiting) return;
    _exiting = true;
    // Dismiss before completing so Play New does not stack lobby/match under
    // a still-visible post-match shell.
    if (mounted) {
      AppModal.dismiss(context);
    }
    complete();
  }

  /// Done: close summary → idle (unlock/daily/legacy via NotificationHost).
  Future<void> _done() async {
    if (_exiting) return;
    await _exit(() {
      ref.read(matchFlowProvider.notifier).completePostMatchDone();
    });
  }

  /// Exit like Done, then open Tasks (not used on Rematch).
  Future<void> _viewDaily() async {
    if (_exiting) return;
    await _exit(() {
      ref.read(matchFlowProvider.notifier).completePostMatchDone();
    });
    final rootCtx = appRootNavigatorKey.currentContext;
    if (rootCtx != null && rootCtx.mounted) {
      Nav.go(rootCtx, AppPaths.tasks);
    }
  }

  void _playNew() {
    unawaited(_exit(() {
      ref.read(matchFlowProvider.notifier).completePostMatchPlayNew();
    }));
  }

  void _rematch() {
    final flow = ref.read(matchFlowProvider.notifier);
    if (!flow.rematchAvailable()) return;
    unawaited(_exit(() {
      flow.completePostMatchRematch();
    }));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchFlowProvider, (prev, next) {
      if (_exiting) return;
      if (prev?.phase == MatchFlowPhase.postMatch &&
          next.phase != MatchFlowPhase.postMatch &&
          context.mounted) {
        if (LOGGING_SWITCH) {
          customlog('postMatchModal: auto-dismiss phase=${next.phase.name}');
        }
        AppModal.dismiss(context);
      }
    });

    final live = ref.watch(matchSnapshotProvider);
    final snap = _frozenSnap ?? live;
    final flow = ref.watch(matchFlowProvider);
    final notifier = ref.read(matchFlowProvider.notifier);
    final rematchOk = notifier.rematchAvailable();
    final rematchReason = notifier.rematchDisabledReason();
    final userId = ref.watch(authProvider).userId?.trim() ?? '';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Celebration & mastery animations — soon',
            style: context.appTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceMutedDark,
            ),
          ),
          AppSpacing.gapSm,
          _RewardRow(
            finalize: flow.postMatchFinalize,
          ),
          AppSpacing.gapMd,
          Text(
            'Results',
            style: context.appTypography.label.copyWith(
              color: AppColors.onSurfaceDark,
            ),
          ),
          AppSpacing.gapXs,
          _CombinedResultsBlock(
            snap: snap,
            localUserId: userId,
            flipsByActorDesign: _frozenFlipsByActor,
            finalize: flow.postMatchFinalize,
          ),
          AppSpacing.gapMd,
          Text(
            'Daily',
            style: context.appTypography.label.copyWith(
              color: AppColors.onSurfaceDark,
            ),
          ),
          AppSpacing.gapXs,
          _DailyProgressBlock(daily: flow.postMatchFinalize?.daily),
          AppSpacing.gapSm,
          OutlinedButton(
            style: context.appButtons.tertiary.outlined,
            onPressed: !_exiting && _actionsArmed
                ? () => unawaited(_viewDaily())
                : null,
            child: const Text('View Daily'),
          ),
          if (flow.postMatchFinalize?.eventProgress != null) ...[
            AppSpacing.gapMd,
            Text(
              'Event',
              style: context.appTypography.label.copyWith(
                color: AppColors.onSurfaceDark,
              ),
            ),
            AppSpacing.gapXs,
            _EventProgressBlock(
              progress: flow.postMatchFinalize!.eventProgress!,
            ),
          ],
          if (flow.postMatchSoftError != null &&
              flow.postMatchSoftError!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              flow.postMatchSoftError!,
              style: context.appTypography.bodySmall.copyWith(
                color: context.appColors.red,
              ),
            ),
          ],
          AppSpacing.gapLg,
          FilledButton(
            style: context.appButtons.primary.filled,
            onPressed:
                rematchOk && !_exiting && _actionsArmed ? _rematch : null,
            child: const Text('Rematch'),
          ),
          if (!rematchOk && rematchReason != null) ...[
            AppSpacing.gapXs,
            Text(
              rematchReason,
              style: context.appTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceMutedDark,
              ),
            ),
          ],
          AppSpacing.gapSm,
          FilledButton(
            style: context.appButtons.secondary.filled,
            onPressed: !_exiting && _actionsArmed ? _playNew : null,
            child: const Text('Play New'),
          ),
          AppSpacing.gapSm,
          OutlinedButton(
            style: context.appButtons.tertiary.outlined,
            onPressed: !_exiting && _actionsArmed
                ? () => unawaited(_done())
                : null,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({this.finalize});

  final MatchFinalizeResult? finalize;

  @override
  Widget build(BuildContext context) {
    final applied = finalize?.applied == true;
    final net = finalize?.goldFragmentsDelta ?? 0;
    final fee = finalize?.feeFragments ?? 0;
    final flips = finalize?.flipsRewarded ?? 0;
    final fragLabel = applied
        ? '${net >= 0 ? '+' : ''}$net Fragments'
        : (finalize?.reason == 'practice'
            ? 'Practice — no economy'
            : '+0 Fragments');
    final detail = applied && (fee > 0 || flips > 0)
        ? 'flips +$flips · fee −$fee'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Chip(
              label: Text(
                fragLabel,
                style: context.appTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
              ),
              backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.7),
              side: BorderSide(
                color: AppSurfaces.frameGold(Brightness.dark)
                    .withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        if (detail != null) ...[
          AppSpacing.gapXs,
          Text(
            detail,
            style: context.appTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceMutedDark,
            ),
          ),
        ],
        if (applied &&
            (finalize?.achievementsUnlocked.isNotEmpty ?? false)) ...[
          AppSpacing.gapSm,
          Text(
            'Achievements',
            style: context.appTypography.label.copyWith(
              color: AppColors.onSurfaceDark,
            ),
          ),
          AppSpacing.gapXs,
          for (final ach in finalize!.achievementsUnlocked)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Text(
                '• ${ach.achievementName}',
                style: context.appTypography.bodySmall.copyWith(
                  color: AppColors.onSurfaceMutedDark,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _CombinedResultsBlock extends StatelessWidget {
  const _CombinedResultsBlock({
    required this.snap,
    required this.localUserId,
    required this.flipsByActorDesign,
    this.finalize,
  });

  final MatchSnapshotState snap;
  final String localUserId;
  final Map<String, Map<String, int>> flipsByActorDesign;
  final MatchFinalizeResult? finalize;

  @override
  Widget build(BuildContext context) {
    final seats = [...snap.seats]
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    if (seats.isEmpty) {
      return Text('No seat data', style: context.appTypography.bodySmall);
    }

    final masteryByDesign = <String, MasteryChange>{
      for (final m in finalize?.masteryChanges ?? const <MasteryChange>[])
        if (m.designId.trim().isNotEmpty) m.designId.trim(): m,
    };
    final applied = finalize?.applied == true;
    final practice = finalize?.reason == 'practice';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final seat in seats) ...[
          Builder(
            builder: (context) {
              final byDesign = _flipsForSeat(seat);
              final total = byDesign.isNotEmpty
                  ? byDesign.values.fold<int>(0, (a, b) => a + b)
                  : seat.score;
              return _PlayerResults(
                snap: snap,
                seat: seat,
                playerLabel: _seatLabel(seat),
                totalFlips: total,
                flipsByDesign: byDesign,
                masteryByDesign:
                    _isLocalSeat(seat) ? masteryByDesign : const {},
                showMasteryPending: _isLocalSeat(seat) &&
                    finalize != null &&
                    !applied &&
                    !practice,
                practiceNoMastery: _isLocalSeat(seat) && practice,
              );
            },
          ),
          if (seat != seats.last) AppSpacing.gapMd,
        ],
      ],
    );
  }

  bool _isLocalSeat(MatchSeatView seat) {
    final uid = seat.userId.trim();
    if (localUserId.isNotEmpty && uid == localUserId) return true;
    if (seat.kind == 'human' &&
        (uid == 'local' || uid.isEmpty || localUserId.isEmpty)) {
      return seat.seatIndex == 0 || uid == 'local';
    }
    return false;
  }

  Map<String, int> _flipsForSeat(MatchSeatView seat) {
    final uid = seat.userId.trim();
    final direct = flipsByActorDesign[uid];
    if (direct != null && direct.isNotEmpty) {
      return Map<String, int>.from(direct);
    }
    if (_isLocalSeat(seat)) {
      final local = flipsByActorDesign['local'];
      if (local != null && local.isNotEmpty) {
        return Map<String, int>.from(local);
      }
      if (localUserId.isNotEmpty) {
        final mine = flipsByActorDesign[localUserId];
        if (mine != null && mine.isNotEmpty) {
          return Map<String, int>.from(mine);
        }
      }
    }
    return const {};
  }

  String _seatLabel(MatchSeatView seat) {
    final isYou = _isLocalSeat(seat);
    final fromSeat = seat.username?.trim() ?? '';
    if (fromSeat.isNotEmpty) {
      return isYou ? '$fromSeat (you)' : fromSeat;
    }
    if (seat.kind == 'ai') {
      return practiceAiUsernameFor(seat.userId);
    }
    if (isYou) return 'You';
    final id = seat.userId.trim();
    if (id.isEmpty) return 'Player';
    return id.length <= 8 ? id : id.substring(0, 8);
  }
}

class _PlayerResults extends StatelessWidget {
  const _PlayerResults({
    required this.snap,
    required this.seat,
    required this.playerLabel,
    required this.totalFlips,
    required this.flipsByDesign,
    required this.masteryByDesign,
    this.showMasteryPending = false,
    this.practiceNoMastery = false,
  });

  final MatchSnapshotState snap;
  final MatchSeatView seat;
  final String playerLabel;
  final int totalFlips;
  final Map<String, int> flipsByDesign;
  final Map<String, MasteryChange> masteryByDesign;
  final bool showMasteryPending;
  final bool practiceNoMastery;

  @override
  Widget build(BuildContext context) {
    final designIds = <String>{
      ...flipsByDesign.keys.where((k) => (flipsByDesign[k] ?? 0) > 0),
      ...masteryByDesign.keys,
    }.toList()
      ..sort((a, b) {
        final fa = flipsByDesign[a] ?? masteryByDesign[a]?.flips ?? 0;
        final fb = flipsByDesign[b] ?? masteryByDesign[b]?.flips ?? 0;
        final cmp = fb.compareTo(fa);
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SeatFace(snap: snap, seat: seat),
            AppSpacing.gapSm,
            Expanded(
              child: Text(
                playerLabel,
                style: context.appTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$totalFlips flip${totalFlips == 1 ? '' : 's'}',
              style: context.appTypography.h3,
            ),
          ],
        ),
        if (showMasteryPending) ...[
          AppSpacing.gapXs,
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'Waiting for mastery…',
              style: context.appTypography.bodySmall,
            ),
          ),
        ] else if (practiceNoMastery && designIds.isEmpty) ...[
          AppSpacing.gapXs,
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'Practice — no mastery',
              style: context.appTypography.bodySmall,
            ),
          ),
        ],
        if (designIds.isEmpty && !showMasteryPending) ...[
          AppSpacing.gapXs,
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              'No Arcori flipped',
              style: context.appTypography.bodySmall,
            ),
          ),
        ] else ...[
          AppSpacing.gapXs,
          for (final designId in designIds)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: AppSpacing.sm),
              child: _ArcoriResultRow(
                snap: snap,
                designId: designId,
                flips: flipsByDesign[designId] ??
                    masteryByDesign[designId]?.flips ??
                    0,
                mastery: masteryByDesign[designId],
              ),
            ),
        ],
      ],
    );
  }
}

class _ArcoriResultRow extends StatelessWidget {
  const _ArcoriResultRow({
    required this.snap,
    required this.designId,
    required this.flips,
    this.mastery,
  });

  final MatchSnapshotState snap;
  final String designId;
  final int flips;
  final MasteryChange? mastery;

  @override
  Widget build(BuildContext context) {
    final piece = _pieceFor(designId);
    final m = mastery;
    final lottieUrl = (m?.lottieUrl != null && m!.lottieUrl!.isNotEmpty)
        ? m.lottieUrl
        : piece?.lottieUrl;
    final useLottie = (lottieUrl ?? '').trim().isNotEmpty;
    final imageUrl = useLottie
        ? null
        : ((m?.imageUrl != null && m!.imageUrl!.isNotEmpty)
            ? m.imageUrl
            : piece?.imageUrl);
    final color = (m?.color != null && m!.color!.isNotEmpty)
        ? m.color
        : piece?.color;
    final name = (m?.displayName != null && m!.displayName!.trim().isNotEmpty)
        ? m.displayName!.trim()
        : _shortDesignLabel(designId);
    final kindLabel = m == null
        ? null
        : (m.kind == 'own' ? 'Own' : 'Other');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ArcoriCylinder(
          size: 40,
          look: ArcoriLook(
            designId: designId,
            imageUrl: imageUrl,
            colorHex: color,
          ),
          faceUp: true,
          showThickness: false,
          face: useLottie
              ? KinSceneStack(
                  lottieUrl: lottieUrl,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: context.appTypography.body,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                flips == 1 ? '1 flip' : '$flips flips',
                style: context.appTypography.bodySmall,
              ),
              if (m != null)
                Text(
                  'Mastery ${m.masteryOverMintReach}'
                  '${kindLabel != null ? ' · $kindLabel' : ''}'
                  ' · ${m.relativeDeltaLabel}',
                  style: context.appTypography.caption.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        // Always flip count here — mastery delta is labeled under the name.
        Text(
          '×$flips',
          style: context.appTypography.h3,
        ),
      ],
    );
  }

  MatchPieceView? _pieceFor(String id) {
    final want = id.trim();
    if (want.isEmpty) return null;
    for (final p in snap.pieces) {
      if (p.designId == want) return p;
    }
    return null;
  }

  String _shortDesignLabel(String id) {
    final raw = id.trim();
    if (raw.isEmpty) return 'Arcori';
    final parts = raw.split('-');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return parts[1];
    }
    return raw;
  }
}

class _DailyProgressBlock extends StatelessWidget {
  const _DailyProgressBlock({this.daily});

  final Map<String, dynamic>? daily;

  @override
  Widget build(BuildContext context) {
    final payload = daily;
    if (payload == null || payload.isEmpty) {
      return Text(
        'No daily progress this match',
        style: context.appTypography.bodySmall,
      );
    }

    final goalsRaw = payload['goals'];
    final lines = <String>[];
    String? cacheLine;
    if (goalsRaw is List) {
      for (final item in goalsRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final id = (map['goalId'] ?? map['goal_id'] ?? '').toString().trim();
        final type =
            (map['taskType'] ?? map['task_type'] ?? '').toString().toLowerCase();
        final featured = map['featured'] == true;
        final progress = map['progressToday'] ?? map['progress_today'] ?? 0;
        final target = map['target'] ?? 1;
        final done = map['completedToday'] == true ||
            map['completed_today'] == true;
        final name = (map['name']?.toString().trim().isNotEmpty == true)
            ? map['name'].toString().trim()
            : (id.isEmpty ? 'Daily goal' : id.replaceAll('_', ' '));

        if (type == 'claim_gate' || id == 'daily_mystery_box') {
          final cacheStatus = done
              ? 'claimed'
              : _cacheReadyFromPayload(goalsRaw)
                  ? 'ready'
                  : 'locked';
          cacheLine = '$name — $cacheStatus';
          continue;
        }

        if (!featured) continue;
        final label = done ? 'Done' : '$progress / $target';
        lines.add('$name — $label');
      }
    }

    if (lines.isEmpty && cacheLine == null) {
      return Text(
        'Daily goals updated',
        style: context.appTypography.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(line, style: context.appTypography.bodySmall),
          ),
        if (cacheLine != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Text(cacheLine, style: context.appTypography.bodySmall),
          ),
      ],
    );
  }

  /// Gate ready when known featured requires are completedToday.
  static bool _cacheReadyFromPayload(List goalsRaw) {
    const fallbackRequires = ['play_one_match', 'land_three_flips'];
    final doneById = <String, bool>{};
    for (final item in goalsRaw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final id = (m['goalId'] ?? m['goal_id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      doneById[id] = m['completedToday'] == true || m['completed_today'] == true;
    }
    for (final id in fallbackRequires) {
      if (doneById[id] != true) return false;
    }
    return true;
  }
}

class _EventProgressBlock extends StatelessWidget {
  const _EventProgressBlock({required this.progress});

  final Map<String, dynamic> progress;

  @override
  Widget build(BuildContext context) {
    final credited = progress['matchesCredited'] ?? progress['matches_credited'] ?? 0;
    final required =
        progress['matchesRequired'] ?? progress['matches_required'] ?? 1;
    final flips = progress['flips'] ?? 0;
    final eid = progress['eventId'] ?? progress['event_id'] ?? '';
    return Text(
      '${eid.toString().isEmpty ? 'Event' : eid}: '
      '$credited/$required matches credited · $flips flips',
      style: context.appTypography.bodySmall,
    );
  }
}

class _SeatFace extends StatelessWidget {
  const _SeatFace({required this.snap, required this.seat});

  final MatchSnapshotState snap;
  final MatchSeatView seat;

  @override
  Widget build(BuildContext context) {
    MatchPieceView? piece;
    for (final p in snap.pieces) {
      if (p.seatIndex == seat.seatIndex) {
        piece = p;
        break;
      }
    }
    final designId = piece?.designId.isNotEmpty == true
        ? piece!.designId
        : (seat.arcoriIds.isNotEmpty ? seat.arcoriIds.first : 'unknown');
    final useLottie = piece?.hasLottieFace == true;
    return ArcoriCylinder(
      size: 40,
      look: ArcoriLook(
        designId: designId,
        imageUrl: useLottie ? null : piece?.imageUrl,
        colorHex: piece?.color,
      ),
      faceUp: true,
      showThickness: false,
      face: useLottie
          ? KinSceneStack(
              lottieUrl: piece!.lottieUrl,
              fit: BoxFit.cover,
            )
          : null,
    );
  }
}
