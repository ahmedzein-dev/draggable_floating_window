import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core.dart';
import '../theme/window_stack_labels.dart';
import '../theme/window_stack_theme.dart';
import 'glyphs.dart';

/// The minimize, maximize and close buttons of the enclosing window.
///
/// Buttons the window does not allow, such as maximize on a window opened
/// with `maximizable: false`, are shown disabled. The look follows [style],
/// or [WindowStackThemeData.controlsStyle] when [style] is null.
///
/// Use it in a custom title bar:
///
/// ```dart
/// WindowStack(
///   controller: controller,
///   titleBarBuilder: (context, window) => Row(
///     children: [
///       Expanded(child: WindowDragArea(child: Text(window.title))),
///       const WindowControls(style: WindowControlsStyle.windows),
///     ],
///   ),
/// );
/// ```
///
/// Must be used inside a window.
class WindowControls extends StatelessWidget {
  /// Creates the buttons of the enclosing window.
  const WindowControls({super.key, this.style});

  /// The look of the buttons. Defaults to the theme's controls style.
  final WindowControlsStyle? style;

  /// The width the [WindowControlsStyle.trafficLights] buttons take up,
  /// padding included.
  static const double trafficLightsWidth = 76;

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = WindowEntry.of(context);
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    final WindowStackLabels labels = WindowStackLabels.of(context);
    return ListenableBuilder(
      listenable: window,
      builder: (BuildContext context, Widget? child) {
        return switch (style ?? theme.controlsStyle!) {
          WindowControlsStyle.trafficLights => _TrafficLights(
              window: window,
              theme: theme,
              labels: labels,
            ),
          WindowControlsStyle.windows => _WindowsButtons(
              window: window,
              theme: theme,
              labels: labels,
            ),
        };
      },
    );
  }
}

class _TrafficLights extends StatefulWidget {
  const _TrafficLights({
    required this.window,
    required this.theme,
    required this.labels,
  });

  final WindowEntry window;
  final WindowStackThemeData theme;
  final WindowStackLabels labels;

  @override
  State<_TrafficLights> createState() => _TrafficLightsState();
}

class _TrafficLightsState extends State<_TrafficLights> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = widget.window;
    final WindowStackThemeData theme = widget.theme;
    final WindowStackLabels labels = widget.labels;
    // Inactive windows show grey lights until the pointer reaches them.
    final bool lit = window.isActive || _hovered;
    Color colorFor(Color color, bool enabled) {
      return lit && enabled ? color : theme.inactiveButtonColor!;
    }

    return MouseRegion(
      onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
      onExit: (PointerExitEvent event) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TrafficLight(
              color: colorFor(theme.closeButtonColor!, window.closable),
              glyph: WindowGlyph.close,
              showGlyph: _hovered && window.closable,
              label: labels.close,
              onPressed: window.closable ? () => window.close() : null,
            ),
            const SizedBox(width: 8),
            _TrafficLight(
              color: colorFor(theme.minimizeButtonColor!, window.minimizable),
              glyph: WindowGlyph.minimize,
              showGlyph: _hovered && window.minimizable,
              label: labels.minimize,
              onPressed: window.minimizable ? window.minimize : null,
            ),
            const SizedBox(width: 8),
            _TrafficLight(
              color: colorFor(theme.maximizeButtonColor!, window.maximizable),
              glyph: WindowGlyph.maximize,
              showGlyph: _hovered && window.maximizable,
              label: window.isMaximized ? labels.restore : labels.maximize,
              onPressed: window.maximizable ? window.toggleMaximize : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficLight extends StatelessWidget {
  const _TrafficLight({
    required this.color,
    required this.glyph,
    required this.showGlyph,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final WindowGlyph glyph;
  final bool showGlyph;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget light = Container(
      width: 12,
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: showGlyph
          ? GlyphIcon(
              glyph,
              color: Colors.black.withValues(alpha: 0.6),
              size: 6,
              strokeWidth: 1.3,
              plusForMaximize: true,
            )
          : null,
    );
    return labeledButton(
      context: context,
      label: label,
      child: MouseRegion(
        cursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(onTap: onPressed, child: light),
      ),
    );
  }
}

class _WindowsButtons extends StatelessWidget {
  const _WindowsButtons({
    required this.window,
    required this.theme,
    required this.labels,
  });

  final WindowEntry window;
  final WindowStackThemeData theme;
  final WindowStackLabels labels;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle =
        window.isActive ? theme.titleTextStyle! : theme.inactiveTitleTextStyle!;
    final Color glyphColor =
        titleStyle.color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _WindowsButton(
          glyph: WindowGlyph.minimize,
          glyphColor: glyphColor,
          hoverColor: glyphColor.withValues(alpha: 0.1),
          label: labels.minimize,
          height: theme.titleBarHeight!,
          onPressed: window.minimizable ? window.minimize : null,
        ),
        _WindowsButton(
          glyph:
              window.isMaximized ? WindowGlyph.restore : WindowGlyph.maximize,
          glyphColor: glyphColor,
          hoverColor: glyphColor.withValues(alpha: 0.1),
          label: window.isMaximized ? labels.restore : labels.maximize,
          height: theme.titleBarHeight!,
          onPressed: window.maximizable ? window.toggleMaximize : null,
        ),
        _WindowsButton(
          glyph: WindowGlyph.close,
          glyphColor: glyphColor,
          hoverColor: theme.closeButtonColor!,
          hoverGlyphColor: Colors.white,
          label: labels.close,
          height: theme.titleBarHeight!,
          onPressed: window.closable ? () => window.close() : null,
        ),
      ],
    );
  }
}

class _WindowsButton extends StatefulWidget {
  const _WindowsButton({
    required this.glyph,
    required this.glyphColor,
    required this.hoverColor,
    required this.label,
    required this.height,
    required this.onPressed,
    this.hoverGlyphColor,
  });

  final WindowGlyph glyph;
  final Color glyphColor;
  final Color hoverColor;
  final Color? hoverGlyphColor;
  final String label;
  final double height;
  final VoidCallback? onPressed;

  @override
  State<_WindowsButton> createState() => _WindowsButtonState();
}

class _WindowsButtonState extends State<_WindowsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool highlighted = enabled && _hovered;
    final Color glyphColor = !enabled
        ? widget.glyphColor.withValues(alpha: 0.35)
        : highlighted
            ? (widget.hoverGlyphColor ?? widget.glyphColor)
            : widget.glyphColor;
    return labeledButton(
      context: context,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
        onExit: (PointerExitEvent event) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 46,
            height: widget.height,
            alignment: Alignment.center,
            color: highlighted ? widget.hoverColor : Colors.transparent,
            child: GlyphIcon(widget.glyph, color: glyphColor),
          ),
        ),
      ),
    );
  }
}
