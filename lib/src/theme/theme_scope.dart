import 'package:flutter/material.dart';

import 'window_stack_labels.dart';
import 'window_stack_theme.dart';

/// Makes a `WindowStack`'s resolved theme and labels available to the
/// windows inside it. Internal to the package.
class WindowStackThemeScope extends InheritedWidget {
  /// Creates a scope for [theme] and [labels].
  const WindowStackThemeScope({
    super.key,
    required this.theme,
    required this.labels,
    required super.child,
  });

  /// The fully resolved theme.
  final WindowStackThemeData theme;

  /// The button and barrier labels.
  final WindowStackLabels labels;

  /// Returns the nearest scope, if any.
  static WindowStackThemeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WindowStackThemeScope>();
  }

  @override
  bool updateShouldNotify(WindowStackThemeScope oldWidget) {
    return theme != oldWidget.theme || labels != oldWidget.labels;
  }
}

/// Resolves [explicit] over the [ThemeData] extension over defaults derived
/// from the ambient [ThemeData]. Every property of the result is non-null.
WindowStackThemeData resolveWindowStackTheme(
  BuildContext context,
  WindowStackThemeData? explicit,
) {
  final ThemeData theme = Theme.of(context);
  final WindowStackThemeData data = (explicit ?? const WindowStackThemeData())
      .merge(theme.extension<WindowStackThemeData>());
  return data.merge(_defaults(theme, data));
}

WindowStackThemeData _defaults(ThemeData theme, WindowStackThemeData data) {
  final ColorScheme colors = theme.colorScheme;
  final bool dark = colors.brightness == Brightness.dark;
  final TextStyle titleStyle = data.titleTextStyle ??
      (theme.textTheme.titleSmall ?? const TextStyle(fontSize: 14)).copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w600,
      );
  return WindowStackThemeData(
    backgroundColor: colors.surface,
    titleBarColor: colors.surfaceContainerHigh,
    inactiveTitleBarColor: colors.surfaceContainer,
    titleTextStyle: titleStyle,
    inactiveTitleTextStyle: titleStyle.copyWith(
      color: colors.onSurfaceVariant,
    ),
    titleBarHeight: 36,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    borderColor: colors.outlineVariant,
    activeBorderColor: colors.primary.withValues(alpha: 0.6),
    activeShadows: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.5 : 0.22),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    ],
    inactiveShadows: <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
        blurRadius: 14,
        offset: const Offset(0, 6),
      ),
    ],
    controlsStyle: WindowControlsStyle.trafficLights,
    closeButtonColor: const Color(0xFFFF605C),
    minimizeButtonColor: const Color(0xFFFFBD44),
    maximizeButtonColor: const Color(0xFF00CA4E),
    inactiveButtonColor: colors.outlineVariant,
    resizeHandleSize: 8,
    minimizedSize: const Size(200, 40),
    dockPadding: const EdgeInsets.all(10),
    dockSpacing: 10,
    minimizedBarColor: colors.surfaceContainerHighest,
    minimizedTextStyle: (theme.textTheme.labelLarge ?? const TextStyle())
        .copyWith(color: colors.onSurface),
    barrierColor: Colors.black.withValues(alpha: 0.3),
    animationDuration: const Duration(milliseconds: 180),
    animationCurve: Curves.easeOutCubic,
  );
}
