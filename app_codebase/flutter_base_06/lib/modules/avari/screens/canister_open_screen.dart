import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/app_chrome.dart';
import '../../../core/widgets/app_mark_icon.dart';
import '../avari_models.dart';
import '../circulating_browse.dart';
import '../widgets/arcori_container_bank.dart';
import '../widgets/circulating_arcori_tile.dart';

const String _bodyAsset = 'assets/images/container_body.webp';
const String _capAsset = 'assets/images/container_cap.webp';

/// Full artwork is 720×1745, including headroom so the cap can rise and tilt.
const double _artWidth = 720;
const double _artHeight = 1745;

/// Cap center inside that canvas, as an [Alignment] (−1…1).
const Alignment _capPivot = Alignment(0.02083, -0.36447);

/// Body rim (top of the canister opening) inside that canvas.
/// SVG body top is y=491.7, centered at x=630.8, on a canvas with 620 units
/// of headroom (2999 tall, 1237.1 wide).
const Alignment _rimPivot = Alignment(0.01981, -0.25862);

const Duration _openDuration = Duration(milliseconds: 2600);

class _CapPose {
  const _CapPose(this.dy, this.radians);

  /// Fraction of the canvas height. Negative moves the cap up.
  final double dy;
  final double radians;
}

/// Closed, then a straight lift, then a tilt while it keeps rising, then a hold.
_CapPose _capPose(double t) {
  const closedEnd = 8 / 78;
  const riseEnd = 26 / 78;
  const tiltEnd = 54 / 78;
  const riseDy = -180 / 2999;
  const openDy = -420 / 2999;
  const openRot = -38 * math.pi / 180;
  if (t <= closedEnd) return const _CapPose(0, 0);
  if (t <= riseEnd) {
    final u = Curves.easeInOut.transform((t - closedEnd) / (riseEnd - closedEnd));
    return _CapPose(riseDy * u, 0);
  }
  if (t <= tiltEnd) {
    final u = Curves.easeInOut.transform((t - riseEnd) / (tiltEnd - riseEnd));
    return _CapPose(riseDy + (openDy - riseDy) * u, openRot * u);
  }
  return const _CapPose(openDy, openRot);
}

double _shineOpacity(double t) {
  const closedEnd = 8 / 78;
  const riseEnd = 26 / 78;
  if (t <= closedEnd) return 0;
  if (t >= riseEnd) return 1;
  return Curves.easeOut.transform((t - closedEnd) / (riseEnd - closedEnd));
}

/// Distance from [rim] to the farthest corner of [screen], so a circle of
/// this radius covers the page.
double _shineReach(Offset rim, Size screen) {
  var reach = 0.0;
  for (final corner in <Offset>[
    Offset.zero,
    Offset(screen.width, 0),
    Offset(0, screen.height),
    Offset(screen.width, screen.height),
  ]) {
    final distance = (corner - rim).distance;
    if (distance > reach) reach = distance;
  }
  return reach;
}

/// Rotating circular gold shine, held on the canister rim and large enough
/// to cover the screen.
class _OpeningShine extends StatelessWidget {
  const _OpeningShine({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final opacity = _shineOpacity(t);
    if (opacity <= 0) return const SizedBox.shrink();
    return CustomPaint(
      painter: _OpeningShinePainter(turns: t * 1.6, opacity: opacity),
    );
  }
}

class _OpeningShinePainter extends CustomPainter {
  const _OpeningShinePainter({required this.turns, required this.opacity});

  final double turns;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final glow = opacity;

    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
    canvas.saveLayer(rect, Paint());
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = SweepGradient(
          transform: GradientRotation(turns * math.pi * 2),
          colors: [
            AppColors.secondary.withValues(alpha: 0.05 * glow),
            AppColors.headingGold.withValues(alpha: 0.95 * glow),
            AppColors.secondary.withValues(alpha: 0.4 * glow),
            AppColors.tertiary.withValues(alpha: 0.04 * glow),
            AppColors.headingGold.withValues(alpha: 0.9 * glow),
            AppColors.secondary.withValues(alpha: 0.05 * glow),
          ],
          stops: const [0.0, 0.12, 0.28, 0.5, 0.68, 1.0],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.72, 1.0],
        ).createShader(rect)
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
    canvas.drawCircle(
      center,
      radius * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.headingGold.withValues(alpha: 0.9 * glow),
            AppColors.secondary.withValues(alpha: 0.45 * glow),
            AppColors.secondary.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(
          Rect.fromCircle(center: center, radius: radius * 0.46),
        )
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.08),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OpeningShinePainter oldDelegate) {
    return oldDelegate.turns != turns || oldDelegate.opacity != opacity;
  }
}

/// Plays the canister opening, then lists the Arcori packed inside it.
class CanisterOpenScreen extends StatefulWidget {
  const CanisterOpenScreen({required this.canister, super.key});

  final CirculatingCanister canister;

  @override
  State<CanisterOpenScreen> createState() => _CanisterOpenScreenState();
}

class _CanisterOpenScreenState extends State<CanisterOpenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;
  bool _revealed = false;
  String? _theme;
  String? _series;
  CirculatingSort _sort = CirculatingSort.mastery;

  @override
  void initState() {
    super.initState();
    _open = AnimationController(vsync: this, duration: _openDuration);
    _open.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && !_revealed) {
        setState(() => _revealed = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_revealed) _open.forward();
    });
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _reveal() {
    if (!mounted || _revealed) return;
    setState(() => _revealed = true);
  }

  void _openDesign(AvariInventoryItem item) {
    final id = item.designId.trim();
    if (id.isEmpty) return;
    Nav.push(
      context,
      '${AppPaths.arcoriDetail}?id=${Uri.encodeQueryComponent(id)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final canister = widget.canister;
    final muted = context.appTypography.bodySmall.copyWith(
      color: AppChrome.onSurfaceMuted,
    );
    return ModuleScreenRegistrar(
      appBarItems: [
        AppBarTitle(
          text: 'Canister ${canister.index + 1}',
          iconAsset: AppMarks.arcori,
        ),
      ],
      child: AppChromePage(
        child: _revealed
            ? _contents(context, canister, muted)
            : _opening(context),
      ),
    );
  }

  Widget _opening(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final top = AppChromePage.topClearance(context);
        final maxH = (screen.height - top) * 0.92;
        final maxW = screen.width * 0.86;
        const aspect = _artWidth / _artHeight;
        var width = maxW;
        var height = width / aspect;
        if (height > maxH) {
          height = maxH;
          width = height * aspect;
        }
        final artLeft = (screen.width - width) / 2;
        final artTop = top + (screen.height - top - height) / 2;
        final rim = Offset(
          artLeft + (_rimPivot.x + 1) / 2 * width,
          artTop + (_rimPivot.y + 1) / 2 * height,
        );
        final reach = _shineReach(rim, screen);
        return AnimatedBuilder(
          animation: _open,
          builder: (context, _) {
            final pose = _capPose(_open.value);
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: artLeft,
                  top: artTop,
                  width: width,
                  height: height,
                  child: Image.asset(
                    _bodyAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _reveal());
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                Positioned(
                  left: rim.dx - reach,
                  top: rim.dy - reach,
                  width: reach * 2,
                  height: reach * 2,
                  child: _OpeningShine(t: _open.value),
                ),
                Positioned(
                  left: artLeft,
                  top: artTop,
                  width: width,
                  height: height,
                  child: Transform(
                    alignment: _capPivot,
                    transform: Matrix4.identity()
                      ..translate(0.0, pose.dy * height)
                      ..rotateZ(pose.radians),
                    child: Image.asset(
                      _capAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _contents(
    BuildContext context,
    CirculatingCanister canister,
    TextStyle muted,
  ) {
    final stored = canister.items;
    final themes = circulatingFacet(stored, (item) => item.theme);
    final series = circulatingFacet(stored, (item) => item.seriesKey);
    final theme = themes.contains(_theme) ? _theme : null;
    final seriesKey = series.contains(_series) ? _series : null;
    final items = filterCirculating(
      stored,
      theme: theme,
      seriesKey: seriesKey,
      sort: _sort,
    );
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppChromePage.topClearance(context) + AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          canister.filling
              ? '${canister.filled} / ${ArcoriContainerBank.perContainer}'
              : '${canister.filled} Arcori',
          style: context.appTypography.h2.copyWith(
            color: AppChrome.accentGold,
            height: 1.1,
          ),
        ),
        AppSpacing.gapMd,
        if (stored.isEmpty)
          Text('This canister is empty.', style: muted)
        else ...[
          AppChromeSection(
            title: 'Filters',
            goldFrame: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (themes.isNotEmpty)
                  _FilterRow(
                    label: 'Theme',
                    options: themes,
                    selected: theme,
                    onSelect: (value) => setState(() => _theme = value),
                  ),
                if (series.isNotEmpty) ...[
                  if (themes.isNotEmpty) AppSpacing.gapSm,
                  _FilterRow(
                    label: 'Series',
                    options: series,
                    selected: seriesKey,
                    onSelect: (value) => setState(() => _series = value),
                  ),
                ],
                AppSpacing.gapSm,
                _FilterRow(
                  label: 'Sort',
                  options: const ['Mastery', 'Name', 'Near mint'],
                  selected: switch (_sort) {
                    CirculatingSort.mastery => 'Mastery',
                    CirculatingSort.name => 'Name',
                    CirculatingSort.nearMint => 'Near mint',
                  },
                  allowAll: false,
                  onSelect: (value) => setState(() {
                    _sort = switch (value) {
                      'Name' => CirculatingSort.name,
                      'Near mint' => CirculatingSort.nearMint,
                      _ => CirculatingSort.mastery,
                    };
                  }),
                ),
              ],
            ),
          ),
          AppSpacing.gapMd,
          if (items.isEmpty)
            Text('No Arcori in this canister match these filters.', style: muted)
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 0.62,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return CirculatingArcoriTile(
                  item: item,
                  onTap: () => _openDesign(item),
                );
              },
            ),
        ],
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.allowAll = true,
  });

  final String label;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final bool allowAll;

  @override
  Widget build(BuildContext context) {
    final choices = [
      if (allowAll) null,
      ...options,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.appTypography.caption.copyWith(
            color: AppChrome.accentGold,
          ),
        ),
        AppSpacing.gapXxs,
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < choices.length; i++) ...[
                if (i > 0) AppSpacing.gapXs,
                _FilterButton(
                  label: choices[i] ?? 'All',
                  selected: choices[i] == selected,
                  onPressed: () => onSelect(choices[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: selected
          ? context.appButtons.primary.filled
          : context.appButtons.primary.tonal,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

/// Shown when the open route is reached without the canister that was tapped.
class CanisterOpenMissing extends StatelessWidget {
  const CanisterOpenMissing({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Canister', iconAsset: AppMarks.arcori),
      ],
      child: AppChromePage(
        child: AppChromeCentered(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Open a canister from My Arcori.',
                textAlign: TextAlign.center,
                style: context.appTypography.body.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
              AppSpacing.gapMd,
              FilledButton(
                style: context.appButtons.primary.filled,
                onPressed: () => Nav.go(context, AppPaths.avariCirculating),
                child: const Text('My Arcori'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
