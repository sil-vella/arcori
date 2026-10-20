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
import '../../avari/avari_notifier.dart';
import '../../kin/widgets/kin_lottie_preview.dart';
import '../../match/input/slam_resolver.dart';
import '../../match/practice_ai_pool.dart';
import '../../match/state/match_notifier.dart';
import '../../match/state/match_snapshot_state.dart';
import '../../match/widgets/arcori_cylinder.dart';
import '../../match/widgets/arcori_look.dart';
import '../../match/widgets/slam_result_modal.dart';
import '../play_models.dart';
import '../play_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Single post-match shell: celebration stubs + summary + actions.
///
/// If the last turn's flip/miss card is up, this route is installed under it.
/// Close or the card's timer reveals the summary already behind it.
Future<void> showPostMatchModal(BuildContext context, WidgetRef ref) async {
  final front = await SlamResultFront.frontRoute();
  if (!context.mounted) return;
  final nav = Navigator.of(context, rootNavigator: true);
  final route = _postMatchRoute(context);
  if (installRouteBehindFront(
    nav,
    route,
    keepInFront: front,
    shellUnder: SlamResultFront.shellRoute,
  )) {
    if (LOGGING_SWITCH) {
      customlog('postMatchModal: inserted behind slam result');
    }
    return route.popped;
  }
  if (front != null && front.isActive && front.isCurrent) {
    if (LOGGING_SWITCH) {
      customlog('postMatchModal: waiting for slam result to close');
    }
    await front.popped;
    if (!context.mounted) return;
    return nav.push<void>(_postMatchRoute(context));
  }
  if (LOGGING_SWITCH) {
    customlog('postMatchModal: show');
  }
  final shown = nav.push<void>(route);
  SlamResultFront.onReleased?.call();
  return shown;
}

Route<void> _postMatchRoute(BuildContext context) {
  return AppModal.centeredRoute<void>(
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
          _SlammerMasteryHero(
            snap: snap,
            localUserId: userId,
            finalize: flow.postMatchFinalize,
            ownedSlammers:
                ref.watch(avariProfileProvider).profile?.slammers ?? const [],
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
    return _isLocalMatchSeat(seat, localUserId);
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < designIds.length; i++) ...[
                  if (i > 0) AppSpacing.gapSm,
                  _ArcoriResultColumn(
                    snap: snap,
                    designId: designIds[i],
                    flips: flipsByDesign[designIds[i]] ??
                        masteryByDesign[designIds[i]]?.flips ??
                        0,
                    mastery: masteryByDesign[designIds[i]],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ArcoriResultColumn extends StatelessWidget {
  const _ArcoriResultColumn({
    required this.snap,
    required this.designId,
    required this.flips,
    this.mastery,
  });

  final MatchSnapshotState snap;
  final String designId;
  final int flips;
  final MasteryChange? mastery;

  static const double _width = 92;
  static const double _disc = 64;

  @override
  Widget build(BuildContext context) {
    final face = _ResolvedDisc.resolve(
      snap: snap,
      designId: designId,
      mastery: mastery,
    );
    return SizedBox(
      width: _width,
      child: InkWell(
        onTap: () {
          unawaited(
            AppModal.showCenteredShell(
              context,
              title: face.name,
              child: _ArcoriFocus(
                face: face,
                flips: flips,
                mastery: mastery,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              face.disc(_disc),
              AppSpacing.gapXxs,
              Text(
                face.name,
                style: context.appTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text(
                flips == 1 ? '1 flip' : '$flips flips',
                style: context.appTypography.caption.copyWith(
                  color: context.appColorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (mastery != null)
                Text(
                  '${mastery!.relativeDeltaLabel} · ${mastery!.masteryOverMintReach}',
                  style: context.appTypography.caption.copyWith(
                    color: AppSurfaces.frameGold(Brightness.dark),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcoriFocus extends StatelessWidget {
  const _ArcoriFocus({
    required this.face,
    required this.flips,
    this.mastery,
  });

  final _ResolvedDisc face;
  final int flips;
  final MasteryChange? mastery;

  @override
  Widget build(BuildContext context) {
    final kindLabel = mastery == null
        ? null
        : (mastery!.kind == 'own' ? 'Own' : 'Other');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(child: face.disc(220)),
        AppSpacing.gapSm,
        Text(
          flips == 1 ? '1 flip' : '$flips flips',
          style: context.appTypography.h3.copyWith(
            color: AppColors.onSurfaceDark,
          ),
          textAlign: TextAlign.center,
        ),
        if (mastery != null) ...[
          AppSpacing.gapXs,
          Text(
            'Mastery ${mastery!.masteryOverMintReach}'
            '${kindLabel != null ? ' · $kindLabel' : ''}'
            ' · ${mastery!.relativeDeltaLabel}',
            style: context.appTypography.body.copyWith(
              color: AppColors.onSurfaceDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ResolvedDisc {
  const _ResolvedDisc({
    required this.name,
    required this.designId,
    this.imageUrl,
    this.lottieUrl,
    this.color,
  });

  final String name;
  final String designId;
  final String? imageUrl;
  final String? lottieUrl;
  final String? color;

  bool get useLottie => (lottieUrl ?? '').trim().isNotEmpty;

  factory _ResolvedDisc.resolve({
    required MatchSnapshotState snap,
    required String designId,
    MasteryChange? mastery,
  }) {
    MatchPieceView? piece;
    final want = designId.trim();
    for (final p in snap.pieces) {
      if (p.designId == want) {
        piece = p;
        break;
      }
    }
    final lottie = _firstNonEmpty(mastery?.lottieUrl, piece?.lottieUrl);
    final image = lottie != null
        ? null
        : _firstNonEmpty(mastery?.imageUrl, piece?.imageUrl);
    final name = _firstNonEmpty(mastery?.displayName) ??
        _shortDesignLabel(designId);
    return _ResolvedDisc(
      name: name,
      designId: designId,
      imageUrl: image,
      lottieUrl: lottie,
      color: _firstNonEmpty(mastery?.color, piece?.color),
    );
  }

  Widget disc(double size) {
    return ArcoriCylinder(
      size: size,
      look: ArcoriLook(
        designId: designId,
        imageUrl: useLottie ? null : imageUrl,
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
    );
  }
}

class _SlammerMasteryHero extends StatelessWidget {
  const _SlammerMasteryHero({
    required this.snap,
    required this.localUserId,
    required this.ownedSlammers,
    this.finalize,
  });

  final MatchSnapshotState snap;
  final String localUserId;
  final MatchFinalizeResult? finalize;
  final List<AvariInventoryItem> ownedSlammers;

  static const double _disc = 112;

  @override
  Widget build(BuildContext context) {
    final seat = _localSeat();
    final changes = finalize?.slammerMasteryChanges ?? const <MasteryChange>[];
    final change = _changeForSeat(seat, changes);
    final owned = _ownedFor(seat, change);
    final slammerId = (change?.designId ?? seat?.slammerId ?? '').trim();
    if (slammerId.isEmpty && change == null && owned == null) {
      return const SizedBox.shrink();
    }

    final practice = finalize?.reason == 'practice';
    final pending = finalize == null ||
        (finalize!.applied != true && !practice);
    final face = _slammerFace(seat, change, owned, slammerId);
    final total = change?.masteryOverMintReach ??
        (practice || pending ? null : owned?.masteryOverMintReach);
    final gain = change?.relativeDeltaLabel;

    final gold = AppSurfaces.frameGold(Brightness.dark);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: gold.withValues(alpha: 0.65)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Text(
                'Slammer Mastery',
                style: context.appTypography.label.copyWith(color: gold),
              ),
              AppSpacing.gapSm,
              face.disc(_disc),
              AppSpacing.gapXs,
              Text(
                face.name,
                style: context.appTypography.subtitle.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
                textAlign: TextAlign.center,
              ),
              if (total != null) ...[
                AppSpacing.gapXxs,
                Text(
                  total,
                  style: context.appTypography.h1.copyWith(color: gold),
                  textAlign: TextAlign.center,
                ),
              ],
              AppSpacing.gapXxs,
              Text(
                practice
                    ? 'Practice — no mastery'
                    : pending
                        ? 'Waiting for mastery…'
                        : gain == null
                            ? '+0 this match'
                            : '$gain this match',
                style: context.appTypography.body.copyWith(
                  color: AppColors.onSurfaceDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  MatchSeatView? _localSeat() {
    for (final seat in snap.seats) {
      if (_isLocalMatchSeat(seat, localUserId)) return seat;
    }
    return null;
  }

  MasteryChange? _changeForSeat(
    MatchSeatView? seat,
    List<MasteryChange> changes,
  ) {
    if (changes.isEmpty) return null;
    final want = ensureGen001DesignId(seat?.slammerId ?? '');
    if (want.isNotEmpty) {
      for (final change in changes) {
        if (ensureGen001DesignId(change.designId) == want) return change;
      }
    }
    return changes.first;
  }

  AvariInventoryItem? _ownedFor(MatchSeatView? seat, MasteryChange? change) {
    final ids = <String>{
      if ((seat?.slammerId ?? '').trim().isNotEmpty)
        ensureGen001DesignId(seat!.slammerId),
      if (change != null) ensureGen001DesignId(change.designId),
    };
    if (ids.isEmpty) return null;
    for (final item in ownedSlammers) {
      if (ids.contains(ensureGen001DesignId(item.designId))) return item;
    }
    return null;
  }

  _ResolvedDisc _slammerFace(
    MatchSeatView? seat,
    MasteryChange? change,
    AvariInventoryItem? owned,
    String slammerId,
  ) {
    final practice = practiceSlammerFaceFor(slammerId.isEmpty ? null : slammerId);
    final lottie = _firstNonEmpty(
      seat?.lottieUrl,
      change?.lottieUrl,
      owned?.lottieUrl,
    );
    final image = lottie != null
        ? null
        : _firstNonEmpty(
            seat?.imageUrl,
            change?.imageUrl,
            owned?.imageUrl,
            practice['imageUrl'],
          );
    final name = _firstNonEmpty(change?.displayName, owned?.displayName) ??
        _shortDesignLabel(slammerId.isEmpty ? 'Slammer' : slammerId);
    return _ResolvedDisc(
      name: name,
      designId: slammerId.isEmpty ? (owned?.designId ?? 'slammer') : slammerId,
      imageUrl: image,
      lottieUrl: lottie,
      color: _firstNonEmpty(
        seat?.color,
        change?.color,
        owned?.color,
        practice['color'],
      ),
    );
  }
}

bool _isLocalMatchSeat(MatchSeatView seat, String localUserId) {
  final uid = seat.userId.trim();
  if (localUserId.isNotEmpty && uid == localUserId) return true;
  if (seat.kind == 'human' &&
      (uid == 'local' || uid.isEmpty || localUserId.isEmpty)) {
    return seat.seatIndex == 0 || uid == 'local';
  }
  return false;
}

String? _firstNonEmpty(String? a, [String? b, String? c, String? d]) {
  for (final value in [a, b, c, d]) {
    final text = value?.trim() ?? '';
    if (text.isNotEmpty) return text;
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
