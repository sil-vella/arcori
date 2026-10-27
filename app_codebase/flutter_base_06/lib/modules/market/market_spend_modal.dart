import 'package:flutter/material.dart';

import '../../core/errors/error_policy.dart';
import '../../core/modal/modal.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/economy_icon.dart';
import '../avari/avari_api.dart';
import 'market_api.dart';

/// Confirm a Market buy or charge, then show the result in the same modal.
///
/// Returns `true` when the spend succeeded.
Future<bool> showMarketSpendModal(
  BuildContext context, {
  required String title,
  required String confirmBody,
  required String confirmLabel,
  required Future<AvariApiOutcome<MarketPurchaseResult>> Function() send,
  required String Function(MarketPurchaseResult result) successBody,
}) async {
  final result = await AppModal.showCentered<bool>(
    context,
    barrierDismissible: false,
    builder: (ctx) => Theme(
      data: AppTheme.dark,
      child: _MarketSpendModal(
        title: title,
        confirmBody: confirmBody,
        confirmLabel: confirmLabel,
        send: send,
        successBody: successBody,
      ),
    ),
  );
  return result == true;
}

class _MarketSpendModal extends StatefulWidget {
  const _MarketSpendModal({
    required this.title,
    required this.confirmBody,
    required this.confirmLabel,
    required this.send,
    required this.successBody,
  });

  final String title;
  final String confirmBody;
  final String confirmLabel;
  final Future<AvariApiOutcome<MarketPurchaseResult>> Function() send;
  final String Function(MarketPurchaseResult result) successBody;

  @override
  State<_MarketSpendModal> createState() => _MarketSpendModalState();
}

class _MarketSpendModalState extends State<_MarketSpendModal> {
  bool _working = false;
  String? _resultBody;
  bool _success = false;

  bool get _done => _resultBody != null;

  Future<void> _confirm() async {
    if (_working || _done) return;
    setState(() => _working = true);
    final outcome = await widget.send();
    if (!mounted) return;
    if (!outcome.isSuccess || outcome.data == null) {
      final error = outcome.error;
      if (error != null) {
        actionForApiError(error, isWebSocket: false);
      }
      setState(() {
        _working = false;
        _success = false;
        _resultBody = outcome.isNetworkError
            ? 'Network error'
            : (error?.message ?? 'Purchase failed');
      });
      return;
    }
    setState(() {
      _working = false;
      _success = true;
      _resultBody = widget.successBody(outcome.data!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _resultBody ?? widget.confirmBody;
    return AppCenteredModal(
      title: widget.title,
      showCloseButton: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const EconomyIcon(EconomyMark.goldArcori, size: 48),
              AppSpacing.gapSm,
              Expanded(
                child: Text(
                  body,
                  style: context.appTypography.body.copyWith(
                    color: AppColors.onSurfaceDark,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          if (!_done) ...[
            FilledButton.icon(
              style: context.appButtons.primary.filled,
              onPressed: _working ? null : _confirm,
              icon: _working
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const EconomyIcon(EconomyMark.goldArcori, size: 22),
              label: Text(widget.confirmLabel),
            ),
            AppSpacing.gapSm,
            OutlinedButton(
              style: context.appButtons.tertiary.outlined,
              onPressed: _working
                  ? null
                  : () => AppModal.dismiss(context, false),
              child: const Text('Cancel'),
            ),
          ] else
            FilledButton(
              style: context.appButtons.primary.filled,
              onPressed: () => AppModal.dismiss(context, _success),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }
}
