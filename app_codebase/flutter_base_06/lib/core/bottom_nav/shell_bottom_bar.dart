import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import '../theme/theme.dart';
import 'bottom_nav_controller.dart';
import 'contracts/register_bottom_nav_contract.dart';

/// Shell bottom action bar; hidden when no screen-scoped items are active.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({required this.controller, super.key});

  final BottomNavController controller;

  static const int _kMaxVisible = 5;
  static const double barContentHeight = 56;

  /// Half of the raised Match disc, which sits above the sink fill.
  static const double playProtrusion = 28;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.itemsFor(context);
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final visible = items.take(_kMaxVisible).toList();
        final overflow = items.length > _kMaxVisible
            ? items.sublist(_kMaxVisible)
            : const <BottomNavItem>[];
        final raised = visible.whereType<BottomNavAction>().where(
              (item) => item.emphasized,
            );

        final sink = Material(
          color: AppColors.surfaceDark,
          elevation: 0,
          clipBehavior: Clip.none,
          shape: Border(
            top: BorderSide(
              color: AppColors.tertiary.withValues(alpha: 0.45),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: barContentHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final item in visible)
                    Expanded(child: _buildItem(context, item)),
                  if (overflow.isNotEmpty)
                    SizedBox(
                      width: 48,
                      child: _OverflowMenu(
                        items: overflow,
                        controller: controller,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );

        final raisedAction = raised.isEmpty ? null : raised.first;
        return Theme(
          data: AppTheme.dark,
          child: raisedAction == null
              ? sink
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: playProtrusion,
                      child: Row(
                        children: [
                          for (final item in visible)
                            Expanded(
                              child: item == raisedAction
                                  ? Center(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: raisedAction.onTap,
                                        child: const SizedBox(
                                          width: barContentHeight,
                                          height: playProtrusion,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          if (overflow.isNotEmpty) const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    sink,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, BottomNavItem item) {
    return switch (item) {
      BottomNavAction(
        :final icon,
        :final iconAsset,
        :final label,
        :final tooltip,
        :final onTap,
        :final emphasized,
      ) =>
        _BottomNavButton(
          icon: icon,
          iconAsset: iconAsset,
          label: label,
          tooltip: tooltip,
          onTap: onTap,
          emphasized: emphasized,
        ),
      BottomNavNavigate(:final icon, :final label, :final tooltip, :final path) =>
        _BottomNavButton(
          icon: icon,
          label: label,
          tooltip: tooltip,
          onTap: () => _onNavigate(context, path),
        ),
    };
  }

  void _onNavigate(BuildContext context, String path) {
    final moduleId = controller.activeModuleId();
    if (moduleId == null) {
      return;
    }
    final scope = controller.moduleScopeFor(moduleId);
    if (scope == null ||
        !BottomNavController.locationMatchesScope(path, scope)) {
      return;
    }

    final current = Nav.matchedLocation(context);
    if (current == path || (current.isEmpty ? '/' : current) == path) {
      return;
    }
    Nav.push(context, path);
  }
}

class _BottomNavButton extends StatelessWidget {
  const _BottomNavButton({
    required this.icon,
    required this.onTap,
    this.iconAsset,
    this.label,
    this.tooltip,
    this.emphasized = false,
  });

  final IconData icon;
  final String? iconAsset;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final glyph = iconAsset == null
        ? Icon(icon, size: 22)
        : Image.asset(
            iconAsset!,
            width: 22,
            height: 22,
            fit: BoxFit.contain,
          );
    if (emphasized) {
      const gold = AppColors.headingGold;
      // Circle is centered on the sink's top edge, so half of it sits above
      // the bar. The icon is twice the flat sink marks (22).
      const discSize = ShellBottomBar.barContentHeight;
      const iconSize = 44.0;
      final mark = iconAsset == null
          ? Icon(icon, color: AppColors.surfaceDark, size: iconSize)
          : Image.asset(
              iconAsset!,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            );
      final button = SizedBox(
        height: ShellBottomBar.barContentHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                label ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTypography.caption.copyWith(
                  color: gold,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              top: -discSize / 2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold,
                  border: Border.all(color: AppColors.surfaceDark, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: gold.withValues(alpha: 0.45),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: discSize,
                  height: discSize,
                  child: Center(child: mark),
                ),
              ),
            ),
          ],
        ),
      );
      return Tooltip(
        message: tooltip ?? label ?? '',
        child: InkWell(onTap: onTap, child: button),
      );
    }
    if (label != null) {
      return TextButton.icon(
        onPressed: onTap,
        icon: glyph,
        label: Text(
          label!,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.headingGold),
        ),
      );
    }
    return IconButton(
      icon: glyph,
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({
    required this.items,
    required this.controller,
  });

  final List<BottomNavItem> items;
  final BottomNavController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BottomNavItem>(
      icon: const Icon(Icons.more_horiz),
      tooltip: 'More',
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<BottomNavItem>(
            value: item,
            onTap: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                switch (item) {
                  case BottomNavAction(:final onTap):
                    onTap();
                  case BottomNavNavigate(:final path):
                    final moduleId = controller.activeModuleId();
                    if (moduleId == null) {
                      return;
                    }
                    final scope = controller.moduleScopeFor(moduleId);
                    if (scope == null ||
                        !BottomNavController.locationMatchesScope(
                          path,
                          scope,
                        )) {
                      return;
                    }
                    final current = Nav.matchedLocation(context);
                    if (current != path) {
                      Nav.push(context, path);
                    }
                }
              });
            },
            child: _OverflowMenuLabel(item: item),
          ),
      ],
    );
  }
}

class _OverflowMenuLabel extends StatelessWidget {
  const _OverflowMenuLabel({required this.item});

  final BottomNavItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      BottomNavAction(:final icon, :final iconAsset, :final label, :final tooltip) =>
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconAsset != null
                ? Image.asset(
                    iconAsset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  )
                : Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label ?? tooltip ?? ''),
          ],
        ),
      BottomNavNavigate(:final icon, :final label, :final tooltip) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label ?? tooltip ?? ''),
          ],
        ),
    };
  }
}
