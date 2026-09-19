import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/media_url.dart';
import '../../core/modal/modal.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import '../avari/avari_models.dart';
import '../avari/avari_notifier.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Pick one open Legacy-window Arcori before queueing Preservation Chase.
/// Returns the chosen [AvariInventoryItem] or null if cancelled / empty.
Future<AvariInventoryItem?> showActiveWindowPickerModal({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return AppModal.showCenteredShell<AvariInventoryItem>(
    context,
    title: 'Choose Legacy window',
    child: const _ActiveWindowPickerBody(),
  );
}

class _ActiveWindowPickerBody extends ConsumerStatefulWidget {
  const _ActiveWindowPickerBody();

  @override
  ConsumerState<_ActiveWindowPickerBody> createState() =>
      _ActiveWindowPickerBodyState();
}

class _ActiveWindowPickerBodyState
    extends ConsumerState<_ActiveWindowPickerBody> {
  bool _loading = true;
  String? _error;
  List<AvariInventoryItem> _windows = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    await ref.read(avariProfileProvider.notifier).load(force: true);
    if (!mounted) return;
    final profile = ref.read(avariProfileProvider).profile;
    final windows = profile?.preservationWindows ?? const [];
    if (LOGGING_SWITCH) {
      customlog(
        'special_events: active_window picker n=${windows.length}',
      );
    }
    setState(() {
      _loading = false;
      _windows = windows;
      _error = windows.isEmpty
          ? 'No open Legacy windows in your collection.'
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Play with one Arcori currently under Legacy pressure.',
            style: context.appTypography.bodySmall,
          ),
          AppSpacing.gapMd,
          for (var i = 0; i < _windows.length; i++) ...[
            if (i > 0) AppSpacing.gapSm,
            _WindowRow(item: _windows[i]),
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

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.item});

  final AvariInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final url = (item.imageUrl ?? '').trim().isNotEmpty
        ? resolveMediaUrl(item.imageUrl!)
        : '';
    final mastery = item.masteryOverMintReach;

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
                      Text(mastery, style: context.appTypography.bodySmall),
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
