import 'package:flutter/material.dart';

import '../navigation/app_navigation.dart';
import 'bottom_nav_controller.dart';
import 'contracts/register_bottom_nav_contract.dart';

/// Shell bottom action bar; hidden when no screen-scoped items are active.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({required this.controller, super.key});

  final BottomNavController controller;

  static const int _kMaxVisible = 5;
  static const double _kBarHeight = 56;

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

        return Material(
          elevation: 3,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: _kBarHeight,
              child: Row(
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
      },
    );
  }

  Widget _buildItem(BuildContext context, BottomNavItem item) {
    return switch (item) {
      BottomNavAction(:final icon, :final label, :final tooltip, :final onTap) =>
        _BottomNavButton(
          icon: icon,
          label: label,
          tooltip: tooltip,
          onTap: onTap,
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
    this.label,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (label != null) {
      return TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label!, overflow: TextOverflow.ellipsis),
      );
    }
    return IconButton(
      icon: Icon(icon),
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
      BottomNavAction(:final icon, :final label, :final tooltip) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
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
