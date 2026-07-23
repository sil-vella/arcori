import 'package:flutter/material.dart';

import 'app_bar_controller.dart';
import 'contracts/register_app_bar_contract.dart';

/// Shell AppBar with reserved nav slots and registrable left / center / right widgets.
class ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShellAppBar({
    required this.controller,
    required this.shellNavControls,
    super.key,
  });

  final AppBarController controller;
  final ShellNavControls shellNavControls;

  static const double _kNavSlotWidth = 48;
  static const double _kOverflowWidth = 40;
  static const double _kTitleMaxWidth = 240;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.itemsFor(context);
        final left = items.where((i) => i.slot == AppBarSlot.left).toList();
        final center = items.where((i) => i.slot == AppBarSlot.center).toList();
        final right = items.where((i) => i.slot == AppBarSlot.right).toList();

        return AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          titleSpacing: 0,
          title: LayoutBuilder(
            builder: (context, constraints) {
              final reserved =
                  (shellNavControls.showBack ? _kNavSlotWidth : 0) +
                  _kNavSlotWidth +
                  _kOverflowWidth;
              final budget = constraints.maxWidth - reserved;
              final layout = _fitItems(
                context: context,
                budget: budget,
                left: left,
                center: center,
                right: right,
              );

              return Row(
                children: [
                  if (shellNavControls.showBack)
                    SizedBox(
                      width: _kNavSlotWidth,
                      child: BackButton(onPressed: shellNavControls.onBack),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        ...layout.left.map((i) => _buildItem(context, i)),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: layout.center
                                .map((i) => _buildItem(context, i))
                                .toList(),
                          ),
                        ),
                        ...layout.right.map((i) => _buildItem(context, i)),
                      ],
                    ),
                  ),
                  if (layout.overflow.isNotEmpty)
                    SizedBox(
                      width: _kOverflowWidth,
                      child: _OverflowMenu(items: layout.overflow),
                    ),
                ],
              );
            },
          ),
          actions: [
            SizedBox(
              width: _kNavSlotWidth,
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: shellNavControls.onMenu,
                tooltip: shellNavControls.menuTooltip,
              ),
            ),
          ],
        );
      },
    );
  }

  _SlotLayout _fitItems({
    required BuildContext context,
    required double budget,
    required List<AppBarItem> left,
    required List<AppBarItem> center,
    required List<AppBarItem> right,
  }) {
    final ordered = [...left, ...center, ...right];
    final visible = <AppBarItem>[];
    final overflow = <AppBarItem>[];
    var used = 0.0;

    for (final item in ordered) {
      final width = _estimateWidth(context, item);
      if (used + width <= budget || visible.isEmpty && item is AppBarTitle) {
        visible.add(item);
        used += width;
      } else {
        overflow.add(item);
      }
    }

    return _SlotLayout(
      left: visible.where((i) => i.slot == AppBarSlot.left).toList(),
      center: visible.where((i) => i.slot == AppBarSlot.center).toList(),
      right: visible.where((i) => i.slot == AppBarSlot.right).toList(),
      overflow: overflow,
    );
  }

  double _estimateWidth(BuildContext context, AppBarItem item) {
    return switch (item) {
      AppBarTitle(:final text, :final icon) =>
        (icon != null ? 36.0 : 0) +
            (text != null
                ? mathMin(
                    _kTitleMaxWidth,
                    _measureText(
                      context,
                      text,
                      Theme.of(context).textTheme.titleLarge,
                    ),
                  )
                : 0) +
            8,
      AppBarAction(:final label) => label != null ? 96.0 : _kNavSlotWidth,
    };
  }

  double _measureText(BuildContext context, String text, TextStyle? style) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    return painter.width + 16;
  }

  Widget _buildItem(BuildContext context, AppBarItem item) {
    return switch (item) {
      AppBarTitle(:final text, :final icon) => Flexible(
          fit: FlexFit.loose,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22),
                const SizedBox(width: 8),
              ],
              if (text != null)
                Flexible(
                  child: Text(
                    text,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
            ],
          ),
        ),
      AppBarAction(:final icon, :final label, :final tooltip, :final onTap) =>
        label != null
            ? TextButton.icon(
                onPressed: onTap,
                icon: Icon(icon, size: 20),
                label: Text(label),
              )
            : IconButton(
                icon: Icon(icon),
                tooltip: tooltip,
                onPressed: onTap,
              ),
    };
  }
}

double mathMin(double a, double b) => a < b ? a : b;

class _SlotLayout {
  const _SlotLayout({
    required this.left,
    required this.center,
    required this.right,
    required this.overflow,
  });

  final List<AppBarItem> left;
  final List<AppBarItem> center;
  final List<AppBarItem> right;
  final List<AppBarItem> overflow;
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.items});

  final List<AppBarItem> items;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppBarItem>(
      icon: const Icon(Icons.arrow_drop_down),
      tooltip: 'More',
      itemBuilder: (context) => [
        for (final item in items)
          PopupMenuItem<AppBarItem>(
            value: item,
            onTap: () {
              if (item is AppBarAction) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  item.onTap();
                });
              }
            },
            child: _OverflowMenuLabel(item: item),
          ),
      ],
    );
  }
}

class _OverflowMenuLabel extends StatelessWidget {
  const _OverflowMenuLabel({required this.item});

  final AppBarItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      AppBarTitle(:final text, :final icon) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            if (text != null) Text(text),
          ],
        ),
      AppBarAction(:final icon, :final label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label ?? ''),
          ],
        ),
    };
  }
}
