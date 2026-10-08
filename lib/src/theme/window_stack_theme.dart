import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'theme_scope.dart';

/// The look of the buttons that minimize, maximize and close a window.
enum WindowControlsStyle {
  /// Three round buttons at the leading edge of the title bar, in the style
  /// of macOS. Their symbols appear when the pointer hovers over them.
  trafficLights,

  /// Rectangular minimize, maximize and close buttons at the trailing edge of
  /// the title bar, in the style of Windows.
  windows,
}

/// Visual properties of the windows inside a `WindowStack`.
///
/// Every property is optional. Unset properties fall back to values derived
/// from the ambient [ThemeData], so the windows match the app's
/// [ColorScheme] and text theme out of the box.
///
/// Provide the theme in either of two ways:
///
/// * pass it to `WindowStack.theme`, or
/// * register it as a [ThemeExtension] so it follows light and dark themes:
///
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       WindowStackThemeData(
///         controlsStyle: WindowControlsStyle.windows,
///         borderRadius: BorderRadius.all(Radius.circular(6)),
///       ),
///     ],
///   ),
/// );
/// ```
///
/// When both are present, values passed to `WindowStack.theme` win.
@immutable
class WindowStackThemeData extends ThemeExtension<WindowStackThemeData> {
  /// Creates a window theme. Every argument is optional.
  const WindowStackThemeData({
    this.backgroundColor,
    this.titleBarColor,
    this.inactiveTitleBarColor,
    this.titleTextStyle,
    this.inactiveTitleTextStyle,
    this.titleBarHeight,
    this.borderRadius,
    this.borderColor,
    this.activeBorderColor,
    this.activeShadows,
    this.inactiveShadows,
    this.controlsStyle,
    this.closeButtonColor,
    this.minimizeButtonColor,
    this.maximizeButtonColor,
    this.inactiveButtonColor,
    this.resizeHandleSize,
    this.minimizedSize,
    this.dockPadding,
    this.dockSpacing,
    this.minimizedBarColor,
    this.minimizedTextStyle,
    this.barrierColor,
    this.animationDuration,
    this.animationCurve,
  });

  /// The color behind a window's content.
  ///
  /// Defaults to [ColorScheme.surface].
  final Color? backgroundColor;

  /// The title bar color of the active window.
  ///
  /// Defaults to [ColorScheme.surfaceContainerHigh].
  final Color? titleBarColor;

  /// The title bar color of inactive windows.
  ///
  /// Defaults to [ColorScheme.surfaceContainer].
  final Color? inactiveTitleBarColor;

  /// The title text style of the active window.
  ///
  /// Defaults to [TextTheme.titleSmall] in [ColorScheme.onSurface].
  final TextStyle? titleTextStyle;

  /// The title text style of inactive windows.
  ///
  /// Defaults to [titleTextStyle] in [ColorScheme.onSurfaceVariant].
  final TextStyle? inactiveTitleTextStyle;

  /// The height of the default title bar. Defaults to 36.
  final double? titleBarHeight;

  /// The corner radius of windows in normal mode. Maximized windows have
  /// square corners. Defaults to a radius of 10.
  final BorderRadius? borderRadius;

  /// The outline color of inactive windows.
  ///
  /// Defaults to [ColorScheme.outlineVariant].
  final Color? borderColor;

  /// The outline color of the active window, which makes the focused window
  /// easy to spot when several overlap.
  ///
  /// Defaults to [ColorScheme.primary] at 60% opacity.
  final Color? activeBorderColor;

  /// The shadows under the active window.
  final List<BoxShadow>? activeShadows;

  /// The shadows under inactive windows.
  final List<BoxShadow>? inactiveShadows;

  /// The style of the default window buttons.
  ///
  /// Defaults to [WindowControlsStyle.trafficLights].
  final WindowControlsStyle? controlsStyle;

  /// The color of the close button. With [WindowControlsStyle.windows] it is
  /// the hover color of the close button. Defaults to `Color(0xFFFF605C)`.
  final Color? closeButtonColor;

  /// The color of the minimize traffic light. Defaults to `Color(0xFFFFBD44)`.
  final Color? minimizeButtonColor;

  /// The color of the maximize traffic light. Defaults to `Color(0xFF00CA4E)`.
  final Color? maximizeButtonColor;

  /// The color of the traffic lights of inactive windows.
  ///
  /// Defaults to [ColorScheme.outlineVariant].
  final Color? inactiveButtonColor;

  /// The thickness of the invisible resize zones along each edge.
  ///
  /// Corner zones are twice as large. Defaults to 8.
  final double? resizeHandleSize;

  /// The size of a minimized window in the dock. Defaults to 200 by 40.
  final Size? minimizedSize;

  /// The space between the dock and the edges of the stack.
  ///
  /// Defaults to 10 on every side.
  final EdgeInsets? dockPadding;

  /// The gap between minimized windows in the dock. Defaults to 10.
  final double? dockSpacing;

  /// The background color of a minimized window.
  ///
  /// Defaults to [ColorScheme.surfaceContainerHighest].
  final Color? minimizedBarColor;

  /// The text style of a minimized window's title.
  ///
  /// Defaults to [TextTheme.labelLarge] in [ColorScheme.onSurface].
  final TextStyle? minimizedTextStyle;

  /// The default barrier color behind dialogs.
  ///
  /// Defaults to black at 30% opacity.
  final Color? barrierColor;

  /// The duration of the maximize and restore animations, and of the dialog
  /// entrance. Use [Duration.zero] to turn animations off.
  ///
  /// Defaults to 180 milliseconds.
  final Duration? animationDuration;

  /// The curve of the maximize and restore animations.
  ///
  /// Defaults to [Curves.easeOutCubic].
  final Curve? animationCurve;

  /// Returns the window theme that applies at [context], with every property
  /// filled in.
  ///
  /// Inside a `WindowStack` this is the stack's resolved theme. Elsewhere the
  /// [ThemeData] extension, if any, is resolved against the ambient
  /// [ThemeData].
  static WindowStackThemeData of(BuildContext context) {
    return WindowStackThemeScope.maybeOf(context)?.theme ??
        resolveWindowStackTheme(context, null);
  }

  @override
  WindowStackThemeData copyWith({
    Color? backgroundColor,
    Color? titleBarColor,
    Color? inactiveTitleBarColor,
    TextStyle? titleTextStyle,
    TextStyle? inactiveTitleTextStyle,
    double? titleBarHeight,
    BorderRadius? borderRadius,
    Color? borderColor,
    Color? activeBorderColor,
    List<BoxShadow>? activeShadows,
    List<BoxShadow>? inactiveShadows,
    WindowControlsStyle? controlsStyle,
    Color? closeButtonColor,
    Color? minimizeButtonColor,
    Color? maximizeButtonColor,
    Color? inactiveButtonColor,
    double? resizeHandleSize,
    Size? minimizedSize,
    EdgeInsets? dockPadding,
    double? dockSpacing,
    Color? minimizedBarColor,
    TextStyle? minimizedTextStyle,
    Color? barrierColor,
    Duration? animationDuration,
    Curve? animationCurve,
  }) {
    return WindowStackThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      titleBarColor: titleBarColor ?? this.titleBarColor,
      inactiveTitleBarColor:
          inactiveTitleBarColor ?? this.inactiveTitleBarColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      inactiveTitleTextStyle:
          inactiveTitleTextStyle ?? this.inactiveTitleTextStyle,
      titleBarHeight: titleBarHeight ?? this.titleBarHeight,
      borderRadius: borderRadius ?? this.borderRadius,
      borderColor: borderColor ?? this.borderColor,
      activeBorderColor: activeBorderColor ?? this.activeBorderColor,
      activeShadows: activeShadows ?? this.activeShadows,
      inactiveShadows: inactiveShadows ?? this.inactiveShadows,
      controlsStyle: controlsStyle ?? this.controlsStyle,
      closeButtonColor: closeButtonColor ?? this.closeButtonColor,
      minimizeButtonColor: minimizeButtonColor ?? this.minimizeButtonColor,
      maximizeButtonColor: maximizeButtonColor ?? this.maximizeButtonColor,
      inactiveButtonColor: inactiveButtonColor ?? this.inactiveButtonColor,
      resizeHandleSize: resizeHandleSize ?? this.resizeHandleSize,
      minimizedSize: minimizedSize ?? this.minimizedSize,
      dockPadding: dockPadding ?? this.dockPadding,
      dockSpacing: dockSpacing ?? this.dockSpacing,
      minimizedBarColor: minimizedBarColor ?? this.minimizedBarColor,
      minimizedTextStyle: minimizedTextStyle ?? this.minimizedTextStyle,
      barrierColor: barrierColor ?? this.barrierColor,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
    );
  }

  /// Returns a copy of this theme whose unset properties are taken from
  /// [other].
  WindowStackThemeData merge(WindowStackThemeData? other) {
    if (other == null) {
      return this;
    }
    return other.copyWith(
      backgroundColor: backgroundColor,
      titleBarColor: titleBarColor,
      inactiveTitleBarColor: inactiveTitleBarColor,
      titleTextStyle: titleTextStyle,
      inactiveTitleTextStyle: inactiveTitleTextStyle,
      titleBarHeight: titleBarHeight,
      borderRadius: borderRadius,
      borderColor: borderColor,
      activeBorderColor: activeBorderColor,
      activeShadows: activeShadows,
      inactiveShadows: inactiveShadows,
      controlsStyle: controlsStyle,
      closeButtonColor: closeButtonColor,
      minimizeButtonColor: minimizeButtonColor,
      maximizeButtonColor: maximizeButtonColor,
      inactiveButtonColor: inactiveButtonColor,
      resizeHandleSize: resizeHandleSize,
      minimizedSize: minimizedSize,
      dockPadding: dockPadding,
      dockSpacing: dockSpacing,
      minimizedBarColor: minimizedBarColor,
      minimizedTextStyle: minimizedTextStyle,
      barrierColor: barrierColor,
      animationDuration: animationDuration,
      animationCurve: animationCurve,
    );
  }

  @override
  WindowStackThemeData lerp(
    covariant ThemeExtension<WindowStackThemeData>? other,
    double t,
  ) {
    if (other is! WindowStackThemeData) {
      return this;
    }
    return WindowStackThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      titleBarColor: Color.lerp(titleBarColor, other.titleBarColor, t),
      inactiveTitleBarColor: Color.lerp(
        inactiveTitleBarColor,
        other.inactiveTitleBarColor,
        t,
      ),
      titleTextStyle: TextStyle.lerp(titleTextStyle, other.titleTextStyle, t),
      inactiveTitleTextStyle: TextStyle.lerp(
        inactiveTitleTextStyle,
        other.inactiveTitleTextStyle,
        t,
      ),
      titleBarHeight: lerpDouble(titleBarHeight, other.titleBarHeight, t),
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t),
      borderColor: Color.lerp(borderColor, other.borderColor, t),
      activeBorderColor: Color.lerp(
        activeBorderColor,
        other.activeBorderColor,
        t,
      ),
      activeShadows: BoxShadow.lerpList(activeShadows, other.activeShadows, t),
      inactiveShadows: BoxShadow.lerpList(
        inactiveShadows,
        other.inactiveShadows,
        t,
      ),
      controlsStyle: t < 0.5 ? controlsStyle : other.controlsStyle,
      closeButtonColor: Color.lerp(closeButtonColor, other.closeButtonColor, t),
      minimizeButtonColor: Color.lerp(
        minimizeButtonColor,
        other.minimizeButtonColor,
        t,
      ),
      maximizeButtonColor: Color.lerp(
        maximizeButtonColor,
        other.maximizeButtonColor,
        t,
      ),
      inactiveButtonColor: Color.lerp(
        inactiveButtonColor,
        other.inactiveButtonColor,
        t,
      ),
      resizeHandleSize: lerpDouble(resizeHandleSize, other.resizeHandleSize, t),
      minimizedSize: Size.lerp(minimizedSize, other.minimizedSize, t),
      dockPadding: EdgeInsets.lerp(dockPadding, other.dockPadding, t),
      dockSpacing: lerpDouble(dockSpacing, other.dockSpacing, t),
      minimizedBarColor: Color.lerp(
        minimizedBarColor,
        other.minimizedBarColor,
        t,
      ),
      minimizedTextStyle: TextStyle.lerp(
        minimizedTextStyle,
        other.minimizedTextStyle,
        t,
      ),
      barrierColor: Color.lerp(barrierColor, other.barrierColor, t),
      animationDuration: t < 0.5 ? animationDuration : other.animationDuration,
      animationCurve: t < 0.5 ? animationCurve : other.animationCurve,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WindowStackThemeData &&
        other.backgroundColor == backgroundColor &&
        other.titleBarColor == titleBarColor &&
        other.inactiveTitleBarColor == inactiveTitleBarColor &&
        other.titleTextStyle == titleTextStyle &&
        other.inactiveTitleTextStyle == inactiveTitleTextStyle &&
        other.titleBarHeight == titleBarHeight &&
        other.borderRadius == borderRadius &&
        other.borderColor == borderColor &&
        other.activeBorderColor == activeBorderColor &&
        listEquals(other.activeShadows, activeShadows) &&
        listEquals(other.inactiveShadows, inactiveShadows) &&
        other.controlsStyle == controlsStyle &&
        other.closeButtonColor == closeButtonColor &&
        other.minimizeButtonColor == minimizeButtonColor &&
        other.maximizeButtonColor == maximizeButtonColor &&
        other.inactiveButtonColor == inactiveButtonColor &&
        other.resizeHandleSize == resizeHandleSize &&
        other.minimizedSize == minimizedSize &&
        other.dockPadding == dockPadding &&
        other.dockSpacing == dockSpacing &&
        other.minimizedBarColor == minimizedBarColor &&
        other.minimizedTextStyle == minimizedTextStyle &&
        other.barrierColor == barrierColor &&
        other.animationDuration == animationDuration &&
        other.animationCurve == animationCurve;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        backgroundColor,
        titleBarColor,
        inactiveTitleBarColor,
        titleTextStyle,
        inactiveTitleTextStyle,
        titleBarHeight,
        borderRadius,
        borderColor,
        activeBorderColor,
        activeShadows == null ? null : Object.hashAll(activeShadows!),
        inactiveShadows == null ? null : Object.hashAll(inactiveShadows!),
        controlsStyle,
        closeButtonColor,
        minimizeButtonColor,
        maximizeButtonColor,
        inactiveButtonColor,
        resizeHandleSize,
        minimizedSize,
        dockPadding,
        dockSpacing,
        minimizedBarColor,
        minimizedTextStyle,
        barrierColor,
        animationDuration,
        animationCurve,
      ]);
}
