import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../../core/screen/module_screen_registrar.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../../avari/avari_notifier.dart';
import '../../match/input/slam_motion_capability.dart';
import '../game_controls_prefs.dart';
import '../slam_control_mode_ui.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Equipped slammer + exclusive slam control mode (accel vs touch).
class GameControlsScreen extends ConsumerStatefulWidget {
  const GameControlsScreen({super.key});

  @override
  ConsumerState<GameControlsScreen> createState() => _GameControlsScreenState();
}

class _GameControlsScreenState extends ConsumerState<GameControlsScreen> {
  bool _loadingInventory = true;
  String? _inventoryError;
  List<(String id, String label)> _slammers = const [];
  bool? _motionAvailable;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(gameControlsProvider.notifier).reload();
      await _loadOwnedSlammers();
      final motion = await probeSlamShakeAvailable();
      if (mounted) setState(() => _motionAvailable = motion);
    });
  }

  Future<void> _loadOwnedSlammers() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _slammers = const [];
        _inventoryError = 'Sign in to load your slammers';
        _loadingInventory = false;
      });
      return;
    }

    await ref.read(avariProfileProvider.notifier).load(force: true);
    if (!mounted) return;
    final state = ref.read(avariProfileProvider);
    if (state.profile == null) {
      String msg = state.errorMessage?.trim() ?? 'Could not load slammers';
      if (state.errorMessage == null && LOGGING_SWITCH) {
        customlog('gameControls: avari profile empty');
      }
      if (LOGGING_SWITCH) {
        customlog('gameControls: inventory fail msg=$msg');
      }
      setState(() {
        _slammers = const [];
        _inventoryError = msg;
        _loadingInventory = false;
      });
      return;
    }

    final items = <(String, String)>[];
    for (final s in state.profile!.slammers) {
      if (s.designId.isEmpty) continue;
      items.add((s.designId, s.displayName));
    }

    final equipped = ref.read(gameControlsProvider).equippedSlammerId.trim();
    if (items.isNotEmpty && items.every((e) => e.$1 != equipped)) {
      await ref
          .read(gameControlsProvider.notifier)
          .setEquippedSlammerId(items.first.$1);
    }

    if (!mounted) return;
    setState(() {
      _slammers = items;
      _inventoryError = items.isEmpty
          ? 'No slammers in your collection yet.'
          : null;
      _loadingInventory = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(gameControlsProvider);
    final equipped = prefs.equippedSlammerId;
    final mode = prefs.slamControlMode;
    final motionOk = _motionAvailable ?? false;

    final slammerOptions = List<(String, String)>.from(_slammers);
    String? dropdownValue;
    if (slammerOptions.isNotEmpty) {
      dropdownValue = slammerOptions.any((e) => e.$1 == equipped)
          ? equipped
          : slammerOptions.first.$1;
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
              'From your collection. Used for online matches and practice defaults.',
              style: context.appTypography.bodySmall,
            ),
            AppSpacing.gapSm,
            if (_loadingInventory)
              const Center(child: CircularProgressIndicator())
            else if (slammerOptions.isEmpty)
              Text(
                _inventoryError ?? 'No slammers in your collection yet.',
                style: context.appTypography.bodySmall,
              )
            else ...[
              DropdownButtonFormField<String>(
                value: dropdownValue,
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
              if (_inventoryError != null) ...[
                AppSpacing.gapXs,
                Text(_inventoryError!, style: context.appTypography.bodySmall),
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
                  label: Text(SlamControlMode.accel.label),
                  icon: Icon(SlamControlMode.accel.icon),
                  enabled: motionOk,
                ),
                ButtonSegment(
                  value: SlamControlMode.touch,
                  label: Text(SlamControlMode.touch.label),
                  icon: Icon(SlamControlMode.touch.icon),
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
              mode.caption,
              style: context.appTypography.bodySmall,
            ),
            if (!motionOk) ...[
              AppSpacing.gapXs,
              Text(
                'Motion sensors unavailable — touch mode only.',
                style: context.appTypography.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
