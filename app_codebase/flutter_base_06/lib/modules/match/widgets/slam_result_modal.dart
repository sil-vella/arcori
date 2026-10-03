import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../state/match_snapshot_state.dart';
import 'arcori_cylinder.dart';
import 'arcori_look.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const Duration kSlamResultAutoClose = Duration(seconds: 3);
const Duration kSlamFlipFlight = Duration(milliseconds: 1100);

/// How long the end-game modal waits for a last-turn result that is still queued.
const Duration kSlamResultFrontWait = Duration(seconds: 8);

/// Keeps the post-turn flip/miss card in front of the end-game modal.
///
/// The match shell stays up while a result is pending or showing. The
/// post-match route is installed under that card, so close or the 3s timer
/// reveals the summary that is already behind it.
class SlamResultFront {
  SlamResultFront._();

  static Route<dynamic>? active;
  static Route<dynamic>? shellRoute;
  static bool pending = false;
  static VoidCallback? onReleased;

  static final List<Completer<Route<dynamic>?>> _waiters = [];

  static bool get isHolding => pending || (active?.isActive ?? false);

  static void markPending() {
    pending = true;
  }

  /// Result card is on screen. Completes anyone waiting to stack under it.
  static void attach(Route<dynamic> route) {
    active = route;
    pending = false;
    _complete(route);
  }

  static void detach(Route<dynamic> route) {
    if (active != route) return;
    active = null;
    pending = false;
    onReleased?.call();
  }

  /// Queued result will not be shown (shell gone before the card opened).
  static void cancelPending() {
    if (!pending) return;
    pending = false;
    final route = active;
    _complete(route != null && route.isActive ? route : null);
    if (active == null || !active!.isActive) {
      onReleased?.call();
    }
  }

  /// The card that should stay in front of the end-game modal.
  ///
  /// A queued result waits until that card is on screen, so an older card
  /// still counting down cannot be treated as the last turn.
  static Future<Route<dynamic>?> frontRoute({
    Duration timeout = kSlamResultFrontWait,
  }) {
    if (!pending) {
      final route = active;
      if (route != null && route.isActive) {
        return Future<Route<dynamic>?>.value(route);
      }
      return Future<Route<dynamic>?>.value(null);
    }
    final waiter = Completer<Route<dynamic>?>();
    _waiters.add(waiter);
    return waiter.future.timeout(timeout, onTimeout: () {
      _waiters.remove(waiter);
      final current = active;
      if (current != null && current.isActive) return current;
      return null;
    });
  }

  static void _complete(Route<dynamic>? route) {
    final waiters = List<Completer<Route<dynamic>?>>.of(_waiters);
    _waiters.clear();
    for (final waiter in waiters) {
      if (!waiter.isCompleted) waiter.complete(route);
    }
  }

  /// Clears static route bookkeeping. Widget tests only.
  static void resetForTest() {
    active = null;
    shellRoute = null;
    pending = false;
    onReleased = null;
    _complete(null);
  }
}

/// Install [route] under [keepInFront] when [shellUnder] is still beneath it.
///
/// Returns true when the front route stayed current. Otherwise the caller
/// pushes [route] itself (it was not installed).
bool installRouteBehindFront(
  NavigatorState nav,
  Route<void> route, {
  required Route<dynamic>? keepInFront,
  required Route<dynamic>? shellUnder,
}) {
  final front = keepInFront;
  final shell = shellUnder;
  if (front == null || shell == null) return false;
  if (!front.isActive || !front.isCurrent || front.navigator != nav) {
    return false;
  }
  if (!shell.isActive || shell.isCurrent) return false;
  nav.replaceRouteBelow<void>(anchorRoute: front, newRoute: route);
  return true;
}

const double _kDiscSolo = 104;
const double _kDiscPair = 88;
const double _kDiscFew = 72;
const double _kDiscMany = 56;

/// One flipped disc to fly into the slam-result card.
class SlamFlipFace {
  const SlamFlipFace({
    required this.pieceId,
    required this.designId,
    this.imageUrl,
    this.colorHex,
  });

  final String pieceId;
  final String designId;
  final String? imageUrl;
  final String? colorHex;

  ArcoriLook get look => ArcoriLook(
        designId: designId,
        imageUrl: imageUrl,
        colorHex: colorHex,
      );
}

/// Flipped pieces from [lastEvent], in slam order, with catalog faces.
List<SlamFlipFace> slamFlipFaces({
  required List<MatchPieceView> pieces,
  required Map<String, dynamic> lastEvent,
}) {
  final outcome = lastEvent['outcome'];
  final raw = outcome is Map ? outcome['flippedPieceIds'] : null;
  if (raw is! List) return const [];
  final byId = {for (final piece in pieces) piece.pieceId: piece};
  final faces = <SlamFlipFace>[];
  for (final id in raw) {
    final pieceId = id.toString();
    if (pieceId.isEmpty) continue;
    final piece = byId[pieceId];
    if (piece == null) {
      faces.add(SlamFlipFace(pieceId: pieceId, designId: pieceId));
      continue;
    }
    final design = piece.designId.trim();
    faces.add(
      SlamFlipFace(
        pieceId: piece.pieceId,
        designId: design.isEmpty ? piece.pieceId : design,
        imageUrl: piece.imageUrl,
        colorHex: piece.color,
      ),
    );
  }
  return faces;
}

/// 0–1 flight progress for disc [index] inside a shared 0–1 timeline.
double slamFlipFlightT({
  required double t,
  required int index,
  required int count,
}) {
  final clamped = t.clamp(0.0, 1.0);
  if (count <= 1) return Curves.easeOutCubic.transform(clamped);
  final stagger = (0.28 / (count - 1)).clamp(0.0, 0.12);
  final span = (1 - stagger * (count - 1)).clamp(0.4, 1.0);
  final local = ((clamped - index * stagger) / span).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(local);
}

/// +1 Mastery pop, 0 until the disc is most of the way to its slot.
double slamMasteryPopT(double flightT) {
  return ((flightT - 0.62) / 0.38).clamp(0.0, 1.0);
}

double slamFlipDiscSize(int count) {
  if (count <= 1) return _kDiscSolo;
  if (count == 2) return _kDiscPair;
  if (count <= 4) return _kDiscFew;
  return _kDiscMany;
}

/// Non-blocking 3s slam-result overlay for the acting player only.
///
/// Fire-and-forget — do **not** await; match turns continue underneath.
void showSlamResultModal(
  BuildContext context, {
  required Map<String, dynamic> lastEvent,
  required int actorScoreDelta,
  List<SlamFlipFace> flips = const [],
}) {
  if (LOGGING_SWITCH) {
    customlog(
      'slamResultModal: show result=${lastEvent['result']} '
      'delta=$actorScoreDelta flips=${flips.length} '
      'version=${lastEvent['version']}',
    );
  }
  unawaited(
    AppModal.showCentered<void>(
      context,
      barrierDismissible: true,
      builder: (ctx) => Theme(
        data: AppTheme.dark,
        child: _SlamResultStage(
          lastEvent: lastEvent,
          actorScoreDelta: actorScoreDelta,
          flips: flips,
          autoClose: kSlamResultAutoClose,
        ),
      ),
    ),
  );
}

class _SlamResultStage extends StatefulWidget {
  const _SlamResultStage({
    required this.lastEvent,
    required this.actorScoreDelta,
    required this.flips,
    required this.autoClose,
  });

  final Map<String, dynamic> lastEvent;
  final int actorScoreDelta;
  final List<SlamFlipFace> flips;
  final Duration autoClose;

  @override
  State<_SlamResultStage> createState() => _SlamResultStageState();
}

class _SlamResultStageState extends State<_SlamResultStage>
    with TickerProviderStateMixin {
  final GlobalKey _stackKey = GlobalKey();
  late final List<GlobalKey> _slotKeys;
  late final AnimationController _flight;
  late final AnimationController _glint;
  Timer? _timer;
  Timer? _startTimer;
  Route<dynamic>? _route;
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    _slotKeys = List<GlobalKey>.generate(
      widget.flips.length,
      (_) => GlobalKey(),
    );
    _flight = AnimationController(vsync: this, duration: kSlamFlipFlight)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _glint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _timer = Timer(widget.autoClose, _close);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    _startTimer = Timer(AppModalMetrics.transitionDuration, () {
      if (!mounted) return;
      _flight.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    _route = route;
    if (route != null && !_attached) {
      _attached = true;
      SlamResultFront.attach(route);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startTimer?.cancel();
    final route = _route;
    if (route != null) SlamResultFront.detach(route);
    _flight.dispose();
    _glint.dispose();
    super.dispose();
  }

  void _close() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    AppModal.dismiss(context);
  }

  Offset _stackCenter(RenderBox stack) => stack.size.center(Offset.zero);

  Offset _slotCenter(RenderBox stack, int index) {
    final slot = _slotKeys[index].currentContext?.findRenderObject();
    if (slot is! RenderBox || !slot.hasSize) return _stackCenter(stack);
    final origin = stack.globalToLocal(slot.localToGlobal(Offset.zero));
    return origin + Offset(slot.size.width / 2, slot.size.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.lastEvent['result']?.toString() ?? 'miss';
    final isFlip = result == 'flip' && widget.flips.isNotEmpty;
    final discSize = slamFlipDiscSize(widget.flips.length);
    final surfaces = AppSurfacesExtension.dark;

    return SizedBox.expand(
      child: Stack(
        key: _stackKey,
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: const Alignment(0, -0.22),
            child: _ResultCard(
              isFlip: isFlip,
              flipCount: widget.flips.length,
              actorScoreDelta: widget.actorScoreDelta,
              discSize: discSize,
              slotKeys: _slotKeys,
              surfaces: surfaces,
              onClose: _close,
            ),
          ),
          if (isFlip) ..._flyers(discSize),
        ],
      ),
    );
  }

  List<Widget> _flyers(double discSize) {
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !stack.hasSize) return const [];
    final origin = _stackCenter(stack);
    final count = widget.flips.length;
    return [
      for (var i = 0; i < count; i++)
        _flyerAt(
          index: i,
          count: count,
          discSize: discSize,
          from: origin,
          to: _slotCenter(stack, i),
          face: widget.flips[i],
        ),
    ];
  }

  Widget _flyerAt({
    required int index,
    required int count,
    required double discSize,
    required Offset from,
    required Offset to,
    required SlamFlipFace face,
  }) {
    final flightT = slamFlipFlightT(
      t: _flight.value,
      index: index,
      count: count,
    );
    final masteryT = slamMasteryPopT(flightT);
    final pos = Offset.lerp(from, to, flightT)!;
    final labelBand = discSize * 0.78;
    return Positioned(
      left: pos.dx - discSize / 2,
      top: pos.dy - discSize / 2 - labelBand,
      width: discSize,
      height: discSize + labelBand,
      child: IgnorePointer(
        child: _FlyingDisc(
          look: face.look,
          size: discSize,
          labelBand: labelBand,
          flightT: flightT,
          masteryT: masteryT,
          glint: _glint.value,
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.isFlip,
    required this.flipCount,
    required this.actorScoreDelta,
    required this.discSize,
    required this.slotKeys,
    required this.surfaces,
    required this.onClose,
  });

  final bool isFlip;
  final int flipCount;
  final int actorScoreDelta;
  final double discSize;
  final List<GlobalKey> slotKeys;
  final AppSurfacesExtension surfaces;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final gold = surfaces.frameGold;
    final bronze = surfaces.frameBronze;
    return Material(
      color: surfaces.exhibit,
      elevation: AppModalMetrics.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(surfaces.exhibitRadius),
        side: BorderSide(color: gold, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.appModalTheme.maxWidth),
        child: Padding(
          padding: AppSpacing.modalPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  style: context.appButtons.tertiary.icon,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                isFlip ? 'FLIP' : 'MISS',
                textAlign: TextAlign.center,
                style: context.appTypography.title.copyWith(
                  letterSpacing: 2,
                  color: isFlip ? gold : context.appColorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.gapSm,
              if (isFlip)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (var i = 0; i < slotKeys.length; i++)
                      SizedBox(
                        key: slotKeys[i],
                        width: discSize,
                        height: discSize,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: bronze.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                Text(
                  'No flips',
                  textAlign: TextAlign.center,
                  style: context.appTypography.body.copyWith(
                    color: context.appColorScheme.onSurface,
                  ),
                ),
              if (isFlip) ...[
                AppSpacing.gapSm,
                Text(
                  flipCount == 1 ? '1 flipped' : '$flipCount flipped',
                  textAlign: TextAlign.center,
                  style: context.appTypography.bodySmall.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (actorScoreDelta != 0) ...[
                AppSpacing.gapXs,
                Text(
                  actorScoreDelta > 0
                      ? '+$actorScoreDelta score'
                      : '$actorScoreDelta score',
                  textAlign: TextAlign.center,
                  style: context.appTypography.bodySmall.copyWith(
                    color: context.appColorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FlyingDisc extends StatelessWidget {
  const _FlyingDisc({
    required this.look,
    required this.size,
    required this.labelBand,
    required this.flightT,
    required this.masteryT,
    required this.glint,
  });

  final ArcoriLook look;
  final double size;
  final double labelBand;
  final double flightT;
  final double masteryT;
  final double glint;

  @override
  Widget build(BuildContext context) {
    final land = ((flightT - 0.72) / 0.28).clamp(0.0, 1.0);
    final approach = (flightT / 0.72).clamp(0.0, 1.0);
    final scale = flightT < 0.72
        ? 1.14 - (0.14 * approach)
        : 1 + (0.1 * math.sin(land * math.pi));
    final wobble = math.sin(flightT * math.pi * 2) * 0.1 * (1 - flightT);
    final twinkle = math.sin(glint * math.pi * 2) * 0.5 + 0.5;
    final glow = flightT * (0.28 + 0.4 * twinkle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: labelBand,
          width: size,
          child: masteryT <= 0
              ? const SizedBox.shrink()
              : _MasteryPop(
                  masteryT: masteryT,
                  glint: glint,
                ),
        ),
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: glow),
                      blurRadius: 18,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: glow * 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
              Transform.rotate(
                angle: wobble,
                child: Transform.scale(
                  scale: scale,
                  child: ArcoriCylinder(
                    look: look,
                    size: size,
                    faceUp: true,
                  ),
                ),
              ),
              for (var i = 0; i < 6; i++)
                _DiscSparkle(
                  index: i,
                  count: 6,
                  size: size,
                  glint: glint,
                  flightT: flightT,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MasteryPop extends StatelessWidget {
  const _MasteryPop({
    required this.masteryT,
    required this.glint,
  });

  final double masteryT;
  final double glint;

  @override
  Widget build(BuildContext context) {
    final shown = masteryT.clamp(0.0, 1.0);
    final pop = Curves.easeOutBack.transform(shown);
    final wave = math.sin(glint * math.pi * 2);
    final enter = (1 - pop) * 16;
    final bounce = wave * -8 * shown;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, enter + bounce),
        child: Opacity(
          opacity: shown,
          child: Transform.scale(
            scale: 0.76 + (0.24 * pop),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 4; i++)
                  _LabelSparkle(index: i, glint: glint, shown: shown),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+1',
                      style: context.appTypography.title.copyWith(
                        color: AppColors.secondary,
                        height: 1,
                      ),
                    ),
                    Text(
                      'Mastery',
                      style: context.appTypography.label.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelSparkle extends StatelessWidget {
  const _LabelSparkle({
    required this.index,
    required this.glint,
    required this.shown,
  });

  final int index;
  final double glint;
  final double shown;

  @override
  Widget build(BuildContext context) {
    final phase = (glint + index * 0.23) % 1.0;
    final twinkle = math.sin(phase * math.pi * 2) * 0.5 + 0.5;
    final angle = (index / 4) * math.pi * 2 + glint * 1.4;
    final radius = 22 + (6 * twinkle);
    return Transform.translate(
      offset: Offset(
        math.cos(angle) * radius,
        math.sin(angle) * radius * 0.55 - 6,
      ),
      child: Opacity(
        opacity: shown * (0.35 + 0.65 * twinkle),
        child: Icon(
          Icons.auto_awesome,
          size: 10 + (6 * twinkle),
          color: index.isEven ? AppColors.secondary : AppColors.accent,
        ),
      ),
    );
  }
}

class _DiscSparkle extends StatelessWidget {
  const _DiscSparkle({
    required this.index,
    required this.count,
    required this.size,
    required this.glint,
    required this.flightT,
  });

  final int index;
  final int count;
  final double size;
  final double glint;
  final double flightT;

  @override
  Widget build(BuildContext context) {
    final phase = (glint + index / count) % 1.0;
    final twinkle = math.sin(phase * math.pi * 2) * 0.5 + 0.5;
    final angle = (index / count) * math.pi * 2 + glint * 0.85;
    final radius = size * (0.46 + 0.06 * twinkle);
    final spark = 9 + (7 * twinkle);
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
      child: Opacity(
        opacity: flightT * (0.25 + 0.75 * twinkle),
        child: Icon(
          Icons.auto_awesome,
          size: spark,
          color: index.isEven ? AppColors.secondary : AppColors.tertiary,
        ),
      ),
    );
  }
}
