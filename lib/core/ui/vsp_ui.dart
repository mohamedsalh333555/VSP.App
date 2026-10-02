import 'package:flutter/material.dart';
import 'tokens/vsp_tokens.dart';

/// Shared UI grammar for VSP screens.
///
/// The goal is not to replace existing feature-specific widgets, but to give
/// them the same hierarchy, state language, and geometry.
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
    this.margin = const EdgeInsets.only(bottom: VSPSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: VSPColors.textPrimary,
                      ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: VSPColors.textSecondary,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: VSPSpacing.md),
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
    final foreground = color ?? VSPColors.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(VSPRadius.full),
        border: Border.all(color: foreground.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: VSPSpacing.xs),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
    final isErrorLike = state == VSPUiState.error || state == VSPUiState.offline;
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

    final tint = isErrorLike ? VSPColors.error : VSPColors.accent;

    if (state == VSPUiState.loading || state == VSPUiState.processing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: VSPColors.accent,
              ),
            ),
            const SizedBox(height: VSPSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VSPColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: VSPSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VSPSpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.withValues(alpha: 0.25)),
                ),
                child: Icon(iconData, color: tint, size: 28),
              ),
              const SizedBox(height: VSPSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: VSPColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: VSPSpacing.xs),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VSPColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: VSPSpacing.lg),
                action!,
              ] else if (onRetry != null && isErrorLike) ...[
                const SizedBox(height: VSPSpacing.lg),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(140, VSPSize.buttonHeight),
                    side: const BorderSide(color: VSPColors.borderAccent),
                    foregroundColor: VSPColors.accent,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'ar'
                        ? 'إعادة المحاولة'
                        : 'Retry',
                    style: const TextStyle(fontWeight: FontWeight.w800),
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
      VSPSpacing.lg,
      VSPSpacing.md,
      VSPSpacing.lg,
      VSPSpacing.lg,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface,
        border: const Border(
          top: BorderSide(color: VSPColors.divider),
        ),
        boxShadow: VSPShadow.mediumList,
      ),
      padding: padding is EdgeInsets
          ? EdgeInsets.fromLTRB(
              (padding as EdgeInsets).left,
              (padding as EdgeInsets).top,
              (padding as EdgeInsets).right,
              (padding as EdgeInsets).bottom + safeBottom,
            )
          : EdgeInsets.fromLTRB(
              VSPSpacing.lg,
              VSPSpacing.md,
              VSPSpacing.lg,
              VSPSpacing.lg + safeBottom,
            ),
      child: child,
    );
  }
}


/// Canonical VSP page scaffold.
/// Existing feature screens can use it without changing their content structure;
/// it centralizes the page surface defaults while preserving normal Scaffold APIs.
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
      backgroundColor: backgroundColor ?? VSPColors.background,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      primary: primary,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawerEnableOpenDragGesture: drawerEnableOpenDragGesture,
      endDrawerEnableOpenDragGesture: endDrawerEnableOpenDragGesture,
      restorationId: restorationId,
      bottomSheet: bottomSheet,
    );
  }
}
