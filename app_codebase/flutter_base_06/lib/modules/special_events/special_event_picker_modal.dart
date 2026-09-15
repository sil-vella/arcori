import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/media_url.dart';
import '../../core/modal/modal.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'special_events_api.dart';
import 'special_events_models.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

final specialEventsApiProvider = Provider<SpecialEventsApiClient>((ref) {
  return SpecialEventsApiClient();
});

/// Picker for active special events. Returns chosen entry or null if cancelled.
Future<SpecialEventEntry?> showSpecialEventPickerModal({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return AppModal.showCenteredShell<SpecialEventEntry>(
    context,
    title: 'Special Event',
    child: const _SpecialEventPickerBody(),
  );
}

class _SpecialEventPickerBody extends ConsumerStatefulWidget {
  const _SpecialEventPickerBody();

  @override
  ConsumerState<_SpecialEventPickerBody> createState() =>
      _SpecialEventPickerBodyState();
}

class _SpecialEventPickerBodyState
    extends ConsumerState<_SpecialEventPickerBody> {
  bool _loading = true;
  String? _error;
  List<SpecialEventEntry> _events = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final token = ref.read(authProvider).accessToken ?? '';
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Sign in to play special events.';
      });
      return;
    }
    final outcome =
        await ref.read(specialEventsApiProvider).fetchCatalog(accessToken: token);
    if (!mounted) return;
    if (!outcome.isSuccess || outcome.data == null) {
      setState(() {
        _loading = false;
        _error = outcome.isNetworkError
            ? 'Network error loading events.'
            : (outcome.error?.message ?? 'Could not load events.');
      });
      return;
    }
    if (LOGGING_SWITCH) {
      customlog(
        'special_events: picker loaded n=${outcome.data!.events.length}',
      );
    }
    setState(() {
      _loading = false;
      _events = outcome.data!.events;
      _error = _events.isEmpty ? 'No active special events.' : null;
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
          for (var i = 0; i < _events.length; i++) ...[
            if (i > 0) AppSpacing.gapSm,
            _EventRow(entry: _events[i]),
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

class _EventRow extends StatelessWidget {
  const _EventRow({required this.entry});

  final SpecialEventEntry entry;

  @override
  Widget build(BuildContext context) {
    final banner = entry.banner;
    final url = banner != null && banner.isValid
        ? resolveMediaUrl(banner.value)
        : '';
    final blocked = !entry.eligible;
    final reason = entry.blockedReason;
    final subtitle = blocked
        ? (reason == 'complete'
            ? 'Complete (${entry.progress.progressLabel})'
            : 'Unavailable (${reason ?? 'blocked'})')
        : '${entry.progress.progressLabel} matches · ${entry.feeFragments} frag fee';

    return Material(
      color: context.appColorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: blocked
            ? null
            : () => AppModal.dismiss(context, entry),
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
                          child: const Icon(Icons.event),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.event),
                        ),
                ),
              ),
              AppSpacing.gapSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: context.appTypography.label),
                    AppSpacing.gapXs,
                    Text(
                      entry.description.isNotEmpty
                          ? entry.description
                          : subtitle,
                      style: context.appTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.gapXs,
                    Text(subtitle, style: context.appTypography.bodySmall),
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
