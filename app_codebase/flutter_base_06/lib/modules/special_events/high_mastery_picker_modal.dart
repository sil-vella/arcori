import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/media_url.dart';
import '../../core/modal/modal.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import '../avari/avari_models.dart';
import '../avari/avari_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Pick one circulating Arcori at [minMasteryRatio]× mintReach (High Mastery SE).
Future<AvariInventoryItem?> showHighMasteryPickerModal({
  required BuildContext context,
  required WidgetRef ref,
  double minMasteryRatio = 0.8,
}) {
  return AppModal.showCenteredShell<AvariInventoryItem>(
    context,
    title: 'Choose High Mastery',
    child: _HighMasteryPickerBody(minMasteryRatio: minMasteryRatio),
  );
}

bool meetsMinMasteryRatio(AvariInventoryItem item, double ratio) {
  final reach = item.mintReach;
  if (reach == null || reach <= 0) return false;
  final need = (ratio * reach).ceil();
  return item.masteryPoints >= need;
}

class _HighMasteryPickerBody extends ConsumerStatefulWidget {
  const _HighMasteryPickerBody({required this.minMasteryRatio});

  final double minMasteryRatio;

  @override
  ConsumerState<_HighMasteryPickerBody> createState() =>
      _HighMasteryPickerBodyState();
}

class _HighMasteryPickerBodyState
    extends ConsumerState<_HighMasteryPickerBody> {
  bool _loading = true;
  String? _error;
  List<AvariInventoryItem> _items = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(avariProfileProvider.notifier).load(force: true);
    if (!mounted) return;
    final profile = ref.read(avariProfileProvider).profile;
    final ratio = widget.minMasteryRatio > 0 ? widget.minMasteryRatio : 0.8;
    final eligible = (profile?.access ?? const <AvariInventoryItem>[])
        .where((item) => meetsMinMasteryRatio(item, ratio))
        .toList();
    if (LOGGING_SWITCH) {
      customlog(
        'special_events: high_mastery picker n=${eligible.length} '
        'ratio=$ratio access=${profile?.access.length ?? 0}',
      );
    }
    setState(() {
      _loading = false;
      _items = eligible;
      _error = eligible.isEmpty
          ? 'No Arcori at ${(ratio * 100).round()}%+ Preservation reach.'
          : null;
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
    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_error!, style: context.appTypography.body),
          AppSpacing.gapMd,
          OutlinedButton(
            onPressed: () => AppModal.dismiss(context),
            child: const Text('Close'),
          ),
        ],
      );
    }
    final pct = (widget.minMasteryRatio * 100).round();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Play with one circulating Arcori at $pct%+ of its Preservation reach.',
            style: context.appTypography.bodySmall,
          ),
          AppSpacing.gapMd,
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) AppSpacing.gapSm,
            _HighMasteryRow(
              item: _items[i],
              minMasteryRatio: widget.minMasteryRatio,
            ),
          ],
          AppSpacing.gapMd,
          OutlinedButton(
            onPressed: () => AppModal.dismiss(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _HighMasteryRow extends StatelessWidget {
  const _HighMasteryRow({
    required this.item,
    required this.minMasteryRatio,
  });

  final AvariInventoryItem item;
  final double minMasteryRatio;

  @override
  Widget build(BuildContext context) {
    final url = (item.imageUrl ?? '').trim().isNotEmpty
        ? resolveMediaUrl(item.imageUrl!)
        : '';
    final mastery = item.masteryOverMintReach;
    final reach = item.mintReach ?? 0;
    final need = reach > 0 ? (minMasteryRatio * reach).ceil() : 0;

    return Material(
      color: context.appColorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => AppModal.dismiss(context, item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url.isEmpty
                      ? ColoredBox(
                          color: context.appColorScheme.surface,
                          child: const Icon(Icons.pets),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.pets),
                        ),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.displayName, style: context.appTypography.label),
                    if (mastery.isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Text(
                        need > 0 ? '$mastery (≥$need)' : mastery,
                        style: context.appTypography.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
