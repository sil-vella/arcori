import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Exhibit / gallery card frame — bronze or gold hairline over surface fill.
class AppExhibitCard extends StatelessWidget {
  const AppExhibitCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.goldFrame = false,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final bool goldFrame;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.appSurfaces;
    final radius = BorderRadius.circular(surfaces.exhibitRadius);
    final borderColor = goldFrame ? surfaces.frameGold : surfaces.frameBronze;

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.exhibit,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: padding ?? AppSpacing.screenPaddingCompact,
        child: child,
      ),
    );

    final wrapped = margin == null
        ? body
        : Padding(padding: margin!, child: body);

    if (onTap == null) return wrapped;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: wrapped,
      ),
    );
  }
}

/// Section title + optional muted caption with a bronze accent rail.
class AppSectionRail extends StatelessWidget {
  const AppSectionRail({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.appSurfaces;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: caption == null ? 20 : 36,
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            color: surfaces.frameBronze,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.appTypography.title),
              if (caption != null) ...[
                AppSpacing.gapXxs,
                Text(caption!, style: context.appTypography.bodyMuted),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Centered empty-state block using theme typography.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.title,
    this.icon,
  });

  final String message;
  final String? title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 40,
                color: context.appSurfaces.frameBronze,
              ),
              AppSpacing.gapMd,
            ],
            if (title != null) ...[
              Text(
                title!,
                style: context.appTypography.h3,
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapSm,
            ],
            Text(
              message,
              style: context.appTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Piano-glass chip for match HUD (aim lock, mode indicator).
class AppHudGlassChip extends StatelessWidget {
  const AppHudGlassChip({
    super.key,
    required this.child,
    this.onTap,
    this.emphasized = false,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool emphasized;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final hud = context.appHud;
    final surfaces = context.appSurfaces;
    final radius = BorderRadius.circular(AppRadii.pill);
    final border = emphasized ? hud.aimLocked : surfaces.glassHudBorder;

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.glassHud,
        borderRadius: radius,
        border: Border.all(color: border, width: emphasized ? 1.5 : 1),
      ),
      child: Padding(
        padding: padding ??
            const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
        child: DefaultTextStyle(
          style: context.appTypography.label.copyWith(color: hud.onGlass),
          child: IconTheme(
            data: IconThemeData(color: hud.onGlass, size: 18),
            child: child,
          ),
        ),
      ),
    );

    if (onTap == null) return body;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: body,
      ),
    );
  }
}
