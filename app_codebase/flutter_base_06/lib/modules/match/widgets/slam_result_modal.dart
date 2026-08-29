import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/modal/modal.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const Duration kSlamResultAutoClose = Duration(seconds: 3);

/// Non-blocking 3s slam-result overlay for the acting player only.
///
/// Fire-and-forget — do **not** await; match turns continue underneath.
void showSlamResultModal(
  BuildContext context, {
  required Map<String, dynamic> lastEvent,
  required int actorScoreDelta,
}) {
  if (LOGGING_SWITCH) {
    customlog(
      'slamResultModal: show result=${lastEvent['result']} '
      'delta=$actorScoreDelta version=${lastEvent['version']}',
    );
  }
  unawaited(
    AppModal.showCenteredShell<void>(
      context,
      title: 'Slam',
      showCloseButton: true,
      barrierDismissible: true,
      child: _SlamResultBody(
        lastEvent: lastEvent,
        actorScoreDelta: actorScoreDelta,
        autoClose: kSlamResultAutoClose,
      ),
    ),
  );
}

class _SlamResultBody extends StatefulWidget {
  const _SlamResultBody({
    required this.lastEvent,
    required this.actorScoreDelta,
    required this.autoClose,
  });

  final Map<String, dynamic> lastEvent;
  final int actorScoreDelta;
  final Duration autoClose;

  @override
  State<_SlamResultBody> createState() => _SlamResultBodyState();
}

class _SlamResultBodyState extends State<_SlamResultBody> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.autoClose, _close);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    AppModal.dismiss(context);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.lastEvent['result']?.toString() ?? 'miss';
    final isFlip = result == 'flip';
    final outcome = widget.lastEvent['outcome'];
    final flipped = outcome is Map && outcome['flippedPieceIds'] is List
        ? (outcome['flippedPieceIds'] as List).length
        : 0;
    final delta = widget.actorScoreDelta;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isFlip ? 'FLIP' : 'MISS',
          textAlign: TextAlign.center,
          style: context.appTypography.label.copyWith(
            fontSize: 28,
            letterSpacing: 2,
            color: isFlip ? AppColors.primary : context.appTypography.body.color,
          ),
        ),
        AppSpacing.gapSm,
        Text(
          isFlip ? '$flipped disc${flipped == 1 ? '' : 's'} flipped' : 'No flips',
          textAlign: TextAlign.center,
          style: context.appTypography.body,
        ),
        if (delta != 0) ...[
          AppSpacing.gapXs,
          Text(
            delta > 0 ? '+$delta score' : '$delta score',
            textAlign: TextAlign.center,
            style: context.appTypography.bodySmall,
          ),
        ],
        AppSpacing.gapSm,
        Text(
          'Closes in ${widget.autoClose.inSeconds}s',
          textAlign: TextAlign.center,
          style: context.appTypography.bodySmall,
        ),
      ],
    );
  }
}
