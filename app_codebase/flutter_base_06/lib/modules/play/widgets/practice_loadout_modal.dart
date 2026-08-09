import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../velora/velora_api.dart';
import '../play_models.dart';

/// Minimal practice loadout: pick 1 circulating Arcori + 1 slammer.
Future<PracticeLoadout?> showPracticeLoadoutModal(BuildContext context) {
  return AppModal.showCenteredShell<PracticeLoadout>(
    context,
    title: 'Practice loadout',
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
  static const _fallbackArcori = [
    ('ANM-TIG-GEN001-0001', 'Tiger'),
    ('ANM-WTI-GEN001-0002', 'White Tiger'),
  ];
  static const _fallbackSlammers = [
    ('SLM-STR-GEN001-0001', 'Starter Slammer'),
    ('SLM-TTN-GEN001-0002', 'Titan Slammer'),
  ];

  bool _loading = true;
  String? _error;
  List<(String id, String label)> _arcori = const [];
  List<(String id, String label)> _slammers = const [];
  String? _arcoriId;
  String? _slammerId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _arcori = _fallbackArcori;
        _slammers = _fallbackSlammers;
        _arcoriId = _arcori.first.$1;
        _slammerId = _slammers.first.$1;
        _loading = false;
      });
      return;
    }

    final api = VeloraApiClient();
    final animals = await api.fetchIndex(accessToken: token, theme: 'Animals');
    final slammers = await api.fetchIndex(accessToken: token, theme: 'Slammers');

    if (!mounted) return;

    final arcoriItems = <(String, String)>[];
    if (animals.isSuccess) {
      for (final d in animals.data!.items.take(12)) {
        if (d.internalId.isEmpty) continue;
        arcoriItems.add((d.internalId, d.displayName));
      }
    }
    final slammerItems = <(String, String)>[];
    if (slammers.isSuccess) {
      for (final d in slammers.data!.items.take(12)) {
        if (d.internalId.isEmpty) continue;
        slammerItems.add((d.internalId, d.displayName));
      }
    }

    setState(() {
      _arcori = arcoriItems.isNotEmpty ? arcoriItems : _fallbackArcori;
      _slammers = slammerItems.isNotEmpty ? slammerItems : _fallbackSlammers;
      _arcoriId = _arcori.first.$1;
      _slammerId = _slammers.first.$1;
      _error = (!animals.isSuccess && !slammers.isSuccess)
          ? 'Using offline defaults'
          : null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
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
        Text('Arcori', style: context.appTypography.label),
        AppSpacing.gapXs,
        DropdownButtonFormField<String>(
          value: _arcoriId,
          items: [
            for (final e in _arcori)
              DropdownMenuItem(value: e.$1, child: Text(e.$2)),
          ],
          onChanged: (v) => setState(() => _arcoriId = v),
        ),
        AppSpacing.gapMd,
        Text('Slammer', style: context.appTypography.label),
        AppSpacing.gapXs,
        DropdownButtonFormField<String>(
          value: _slammerId,
          items: [
            for (final e in _slammers)
              DropdownMenuItem(value: e.$1, child: Text(e.$2)),
          ],
          onChanged: (v) => setState(() => _slammerId = v),
        ),
        AppSpacing.gapLg,
        FilledButton(
          onPressed: (_arcoriId != null && _slammerId != null)
              ? () => AppModal.dismiss(
                    context,
                    PracticeLoadout(
                      arcoriId: _arcoriId!,
                      slammerId: _slammerId!,
                    ),
                  )
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
