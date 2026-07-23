import 'package:flutter/material.dart';

import '../theme/app_modal_theme.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Centered modal shell with dimmed scrim. Modules supply [child] and optional
/// [actions]; styling comes from the theme module.
class AppCenteredModal extends StatelessWidget {
  const AppCenteredModal({
    required this.child,
    this.title,
    this.actions = const [],
    this.showCloseButton = true,
    this.padding,
    super.key,
  });

  final String? title;
  final Widget child;
  final List<Widget> actions;
  final bool showCloseButton;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final modalTheme = context.appModalTheme;
    final contentPadding = padding ?? AppSpacing.screenPaddingCompact;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Material(
      color: modalTheme.surface,
      elevation: AppModalMetrics.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(modalTheme.borderRadius),
        side: BorderSide(color: modalTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: modalTheme.maxWidth,
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || showCloseButton)
              _Header(
                title: title,
                showCloseButton: showCloseButton,
              ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: contentPadding,
                child: child,
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: contentPadding.copyWith(top: 0),
                child: _ActionsRow(actions: actions),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.showCloseButton,
  });

  final String? title;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Text(title!, style: context.appTypography.title),
          ),
          if (showCloseButton)
            IconButton(
              style: context.appButtons.primary.icon,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: actions,
    );
  }
}
