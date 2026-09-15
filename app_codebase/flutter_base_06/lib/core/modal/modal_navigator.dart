import 'package:flutter/material.dart';

/// Dismiss the [PopupRoute] that owns [context], even when buried.
///
/// Used by [AppModal.dismiss] and shell close buttons. Page routes fall through
/// to a normal root-navigator pop (topmost overlay).
///
/// Never pop the top route when [context]'s popup is already inactive — that
/// steals newer overlays (e.g. post-match under a disposing match shell).
void dismissModalRoute(BuildContext context, [Object? result]) {
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  if (route is PopupRoute) {
    if (!route.isActive) return;
    if (route.isCurrent) {
      nav.pop(result);
      return;
    }
    // Buried under a newer modal — pop() would hit the top route.
    nav.removeRoute(route);
    return;
  }
  if (!nav.canPop()) return;
  nav.pop(result);
}
