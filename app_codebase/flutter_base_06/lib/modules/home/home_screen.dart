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
      ref.read(avariApiClientProvider).fetchMasteryRecent(
            accessToken: token,
            limit: 5,
          ),
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
    await showNotificationModal(
      context,
      ref,
      message,
      markRead: () async {},
    );
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
      appBarItems: const [
        AppBarTitle(text: 'Home', icon: Icons.home_outlined),
      ],
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
                        actionLabel: 'Play',
                        onAction: () => Nav.go(context, AppPaths.play),
                        goldFrame: true,
                        child: _FeaturedEventCard(
                          entry: _featuredEvent,
                          loading: _loadingExtras,
                          onTap: () => Nav.go(context, AppPaths.play),
                        ),
                      ),
                      AppSpacing.gapMd,
                      AppChromeSection(
                        title: 'Mastery Value',
                        actionLabel: 'Profile',
                        onAction: () => Nav.go(context, AppPaths.avari),
                        goldFrame: true,
                        child: _MasteryHeroBody(
                          mastery: mastery,
                          topSlammer: topSlammer,
                          recent: _recentMastery,
                          loading: profileState.isLoading &&
                              !profileState.loaded,
                        ),
                      ),
                      AppSpacing.gapMd,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppChromeSection(
                              title: 'Daily Missions',
                              actionLabel: 'All',
                              onAction: () => Nav.go(context, AppPaths.tasks),
                              child: _DailyMissionsStrip(goals: daily),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppChromeSection(
                              title: 'World News',
                              actionLabel: 'Inbox',
                              onAction: () =>
                                  Nav.go(context, AppPaths.notifications),
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
      return SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppChrome.accentGold,
          ),
        ),
      );
    }
    if (entry == null) {
      return Text(
        'No featured event — open Play when a special event is live.',
        style: context.appTypography.bodyMuted.copyWith(
          color: AppChrome.onSurfaceMuted,
        ),
      );
    }
    final banner = entry!.banner;
    final url = banner != null && banner.isValid
        ? resolveMediaUrl(banner.value)
        : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (url.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: AspectRatio(
                  aspectRatio: 16 / 7,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (url.isNotEmpty) AppSpacing.gapSm,
            Text(
              entry!.name,
              style: context.appTypography.title.copyWith(
                color: AppChrome.onSurface,
              ),
            ),
            if (entry!.description.isNotEmpty) ...[
              AppSpacing.gapXxs,
              Text(
                entry!.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.bodyMuted.copyWith(
                  color: AppChrome.onSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorldNewsList extends StatelessWidget {
  const _WorldNewsList({
    required this.items,
    required this.onTap,
  });

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
    if (loading) {
      return SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: gold),
        ),
      );
    }
    final slammer = topSlammer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: context.appTypography.h1.copyWith(color: gold),
                  ),
                  Text(
                    label,
                    style: context.appTypography.title.copyWith(
                      color: AppChrome.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (slammer != null) ...[
              const SizedBox(width: AppSpacing.sm),
              _TopSlammerFace(item: slammer),
            ],
          ],
        ),
        AppSpacing.gapSm,
        _MasteryTicker(items: recent),
      ],
    );
  }
}

class _TopSlammerFace extends StatelessWidget {
  const _TopSlammerFace({required this.item});

  final AvariInventoryItem item;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final useLottie = item.hasLottieFace;
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ArcoriCylinder(
            look: ArcoriLook(
              designId: item.designId,
              imageUrl: useLottie ? null : item.imageUrl,
              colorHex: item.color,
            ),
            size: _size,
            face: useLottie
                ? KinSceneStack(
                    lottieUrl: item.lottieUrl,
                    fit: BoxFit.cover,
                  )
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
          Text(
            item.masteryOverMintReach,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.appTypography.caption.copyWith(
              color: AppChrome.accentGold,
            ),
          ),
        ],
      ),
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
            onTap: () => Nav.go(context, AppPaths.tasks),
            child: Row(
              children: [
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

