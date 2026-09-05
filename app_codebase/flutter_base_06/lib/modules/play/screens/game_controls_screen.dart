import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/errors/error_policy.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../../match/input/slam_motion_capability.dart';
import '../../match/state/match_notifier.dart';
import '../../velora/velora_api.dart';
import '../game_controls_prefs.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Equipped slammer + exclusive slam control mode (accel vs touch).
class GameControlsScreen extends ConsumerStatefulWidget {
  const GameControlsScreen({super.key});

  @override
  ConsumerState<GameControlsScreen> createState() => _GameControlsScreenState();
}

class _GameControlsScreenState extends ConsumerState<GameControlsScreen> {
  static const _fallbackSlammers = [
    ('SLM-STR-GEN001-0001', 'Starter Slammer'),
    ('SLM-TTN-GEN001-0002', 'Titan Slammer'),
  ];

  bool _loadingCatalog = true;
  String? _catalogError;
  List<(String id, String label)> _slammers = const [];
  bool? _motionAvailable;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(gameControlsProvider.notifier).reload();
      await _loadCatalog();
      final motion = await probeSlamShakeAvailable();
      if (mounted) setState(() => _motionAvailable = motion);
    });
  }

  Future<void> _loadCatalog() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _slammers = _fallbackSlammers;
        _catalogError = null;
        _loadingCatalog = false;
      });
      return;
    }

    final outcome =
        await VeloraApiClient().fetchIndex(accessToken: token, theme: 'Slammers');
    if (!mounted) return;

    if (!outcome.isSuccess) {
      String msg = 'Could not load slammers';
      if (outcome.isNetworkError) {
        msg = 'Network error — check your connection';
      } else if (outcome.error != null) {
        actionForApiError(outcome.error!, isWebSocket: false);
        msg = outcome.error!.message;
      }
      if (LOGGING_SWITCH) {
        customlog(
          'gameControls: catalog fail code=${outcome.error?.code} msg=$msg',
        );
      }
      setState(() {
        _slammers = _fallbackSlammers;
        _catalogError = msg;
        _loadingCatalog = false;
      });
      return;
    }

    final items = <(String, String)>[];
    for (final d in outcome.data!.items.take(24)) {
      if (d.internalId.isEmpty) continue;
      items.add((d.internalId, d.displayName));
    }
    setState(() {
      _slammers = items.isNotEmpty ? items : _fallbackSlammers;
      _catalogError = items.isEmpty ? 'Using offline defaults' : null;
      _loadingCatalog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(gameControlsProvider);
    final equipped = prefs.equippedSlammerId;
    final mode = prefs.slamControlMode;
    final motionOk = _motionAvailable ?? false;

    final slammerOptions = List<(String, String)>.from(_slammers);
    if (slammerOptions.every((e) => e.$1 != equipped)) {
      slammerOptions.insert(0, (equipped, equipped));
    }

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Game Controls', icon: Icons.sports_mma_outlined),
      ],
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: ListView(
          children: [
            Text('Equipped slammer', style: context.appTypography.label),
            AppSpacing.gapXs,
            Text(
              'Used for online matchmaking and practice defaults.',
              style: context.appTypography.bodySmall,
            ),
            AppSpacing.gapSm,
            if (_loadingCatalog)
              const Center(child: CircularProgressIndicator())
            else ...[
              DropdownButtonFormField<String>(
                value: equipped,
                items: [
                  for (final s in slammerOptions)
                    DropdownMenuItem(value: s.$1, child: Text(s.$2)),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  unawaited(
                    ref
                        .read(gameControlsProvider.notifier)
                        .setEquippedSlammerId(id),
                  );
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              if (_catalogError != null) ...[
                AppSpacing.gapXs,
                Text(_catalogError!, style: context.appTypography.bodySmall),
              ],
            ],
            AppSpacing.gapLg,
            Text('Slam controls', style: context.appTypography.label),
            AppSpacing.gapXs,
            Text(
              'One mode at a time during matches.',
              style: context.appTypography.bodySmall,
            ),
            AppSpacing.gapSm,
            SegmentedButton<SlamControlMode>(
              segments: [
                ButtonSegment(
                  value: SlamControlMode.accel,
                  label: const Text('Phone motion'),
                  icon: const Icon(Icons.phone_android),
                  enabled: motionOk,
                ),
                const ButtonSegment(
                  value: SlamControlMode.touch,
                  label: Text('Touch'),
                  icon: Icon(Icons.touch_app_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (set) {
                final next = set.first;
                unawaited(
                  ref
                      .read(gameControlsProvider.notifier)
                      .setSlamControlMode(next),
                );
              },
            ),
            AppSpacing.gapSm,
            Text(
              mode == SlamControlMode.accel
                  ? 'Tilt to aim. Shake (Z) to slam.'
                  : 'Drag to aim. Swipe down to slam.',
              style: context.appTypography.bodySmall,
            ),
            if (!motionOk) ...[
              AppSpacing.gapXs,
              Text(
                'Motion sensors unavailable — touch mode only.',
                style: context.appTypography.bodySmall,
              ),
            ],
            AppSpacing.gapLg,
            Text(
              'Default stub if unset: $stubSlammerId',
              style: context.appTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
