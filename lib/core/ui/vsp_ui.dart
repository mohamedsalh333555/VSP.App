import 'package:flutter/material.dart';
import 'tokens/vsp_design_tokens.dart';

/// Shared VSP UI grammar backed by Design System V2.
enum VSPUiState {
  loading,
  empty,
  error,
  offline,
  pending,
  processing,
  success,
  disabled,
}

class VSPSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  const VSPSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.margin = const EdgeInsets.only(
      bottom: VSPDSSpacing.fieldGap,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        textDirection: Directionality.of(context),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VSPDSTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: VSPDSSpacing.xxs),
                  Text(
                    subtitle!,
                    style: VSPDSTypography.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VSPDSSpacing.fieldGap),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class VSPStatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const VSPStatusPill({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? VSPDSSemanticColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VSPDSSpacing.sm,
        vertical: VSPDSSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: foreground.withValues(
          alpha: VSPDSOpacity.selectedSurface,
        ),
        borderRadius: BorderRadius.circular(VSPDSRadius.full),
        border: Border.all(
          color: foreground.withValues(
            alpha: VSPDSOpacity.border,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: Directionality.of(context),
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: VSPDSizes.statusIcon,
              color: foreground,
            ),
            const SizedBox(width: VSPDSSpacing.xxs),
          ],
          Text(
            label,
            style: VSPDSTypography.status.copyWith(
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class VSPStateView extends StatelessWidget {
  final VSPUiState state;
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final Widget? action;

  const VSPStateView({
    super.key,
    required this.state,
    required this.title,
    this.message,
    this.onRetry,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isErrorLike =
        state == VSPUiState.error || state == VSPUiState.offline;

    final iconData = icon ??
        switch (state) {
          VSPUiState.loading ||
          VSPUiState.processing ||
          VSPUiState.pending =>
            Icons.hourglass_top_rounded,
          VSPUiState.empty => Icons.inbox_outlined,
          VSPUiState.error => Icons.error_outline_rounded,
          VSPUiState.offline => Icons.wifi_off_rounded,
          VSPUiState.success => Icons.check_circle_outline_rounded,
          VSPUiState.disabled => Icons.lock_outline_rounded,
        };

    final tint = isErrorLike
        ? VSPDSSemanticColors.error
        : VSPDSSemanticColors.accent;

    if (state == VSPUiState.loading || state == VSPUiState.processing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: VSPDSizes.stateLoadingIndicator,
              height: VSPDSizes.stateLoadingIndicator,
              child: CircularProgressIndicator(
                strokeWidth: VSPDSizes.progressStroke,
                color: VSPDSSemanticColors.accent,
              ),
            ),
            const SizedBox(height: VSPDSSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: VSPDSTypography.stateTitle,
            ),
            if (message != null) ...[
              const SizedBox(height: VSPDSSpacing.xxs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: VSPDSTypography.stateMessage,
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSPDSSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: VSPDSAccessibility.stateMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: VSPDSizes.stateIconBox,
                height: VSPDSizes.stateIconBox,
                decoration: BoxDecoration(
                  color: tint.withValues(
                    alpha: VSPDSOpacity.selectedSurface,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tint.withValues(
                      alpha: VSPDSOpacity.border,
                    ),
                  ),
                ),
                child: Icon(
                  iconData,
                  color: tint,
                  size: VSPDSizes.iconXl,
                ),
              ),
              const SizedBox(height: VSPDSSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: VSPDSTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: VSPDSSpacing.xxs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: VSPDSTypography.stateBody,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: VSPDSSpacing.md),
                action!,
              ] else if (onRetry != null && isErrorLike) ...[
                const SizedBox(height: VSPDSSpacing.md),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(
                      VSPDSizes.iconXl + VSPDSSpacing.section,
                      VSPDSizes.buttonHeight,
                    ),
                    side: VSPDSBorders.accent,
                    foregroundColor: VSPDSSemanticColors.accent,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'إعادة المحاولة'
                        : 'Retry',
                    style: VSPDSTypography.compactButton,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class VSPBottomActionBar extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const VSPBottomActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      VSPDSSpacing.md,
      VSPDSSpacing.sm,
      VSPDSSpacing.md,
      VSPDSSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: VSPDSSemanticColors.surface,
        border: Border(
          top: VSPDSBorders.divider,
        ),
        boxShadow: <BoxShadow>[
          VSPDSElevation.medium,
        ],
      ),
      padding: padding is EdgeInsets
          ? EdgeInsets.fromLTRB(
              (padding as EdgeInsets).left,
              (padding as EdgeInsets).top,
              (padding as EdgeInsets).right,
              (padding as EdgeInsets).bottom + safeBottom,
            )
          : EdgeInsets.fromLTRB(
              VSPDSSpacing.md,
              VSPDSSpacing.sm,
              VSPDSSpacing.md,
              VSPDSSpacing.md + safeBottom,
            ),
      child: child,
    );
  }
}

/// Canonical page scaffold.
class VSPScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final FloatingActionButtonAnimator? floatingActionButtonAnimator;
  final List<Widget>? persistentFooterButtons;
  final AlignmentDirectional persistentFooterAlignment;
  final Widget? drawer;
  final void Function(bool)? onDrawerChanged;
  final Widget? endDrawer;
  final void Function(bool)? onEndDrawerChanged;
  final Color? drawerScrimColor;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;
  final bool primary;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool drawerEnableOpenDragGesture;
  final bool endDrawerEnableOpenDragGesture;
  final String? restorationId;
  final Widget? bottomNavigationBar;
  final Widget? bottomSheet;

  const VSPScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.floatingActionButtonAnimator,
    this.persistentFooterButtons,
    this.persistentFooterAlignment = AlignmentDirectional.centerEnd,
    this.drawer,
    this.onDrawerChanged,
    this.endDrawer,
    this.onEndDrawerChanged,
    this.drawerScrimColor,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerEnableOpenDragGesture = true,
    this.endDrawerEnableOpenDragGesture = true,
    this.restorationId,
    this.bottomNavigationBar,
    this.bottomSheet,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      floatingActionButtonAnimator: floatingActionButtonAnimator,
      persistentFooterButtons: persistentFooterButtons,
      persistentFooterAlignment: persistentFooterAlignment,
      drawer: drawer,
      onDrawerChanged: onDrawerChanged,
      endDrawer: endDrawer,
      onEndDrawerChanged: onEndDrawerChanged,
      drawerScrimColor: drawerScrimColor,
      backgroundColor: backgroundColor ?? VSPDSSemanticColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
      restorationId: restorationId,
      bottomNavigationBar: bottomNavigationBar,
      bottomSheet: bottomSheet,
    );
  }
}
