import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/http/media_url.dart';
import '../../../core/navigation/app_navigation.dart';
import '../../../core/navigation/app_paths.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../avari_models.dart';
import '../avari_notifier.dart';

class AvariProfileScreen extends ConsumerStatefulWidget {
  const AvariProfileScreen({super.key});

  @override
  ConsumerState<AvariProfileScreen> createState() => _AvariProfileScreenState();
}

class _AvariProfileScreenState extends ConsumerState<AvariProfileScreen> {
  static const double _avatarSize = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).isAuthenticated) {
        ref.read(avariProfileProvider.notifier).load(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final state = ref.watch(avariProfileProvider);

    ref.listen(authProvider, (previous, next) {
      if (!next.isBootstrapping &&
          next.isAuthenticated &&
          previous?.isAuthenticated != true) {
        ref.read(avariProfileProvider.notifier).load(force: true);
      }
    });

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Avari', icon: Icons.person_outline),
      ],
      child: !auth.isAuthenticated && !auth.isBootstrapping
          ? Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign in to view your Avari profile',
                      style: context.appTypography.body,
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.gapMd,
                    FilledButton(
                      onPressed: () => Nav.push(context, AppPaths.account),
                      child: const Text('Open Account'),
                    ),
                  ],
                ),
              ),
            )
          : state.isLoading && state.profile == null
              ? const Center(child: CircularProgressIndicator())
              : state.errorMessage != null && state.profile == null
                  ? Center(
                      child: Padding(
                        padding: AppSpacing.screenPadding,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.errorMessage!,
                              style: context.appTypography.body.copyWith(
                                color: context.appColors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.gapMd,
                            FilledButton(
                              onPressed: () => ref
                                  .read(avariProfileProvider.notifier)
                                  .load(force: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(avariProfileProvider.notifier)
                          .load(force: true),
                      child: ListView(
                        padding: AppSpacing.screenPadding,
                        children: [
                          if (state.profile != null)
                            ..._profileBody(context, state.profile!),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _profileBody(BuildContext context, AvariProfile profile) {
    final identity = profile.identity;
    final scheme = context.appColorScheme;
    return [
      Center(
        child: Column(
          children: [
            SizedBox(
              width: _avatarSize,
              height: _avatarSize,
              child: _IdentityAvatar(avatarUrl: identity.avatarUrl),
            ),
            AppSpacing.gapSm,
            Text(
              identity.displayName,
              style: context.appTypography.h3,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapXxs,
            Text(
              identity.title,
              style: context.appTypography.caption.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      AppSpacing.gapLg,
      _SectionTitle(text: 'Rank & XP'),
      _KeyValue('Level', '${profile.rank.level}'),
      _KeyValue('XP', '${profile.rank.xp}'),
      if (profile.rank.label != null && profile.rank.label!.isNotEmpty)
        _KeyValue('Rank', profile.rank.label!),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Titles'),
      Text(
        profile.titles.isEmpty ? 'None yet' : profile.titles.join(' · '),
        style: context.appTypography.body,
      ),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Kin'),
      Text(
        profile.kin == null ? 'Not claimed yet' : profile.kin.toString(),
        style: context.appTypography.bodyMuted,
      ),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Mastery'),
      _KeyValue('Designs tracked', '${profile.mastery.designsTracked}'),
      if (profile.mastery.top.isEmpty)
        Text('No mastery yet', style: context.appTypography.bodyMuted)
      else
        for (final item in profile.mastery.top)
          Text(item, style: context.appTypography.body),
      AppSpacing.gapMd,
      _SectionTitle(text: 'Stats'),
      _KeyValue('Matches', '${profile.stats.matchesPlayed}'),
      _KeyValue('Wins', '${profile.stats.wins}'),
      _KeyValue('Flips', '${profile.stats.flips}'),
    ];
  }
}

class _IdentityAvatar extends StatelessWidget {
  const _IdentityAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveMediaUrl(avatarUrl);
    final scheme = context.appColorScheme;
    return ClipOval(
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: url.isEmpty
            ? Icon(
                Icons.person_outline,
                size: AppSpacing.xxl,
                color: scheme.onSurfaceVariant,
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.person_outline,
                  size: AppSpacing.xxl,
                  color: scheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(text, style: context.appTypography.title),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.appTypography.caption.copyWith(
                color: context.appColorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(value, style: context.appTypography.body),
        ],
      ),
    );
  }
}
