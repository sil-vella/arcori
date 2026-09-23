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
  return AppModal.showCentered<AvariInventoryItem>(
    context,
    builder: (ctx) => Theme(
      data: AppTheme.dark,
      child: const AppCenteredModal(
        title: 'Choose Legacy window',
        child: _ActiveWindowPickerBody(),
      ),
    ),
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
        padding: AppSpacing.modalPadding,
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
            style: context.appButtons.tertiary.outlined,
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
            style: context.appButtons.tertiary.outlined,
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
      color: AppColors.surfaceDark.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(
          color: AppSurfaces.frameBronze(Brightness.dark).withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => AppModal.dismiss(context, item),
        child: Padding(
          padding: AppSpacing.modalPaddingCompact,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: url.isEmpty
                      ? ColoredBox(
                          color: AppColors.surfaceDark,
                          child: Icon(
                            Icons.pets,
                            color: AppColors.onSurfaceMutedDark,
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.pets,
                            color: AppColors.onSurfaceMutedDark,
                          ),
                        ),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: context.appTypography.label.copyWith(
                        color: AppColors.onSurfaceDark,
                      ),
                    ),
                    if (mastery.isNotEmpty) ...[
                      AppSpacing.gapXs,
                      Text(
                        mastery,
                        style: context.appTypography.bodySmall.copyWith(
                          color: AppSurfaces.frameGold(Brightness.dark),
                        ),
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
