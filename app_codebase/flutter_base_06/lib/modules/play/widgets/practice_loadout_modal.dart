import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../avari/avari_models.dart';
import '../../avari/avari_notifier.dart';
import '../game_controls_prefs.dart';
import '../play_models.dart';

/// Practice setup: pick owned slammer only (Arcori auto-assigned from collection).
Future<PracticeLoadout?> showPracticeLoadoutModal(BuildContext context) {
  return AppModal.showCenteredShell<PracticeLoadout>(
    context,
    title: 'Practice slammer',
    barrierDismissible: true,
    child: const _PracticeLoadoutBody(),
  );
}

class _PracticeLoadoutBody extends ConsumerStatefulWidget {
  const _PracticeLoadoutBody();

  @override
  ConsumerState<_PracticeLoadoutBody> createState() =>
      _PracticeLoadoutBodyState();
}

class _PracticeLoadoutBodyState extends ConsumerState<_PracticeLoadoutBody> {
  bool _loading = true;
  String? _error;
  AvariInventoryItem? _autoArcori;
  List<AvariInventoryItem> _slammers = const [];
  String? _slammerId;

  static const _fallbackArcori = AvariInventoryItem(
    designId: 'ANM-TIG-GEN001-0001',
    displayName: 'Tiger',
    imageUrl: '/catalog-media/genesis/animals/ANM-TIG-GEN001-0001.webp',
    color: '#C6A15B',
  );

  static const _fallbackSlammer = AvariInventoryItem(
    designId: 'SLM-STR-GEN001-0001',
    displayName: 'Starter Slammer',
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(gameControlsProvider.notifier).reload();
    final equipped = ref.read(gameControlsProvider).equippedSlammerId;

    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _autoArcori = _fallbackArcori;
        _slammers = const [_fallbackSlammer];
        _slammerId = _pickDefaultSlammer(const [_fallbackSlammer], equipped);
        _error = 'Offline defaults — sign in to use your collection';
        _loading = false;
      });
      return;
    }

    await ref.read(avariProfileProvider.notifier).load(force: true);
    if (!mounted) return;
    final state = ref.read(avariProfileProvider);
    final profile = state.profile;
    if (profile == null) {
      setState(() {
        _error = state.errorMessage?.trim().isNotEmpty == true
            ? state.errorMessage
            : 'Could not load your collection';
        _loading = false;
      });
      return;
    }

    final arcori = profile.access.where((e) => e.designId.isNotEmpty).toList();
    final slammers =
        profile.slammers.where((e) => e.designId.isNotEmpty).toList();
    setState(() {
      _autoArcori = arcori.isNotEmpty ? arcori.first : _fallbackArcori;
      _slammers = slammers;
      _slammerId = _pickDefaultSlammer(slammers, equipped);
      _error = slammers.isEmpty
          ? 'Your collection needs at least one slammer.'
          : null;
      _loading = false;
    });
  }

  String? _pickDefaultSlammer(
    List<AvariInventoryItem> list,
    String equipped,
  ) {
    if (list.isEmpty) return null;
    if (list.any((e) => e.designId == equipped)) return equipped;
    return list.first.designId;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_error != null) ...[
          Text(_error!, style: context.appTypography.bodySmall),
          AppSpacing.gapSm,
        ],
        Text('Slammer', style: context.appTypography.label),
        AppSpacing.gapXs,
        DropdownButtonFormField<String>(
          value: _slammerId,
          items: [
            for (final e in _slammers)
              DropdownMenuItem(value: e.designId, child: Text(e.displayName)),
          ],
          onChanged: _slammers.isEmpty
              ? null
              : (v) => setState(() => _slammerId = v),
        ),
        AppSpacing.gapLg,
        FilledButton(
          onPressed: (_autoArcori != null && _slammerId != null)
              ? () {
                  final arcori = _autoArcori!;
                  AppModal.dismiss(
                    context,
                    PracticeLoadout(
                      arcoriId: arcori.designId,
                      slammerId: _slammerId!,
                      arcoriImageUrl: arcori.imageUrl,
                      arcoriColor: arcori.color,
                    ),
                  );
                }
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
