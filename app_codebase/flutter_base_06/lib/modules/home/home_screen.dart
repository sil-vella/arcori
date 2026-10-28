import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/http/media_url.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/screen/screen.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';
import '../../core/widgets/app_mark_icon.dart';
import '../../core/widgets/app_visuals.dart';
import '../museum/museum_assets.dart';
import '../velora/velora_assets.dart';
import '../avari/avari_api.dart';
import '../avari/avari_models.dart';
import '../avari/avari_notifier.dart';
import '../hub/hub_bottom_nav.dart';
import '../kin/widgets/kin_lottie_preview.dart';
import '../match/widgets/arcori_cylinder.dart';
import '../match/widgets/arcori_look.dart';
import '../notifications/notification_modal.dart';
import '../notifications/notifications_notifier.dart';
import '../notifications/notifications_state.dart';
import '../special_events/special_events_api.dart';
import '../special_events/special_events_models.dart';
import '../tasks/tasks_bootstrap.dart';
import '../tasks/tasks_models.dart';
import '../tasks/tasks_store.dart';

const String _kWorldNewsCategory = 'news';
const String _kMasteryValueBackground =
    'assets/images/backgrounds/mastery.webp';

/// Body for `/` — featured event, mastery (total + top slammer), daily and news columns, ticker.
///
/// Visual language matches Museum / Velora / Play via [AppChromePage].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _eventsApi = SpecialEventsApiClient();

  SpecialEventEntry? _featuredEvent;
  List<MasteryRecentChange> _recentMastery = const [];
  bool _loadingExtras = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = ref.read(authProvider);
    final token = auth.accessToken?.trim() ?? '';
    await Future.wait([
      ref.read(avariProfileProvider.notifier).load(force: true),
      hydrateTasks(ref),
      ref.read(notificationsProvider.notifier).refreshAll(force: true),
      if (token.isNotEmpty) _loadExtras(token),
    ]);
    if (mounted) setState(() => _loadingExtras = false);
  }

  Future<void> _loadExtras(String token) async {
    final results = await Future.wait([
      _eventsApi.fetchCatalog(accessToken: token),
      ref
          .read(avariApiClientProvider)
          .fetchMasteryRecent(accessToken: token, limit: 5),
    ]);
    if (!mounted) return;
    final catalogOutcome =
        results[0] as SpecialEventsApiOutcome<SpecialEventsCatalog>;
    final recentOutcome =
        results[1] as AvariApiOutcome<List<MasteryRecentChange>>;

    SpecialEventEntry? featured;
    if (catalogOutcome.isSuccess && catalogOutcome.data != null) {
      final events = catalogOutcome.data!.events;
      for (final e in events) {
        if (e.homeFeatured && e.eligible) {
          featured = e;
          break;
        }
      }
      featured ??= () {
        for (final e in events) {
          if (e.eligible) return e;
        }
        return events.isNotEmpty ? events.first : null;
      }();
    }

    setState(() {
      _featuredEvent = featured;
      if (recentOutcome.isSuccess && recentOutcome.data != null) {
        _recentMastery = recentOutcome.data!;
      }
    });
  }

  List<NotificationMessage> _worldNews(NotificationsState state) {
    final merged = <NotificationMessage>[
      ...state.globalBroadcasts,
      ...state.messages,
    ];
    final news = merged
        .where((m) => (m.category ?? '').trim() == _kWorldNewsCategory)
        .toList();
    news.sort((a, b) {
      final ac = a.createdAt ?? '';
      final bc = b.createdAt ?? '';
      return bc.compareTo(ac);
    });
    return news;
  }

  Future<void> _openNews(NotificationMessage message) async {
    final notifier = ref.read(notificationsProvider.notifier);
    await notifier.markRead(message);
    if (!mounted) return;
    await showNotificationModal(context, ref, message, markRead: () async {});
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(avariProfileProvider);
    final notifications = ref.watch(notificationsProvider);
    final profile = profileState.profile;
    final mastery = profile?.mastery;
    final topSlammer = _mostMasteredSlammer(profile?.slammers ?? const []);
    final news = _worldNews(notifications);

    return ModuleScreenRegistrar(
      appBarItems: const [AppBarTitle(text: 'Home', icon: Icons.home_outlined)],
      bottomNavModuleId: hubSinkBottomNavModuleId,
      bottomNavItems: hubSinkBottomNavItems(context),
      child: AppChromePage(
        child: ValueListenableBuilder<int>(
          valueListenable: TasksStore.changeVersion,
          builder: (context, _, __) {
            final daily = TasksStore.dailyGoals.take(3).toList();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(height: AppChromePage.topClearance(context)),
                ),
                SliverPadding(
                  padding: AppSpacing.screenPaddingCompact,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AppChromeSection(
                        title: 'Featured Event',
                        icon: Icons.auto_awesome,
                        actionLabel: 'Play',
                        onAction: () => Nav.push(context, AppPaths.play),
                        goldFrame: true,
                        background: _FeaturedBackdrop(entry: _featuredEvent),
                        child: _FeaturedEventCard(
                          entry: _featuredEvent,
                          loading: _loadingExtras,
                          onTap: () => Nav.push(context, AppPaths.play),
                        ),
                      ),
                      AppSpacing.gapMd,
                      const _LearnTheWorldCard(),
                      AppSpacing.gapMd,
                      AppChromeSection(
                        title: 'Mastery Value',
                        icon: Icons.bar_chart,
                        actionLabel: 'Profile',
                        onAction: () => Nav.push(context, AppPaths.avari),
                        goldFrame: true,
                        background: const _MasteryBackdrop(),
                        child: _MasteryHeroBody(
                          mastery: mastery,
                          topSlammer: topSlammer,
                          recent: _recentMastery,
                          loading:
                              profileState.isLoading && !profileState.loaded,
                        ),
                      ),
                      AppSpacing.gapMd,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppChromeSection(
                              title: 'Daily Missions',
                              icon: Icons.task_alt,
                              actionLabel: 'All',
                              onAction: () => Nav.push(context, AppPaths.tasks),
                              child: _DailyMissionsStrip(goals: daily),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppChromeSection(
                              title: 'World News',
                              mark: const AppMarkIcon(AppMarks.velora),
                              actionLabel: 'Inbox',
                              onAction: () =>
                                  Nav.push(context, AppPaths.notifications),
                              child: _WorldNewsList(
                                items: news.take(8).toList(),
                                onTap: _openNews,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedEventCard extends StatelessWidget {
  const _FeaturedEventCard({
    required this.entry,
    required this.loading,
    required this.onTap,
  });

  final SpecialEventEntry? entry;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (loading && entry == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 80,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppChrome.accentGold,
              ),
            ),
          ),
        ),
      );
    }
    if (entry == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          alignment: Alignment.centerLeft,
          child: Text(
            'No featured event — open Play when a special event is live.',
            style: context.appTypography.bodyMuted.copyWith(
              color: AppChrome.onSurfaceMuted,
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entry!.name,
              style: context.appTypography.h3.copyWith(
                color: AppChrome.accentGold,
              ),
            ),
            if (entry!.description.isNotEmpty) ...[
              AppSpacing.gapXxs,
              Text(
                entry!.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.bodyMuted.copyWith(
                  color: AppChrome.onSurface,
                ),
              ),
            ],
            AppSpacing.gapSm,
            FilledButton.icon(
              style: context.appButtons.primary.filled,
              onPressed: onTap,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnTheWorldCard extends StatelessWidget {
  const _LearnTheWorldCard();

  @override
  Widget build(BuildContext context) {
    return AppCardFrame(
      gold: true,
      background: const _HomeWorldCover(),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Master the Arcori. Learn your slammer.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.bodySmall.copyWith(
                  color: AppChrome.onSurface,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton(
              style: context.appButtons.primary.filled,
              onPressed: () => Nav.push(context, AppPaths.veloraWorld),
              child: const Text('Learn the world'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeWorldCover extends StatelessWidget {
  const _HomeWorldCover();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kVeloraWorldBackgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.92),
                ink.withValues(alpha: 0.55),
                ink.withValues(alpha: 0.15),
              ],
              stops: const [0.0, 0.42, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturedBackdrop extends StatelessWidget {
  const _FeaturedBackdrop({required this.entry});

  final SpecialEventEntry? entry;

  @override
  Widget build(BuildContext context) {
    final banner = entry?.banner;
    final url = banner != null && banner.isValid
        ? resolveMediaUrl(banner.value)
        : '';
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        url.isEmpty
            ? _fallback()
            : Image.network(
                url,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.94),
                ink.withValues(alpha: 0.72),
                ink.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.28, 0.5],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fallback() {
    return Image.asset(
      kVeloraWorldBackgroundAsset,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
      errorBuilder: (_, __, ___) => ColoredBox(color: AppChrome.fieldFill),
    );
  }
}

class _WorldNewsList extends StatelessWidget {
  const _WorldNewsList({required this.items, required this.onTap});

  final List<NotificationMessage> items;
  final Future<void> Function(NotificationMessage message) onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        'No world news yet — closures, Legacy Owners, and admin posts appear here.',
        style: context.appTypography.bodyMuted.copyWith(
          color: AppChrome.onSurfaceMuted,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) ...[
            AppSpacing.gapSm,
            Divider(
              height: 1,
              color: AppChrome.panelBorder.withValues(alpha: 0.35),
            ),
            AppSpacing.gapSm,
          ],
          InkWell(
            onTap: () => onTap(items[i]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        items[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.appTypography.subtitle.copyWith(
                          color: AppChrome.onSurface,
                        ),
                      ),
                    ),
                    if (items[i].isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppChrome.accentGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapXxs,
                Text(
                  items[i].body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTypography.bodyMuted.copyWith(
                    color: AppChrome.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MasteryHeroBody extends StatelessWidget {
  const _MasteryHeroBody({
    required this.mastery,
    required this.loading,
    this.topSlammer,
    this.recent = const [],
  });

  final AvariMasterySummary? mastery;
  final bool loading;
  final AvariInventoryItem? topSlammer;
  final List<MasteryRecentChange> recent;

  @override
  Widget build(BuildContext context) {
    final value = mastery?.masteryValue ?? 0;
    final label = mastery?.masteryValueLabel ?? '—';
    final gold = AppChrome.accentGold;
    final Widget body;
    if (loading) {
      body = SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: gold),
        ),
      );
    } else {
      final slammer = topSlammer;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MasteryScoreColumn(value: value, label: label),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  color: gold.withValues(alpha: 0.85),
                ),
                Expanded(
                  child: slammer == null
                      ? const _TopSlammerEmpty()
                      : _TopSlammerFace(item: slammer),
                ),
              ],
            ),
          ),
          AppSpacing.gapSm,
          _MasteryTicker(items: recent),
        ],
      );
    }
    return body;
  }
}

class _MasteryBackdrop extends StatelessWidget {
  const _MasteryBackdrop();

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.surfaceDark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          kMuseumHallBackgroundAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.35),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                ink.withValues(alpha: 0.74),
                ink.withValues(alpha: 0.62),
                ink.withValues(alpha: 0.55),
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _MasteryScoreColumn extends StatelessWidget {
  const _MasteryScoreColumn({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final gold = AppChrome.accentGold;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: 0.3,
                child: Image.asset(
                  _kMasteryValueBackground,
                  width: 148,
                  height: 148,
                  fit: BoxFit.contain,
                ),
              ),
              const Positioned.fill(child: _MasterySparkles()),
              Positioned.fill(
                child: _MasteryNumber(
                  value: '$value',
                  style: context.appTypography.h2.copyWith(
                    color: gold,
                    height: 1,
                    fontSize: (context.appTypography.h2.fontSize ?? 28) * 2,
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                ),
              ),
            ],
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.appTypography.title.copyWith(
            color: AppChrome.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Twinkling gold stars behind the mastery number.
class _MasterySparkles extends StatefulWidget {
  const _MasterySparkles();

  @override
  State<_MasterySparkles> createState() => _MasterySparklesState();
}

class _MasterySparklesState extends State<_MasterySparkles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle;

  @override
  void initState() {
    super.initState();
    _cycle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cycle,
      builder: (context, _) {
        return CustomPaint(painter: _MasterySparklePainter(t: _cycle.value));
      },
    );
  }
}

class _SparkleSpec {
  const _SparkleSpec(this.x, this.y, this.phase, this.radius);

  final double x;
  final double y;
  final double phase;
  final double radius;
}

const List<_SparkleSpec> _sparkles = [
  _SparkleSpec(0.22, 0.30, 0.00, 7),
  _SparkleSpec(0.78, 0.26, 0.17, 5),
  _SparkleSpec(0.72, 0.74, 0.34, 6.5),
  _SparkleSpec(0.28, 0.76, 0.51, 5.5),
  _SparkleSpec(0.50, 0.16, 0.66, 4.5),
  _SparkleSpec(0.86, 0.48, 0.09, 4),
  _SparkleSpec(0.14, 0.50, 0.43, 4.5),
  _SparkleSpec(0.58, 0.86, 0.79, 5),
];

class _MasterySparklePainter extends CustomPainter {
  const _MasterySparklePainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spec in _sparkles) {
      final u = (t + spec.phase) % 1.0;
      final life = _sparkleLife(u);
      if (life <= 0) continue;
      final center = Offset(spec.x * size.width, spec.y * size.height);
      final radius = spec.radius * (0.35 + 0.65 * life);
      final color = AppColors.headingGold.withValues(alpha: 0.9 * life);
      _drawStar(canvas, center, radius, u * math.pi, color);
      _drawStar(
        canvas,
        center,
        radius * 0.45,
        u * math.pi + math.pi / 4,
        AppColors.secondary.withValues(alpha: 0.55 * life),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MasterySparklePainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

/// Pop in, hold, then fade. Original twinkle, not a vendored Lottie.
double _sparkleLife(double u) {
  if (u < 0.16) return Curves.easeOut.transform(u / 0.16);
  if (u > 0.7) return 1 - Curves.easeIn.transform((u - 0.7) / 0.3);
  return 1;
}

void _drawStar(
  Canvas canvas,
  Offset center,
  double radius,
  double turn,
  Color color,
) {
  final path = Path();
  const points = 4;
  for (var i = 0; i < points * 2; i++) {
    final angle = turn + i * math.pi / points - math.pi / 2;
    final arm = i.isEven ? radius : radius * 0.32;
    final point = Offset(
      center.dx + math.cos(angle) * arm,
      center.dy + math.sin(angle) * arm,
    );
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Mastery digits with a light band that sweeps across them.
class _MasteryNumber extends StatefulWidget {
  const _MasteryNumber({
    required this.value,
    required this.style,
    required this.textDirection,
    required this.textScaler,
  });

  final String value;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  State<_MasteryNumber> createState() => _MasteryNumberState();
}

class _MasteryNumberState extends State<_MasteryNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shine,
      builder: (context, _) {
        return CustomPaint(
          painter: _MasteryValuePainter(
            value: widget.value,
            style: widget.style,
            textDirection: widget.textDirection,
            textScaler: widget.textScaler,
            shine: _shine.value,
          ),
        );
      },
    );
  }
}

/// Paints the score so the digit ink, not the font line box, sits on center.
///
/// Cormorant lining figures occupy the cap-height (0.625 em) above the baseline.
/// The line box has a deep descender, so centering the text widget leaves the
/// number high in the medallion.
class _MasteryValuePainter extends CustomPainter {
  const _MasteryValuePainter({
    required this.value,
    required this.style,
    required this.textDirection,
    required this.textScaler,
    required this.shine,
  });

  final String value;
  final TextStyle style;
  final TextDirection textDirection;
  final TextScaler textScaler;

  /// 0–1 position of the highlight band crossing the digits.
  final double shine;

  static const double _capOverEm = 0.625;

  @override
  void paint(Canvas canvas, Size size) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    if (painter.computeLineMetrics().isEmpty) return;
    final metrics = painter.computeLineMetrics().first;
    final fontSize = textScaler.scale(style.fontSize ?? 28);
    final cap = fontSize * _capOverEm;
    final desiredBaseline = size.height / 2 + cap / 2;
    final offset = Offset(
      (size.width - painter.width) / 2,
      desiredBaseline - metrics.baseline,
    );
    painter.paint(canvas, offset);
    _paintShine(canvas, size, painter, offset);
  }

  void _paintShine(
    Canvas canvas,
    Size size,
    TextPainter painter,
    Offset offset,
  ) {
    final travel = -1.15 + Curves.easeInOut.transform(shine) * 2.3;
    canvas.saveLayer(Offset.zero & size, Paint()..blendMode = BlendMode.plus);
    painter.paint(canvas, offset);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment(travel, -1),
          end: Alignment(travel + 0.55, 1),
          colors: [
            AppColors.headingGold.withValues(alpha: 0),
            AppColors.headingGold.withValues(alpha: 0.2),
            AppColors.headingGold,
            AppColors.secondary.withValues(alpha: 0.85),
            AppColors.headingGold.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.38, 0.5, 0.56, 0.72],
        ).createShader(Offset.zero & size)
        ..blendMode = BlendMode.srcIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MasteryValuePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.style != style ||
        oldDelegate.textScaler != textScaler ||
        oldDelegate.shine != shine;
  }
}

class _TopSlammerFace extends StatelessWidget {
  const _TopSlammerFace({required this.item});

  final AvariInventoryItem item;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final useLottie = item.hasLottieFace;
    final gold = AppChrome.accentGold;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ArcoriCylinder(
          look: ArcoriLook(
            designId: item.designId,
            imageUrl: useLottie ? null : item.imageUrl,
            colorHex: item.color,
          ),
          size: _size,
          face: useLottie
              ? KinSceneStack(lottieUrl: item.lottieUrl, fit: BoxFit.cover)
              : null,
        ),
        AppSpacing.gapXxs,
        Text(
          item.displayName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: AppChrome.onSurface,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppMarkIcon(AppMarks.slammers, size: 14),
            const SizedBox(width: AppSpacing.xxs),
            Flexible(
              child: Text(
                item.masteryOverMintReach,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.appTypography.caption.copyWith(color: gold),
              ),
            ),
          ],
        ),
        if ((item.masteryCap ?? item.mintReach) != null) ...[
          AppSpacing.gapXxs,
          Container(
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: gold, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: () {
                  final reach = item.masteryCap ?? item.mintReach ?? 1;
                  if (reach <= 0) return 0.0;
                  return (item.masteryPoints / reach).clamp(0.0, 1.0);
                }(),
                minHeight: 7,
                backgroundColor: AppChrome.panelBorder,
                color: gold,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopSlammerEmpty extends StatelessWidget {
  const _TopSlammerEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppMarkIcon(AppMarks.slammers, size: 28),
        AppSpacing.gapXxs,
        Text(
          'No slammer yet',
          textAlign: TextAlign.center,
          style: context.appTypography.caption.copyWith(
            color: AppChrome.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

AvariInventoryItem? _mostMasteredSlammer(List<AvariInventoryItem> slammers) {
  AvariInventoryItem? best;
  for (final item in slammers) {
    if (best == null || item.masteryPoints > best.masteryPoints) {
      best = item;
    }
  }
  return best;
}

class _MasteryTicker extends StatefulWidget {
  const _MasteryTicker({required this.items});

  final List<MasteryRecentChange> items;

  @override
  State<_MasteryTicker> createState() => _MasteryTickerState();
}

class _MasteryTickerState extends State<_MasteryTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Text(
        'Play a match to see your recent mastery changes here.',
        style: context.appTypography.bodyMuted.copyWith(
          color: AppChrome.onSurfaceMuted,
        ),
      );
    }
    final text = widget.items.map((e) => e.tickerLabel).join('   ·   ');
    final doubled = '$text   ·   $text   ·   ';
    return ClipRect(
      child: SizedBox(
        height: 28,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-_controller.value * 320, 0),
                child: Text(
                  doubled,
                  maxLines: 1,
                  softWrap: false,
                  style: context.appTypography.subtitle.copyWith(
                    color: AppChrome.accentGold,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DailyMissionsStrip extends StatelessWidget {
  const _DailyMissionsStrip({required this.goals});

  final List<TaskCatalogEntry> goals;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return Text(
        'No daily missions yet — check back after syncing Tasks.',
        style: context.appTypography.bodyMuted.copyWith(
          color: AppChrome.onSurfaceMuted,
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < goals.length; i++) ...[
          if (i > 0) ...[
            AppSpacing.gapSm,
            Divider(
              height: 1,
              color: AppChrome.panelBorder.withValues(alpha: 0.35),
            ),
            AppSpacing.gapSm,
          ],
          InkWell(
            onTap: () => Nav.push(context, AppPaths.tasks),
            child: Row(
              children: [
                Icon(
                  _missionIcon(goals[i]),
                  size: 18,
                  color: AppChrome.accentGold,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    goals[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.appTypography.subtitle.copyWith(
                      color: AppChrome.onSurface,
                    ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final row = TasksStore.progressFor(goals[i].id);
                    final done = row?.completedToday == true;
                    return Text(
                      done ? 'Done' : (row?.progressLabel ?? '—'),
                      style: context.appTypography.caption.copyWith(
                        color: done
                            ? AppChrome.accentGold
                            : AppChrome.onSurfaceMuted,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

IconData _missionIcon(TaskCatalogEntry goal) {
  final id = goal.id.toLowerCase();
  final name = goal.name.toLowerCase();
  if (id.contains('mystery') ||
      id.contains('cache') ||
      name.contains('cache')) {
    return Icons.lock_outline;
  }
  if (id.contains('flip') || name.contains('flip')) {
    return Icons.hourglass_bottom;
  }
  return Icons.check_circle_outline;
}
