import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/error_policy.dart';
import '../../core/modal/modal.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/theme/theme.dart';
import '../../utils/dev_logger.dart';
import 'legacy_api.dart';
import 'legacy_mint_complete_modal.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

typedef LegacyAccessTokenGetter = String? Function();
typedef LegacyProfileReloader = Future<void> Function();

LegacyAccessTokenGetter? _tokenGetter;
LegacyProfileReloader? _profileReloader;

/// Wire from [AppBootstrap] so deep-link complete can auth + refresh profile.
void bindLegacyPreserveDeepLink({
  required LegacyAccessTokenGetter accessToken,
  LegacyProfileReloader? onMintComplete,
}) {
  _tokenGetter = accessToken;
  _profileReloader = onMintComplete;
}

/// Deep link: `arcori://legacy-preserve-complete?intentId=&orderId=`
class LegacyPreserveDeepLinkHandler {
  LegacyPreserveDeepLinkHandler._();

  static ({String intentId, String orderId})? paramsFromUri(Uri uri) {
    final intentId = uri.queryParameters['intentId']?.trim() ?? '';
    final orderId = uri.queryParameters['orderId']?.trim() ?? '';
    if (intentId.isEmpty || orderId.isEmpty) return null;

    if (uri.scheme == 'arcori') {
      final host = uri.host.toLowerCase();
      if (host == 'legacy-preserve-complete') {
        return (intentId: intentId, orderId: orderId);
      }
      if (uri.pathSegments.isNotEmpty &&
          uri.pathSegments.first.toLowerCase() ==
              'legacy-preserve-complete') {
        return (intentId: intentId, orderId: orderId);
      }
      return null;
    }

    final path = uri.path;
    if (path == AppPaths.legacyPreserveComplete ||
        path.endsWith(AppPaths.legacyPreserveComplete)) {
      return (intentId: intentId, orderId: orderId);
    }
    return null;
  }

  static void onReturn({
    required String intentId,
    required String orderId,
  }) {
    unawaited(_complete(intentId: intentId, orderId: orderId));
  }

  static Future<void> _complete({
    required String intentId,
    required String orderId,
  }) async {
    final token = _tokenGetter?.call()?.trim() ?? '';
    if (token.isEmpty) {
      if (LOGGING_SWITCH) {
        customlog('legacy: preserve complete skipped — no token');
      }
      return;
    }
    LegacyApiOutcome<LegacyMintComplete> outcome =
        await LegacyApiClient().preserveComplete(
      accessToken: token,
      intentId: intentId,
      orderId: orderId,
    );

    for (var i = 0;
        i < 4 &&
            outcome.isSuccess &&
            outcome.data?.status == 'processing';
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      outcome = await LegacyApiClient().preserveComplete(
        accessToken: token,
        intentId: intentId,
        orderId: orderId,
      );
    }

    if (!outcome.isSuccess) {
      final err = outcome.error;
      if (err != null) actionForApiError(err, isWebSocket: false);
      return;
    }
    final mint = outcome.data!;
    if (mint.status == 'processing') return;
    final reloader = _profileReloader;
    if (reloader != null) unawaited(reloader());
    await showLegacyMintCompleteModal(mint);
  }
}

List<LegacyOffer> legacyOffersFromNotificationData(Map<String, dynamic> data) {
  final raw = data['legacyOffers'];
  if (raw is! List) return const [];
  final out = <LegacyOffer>[];
  for (final row in raw) {
    if (row is! Map) continue;
    final offer = LegacyOffer.fromJson(Map<String, dynamic>.from(row));
    if (offer.designId.isEmpty) continue;
    out.add(offer);
  }
  return out;
}

/// Selected → stub preserve complete; unselected first-offers → leader window.
Future<LegacyMintComplete?> submitLegacyPreserveSelection({
  required String accessToken,
  required List<LegacyOffer> selected,
  required List<LegacyOffer> decline,
}) async {
  if (selected.isEmpty && decline.isEmpty) return null;

  if (selected.isEmpty) {
    await declineLegacyOffers(accessToken: accessToken, offers: decline);
    return null;
  }

  final first = selected.first;
  final start = await LegacyApiClient().preserveStart(
    accessToken: accessToken,
    designId: first.designId,
    generationNumber: first.generationNumber,
    offers: selected,
    declineOffers: decline,
  );
  if (!start.isSuccess) {
    if (start.error != null) {
      actionForApiError(start.error!, isWebSocket: false);
    }
    return null;
  }
  final data = start.data!;
  if (LOGGING_SWITCH) {
    customlog(
      'legacy: stub preserve done intent=${data.intentId} '
      'n=${data.items.length} '
      'serials=${data.items.map((i) => i.serial).join(",")}',
    );
  }
  final reloader = _profileReloader;
  if (reloader != null) unawaited(reloader());
  return data.toMintComplete();
}

Future<void> declineLegacyOffers({
  required String accessToken,
  required List<LegacyOffer> offers,
}) async {
  final firstOffers =
      offers.where((o) => o.canPreserveAsFirstOffer).toList();
  if (firstOffers.isEmpty) return;
  final first = firstOffers.first;
  final out = await LegacyApiClient().decline(
    accessToken: accessToken,
    designId: first.designId,
    generationNumber: first.generationNumber,
    offers: firstOffers,
  );
  if (!out.isSuccess && out.error != null) {
    actionForApiError(out.error!, isWebSocket: false);
  }
}

/// Selectable celebrate body — check which designs to preserve.
class LegacyOfferCelebrateBody extends StatefulWidget {
  const LegacyOfferCelebrateBody({
    required this.offers,
    this.actionsBuilder,
    super.key,
  });

  final List<LegacyOffer> offers;

  /// Builds actions with current [selected] / [unselected] (unselected → leader).
  final List<Widget> Function(
    BuildContext context,
    List<LegacyOffer> selected,
    List<LegacyOffer> unselected,
  )? actionsBuilder;

  @override
  State<LegacyOfferCelebrateBody> createState() =>
      _LegacyOfferCelebrateBodyState();
}

class _LegacyOfferCelebrateBodyState extends State<LegacyOfferCelebrateBody> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    // Default: all selected; user unchecks what they do not want.
    _selectedIds = {
      for (final o in widget.offers) o.designId,
    };
  }

  List<LegacyOffer> get _selected =>
      widget.offers.where((o) => _selectedIds.contains(o.designId)).toList();

  List<LegacyOffer> get _unselected =>
      widget.offers.where((o) => !_selectedIds.contains(o.designId)).toList();

  @override
  Widget build(BuildContext context) {
    final copy = widget.offers.any((o) => o.canPreserveAsLeader)
        ? 'Select which Arcori to preserve into the Museum. '
            'Unchecked designs open the leader window.'
        : 'You reached the preservation threshold first. '
            'Select which to preserve; unchecked open the leader window.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy, style: context.appTypography.body),
        AppSpacing.gapMd,
        for (final offer in widget.offers)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _selectedIds.contains(offer.designId),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _selectedIds.add(offer.designId);
                } else {
                  _selectedIds.remove(offer.designId);
                }
              });
            },
            title: Text(
              offer.serial,
              style: context.appTypography.body,
            ),
            subtitle: Text(
              'Gen ${offer.generationNumber}',
              style: context.appTypography.bodySmall,
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        if (widget.actionsBuilder != null) ...[
          AppSpacing.gapMd,
          ...widget.actionsBuilder!(context, _selected, _unselected),
        ],
      ],
    );
  }
}

/// Standalone selection shell (non-notification callers).
Future<void> showLegacyPreserveOfferModal({
  required BuildContext context,
  required List<LegacyOffer> offers,
  required String accessToken,
}) async {
  final preservable = offers.where((o) => o.canPreserve).toList();
  if (preservable.isEmpty) return;

  final result = await AppModal.showCenteredShell<
      ({List<LegacyOffer> selected, List<LegacyOffer> decline})>(
    context,
    title: preservable.length > 1
        ? 'Preserve Legacy (${preservable.length})'
        : 'Preserve Legacy',
    barrierDismissible: false,
    showCloseButton: true,
    child: LegacyOfferCelebrateBody(
      offers: preservable,
      actionsBuilder: (ctx, selected, unselected) => [
        FilledButton(
          onPressed: selected.isEmpty && unselected.isEmpty
              ? null
              : () => Navigator.of(ctx).pop(
                    (selected: selected, decline: unselected),
                  ),
          child: Text(
            selected.isEmpty
                ? 'Open leader window'
                : (selected.length == 1
                    ? 'Preserve selected'
                    : 'Preserve ${selected.length} selected'),
          ),
        ),
        AppSpacing.gapSm,
        OutlinedButton(
          onPressed: () => Navigator.of(ctx).pop(
            (selected: <LegacyOffer>[], decline: preservable),
          ),
          child: const Text('Preserve none'),
        ),
      ],
    ),
  );

  if (!context.mounted || result == null) return;
  final mint = await submitLegacyPreserveSelection(
    accessToken: accessToken,
    selected: result.selected,
    decline: result.decline,
  );
  if (mint != null && context.mounted) {
    await showLegacyMintCompleteModal(mint);
  }
}
