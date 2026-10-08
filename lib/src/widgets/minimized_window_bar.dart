import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core.dart';
import '../theme/window_stack_labels.dart';
import '../theme/window_stack_theme.dart';
import 'glyphs.dart';

/// The default bar that stands for a minimized window in the dock.
///
/// Shows the window's icon and title and buttons to restore, maximize and
/// close it. Clicking the title restores the window. A dot appears when a
/// window dialog is waiting on the minimized window.
///
/// Replace it with [WindowStack.minimizedBuilder]. Must be used inside a
/// window's dock slot.
class MinimizedWindowBar extends StatelessWidget {
  /// Creates the default dock bar.
  const MinimizedWindowBar({super.key});

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = WindowEntry.of(context);
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    final WindowStackLabels labels = WindowStackLabels.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: window,
      builder: (BuildContext context, Widget? child) {
        final TextStyle style = theme.minimizedTextStyle!;
        final Color glyphColor = style.color ?? colors.onSurface;
        return Semantics(
          container: true,
          label: window.title,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.minimizedBarColor,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(color: theme.borderColor!),
              boxShadow: theme.inactiveShadows,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: labeledButton(
                    context: context,
                    label: labels.restore,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: window.restore,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start: 10,
                            end: 4,
                          ),
                          child: Row(
                            children: <Widget>[
                              if (window.icon != null) ...<Widget>[
                                IconTheme.merge(
                                  data: IconThemeData(
                                    size: 16,
                                    color: glyphColor,
                                  ),
                                  child: window.icon!,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  window.title,
                                  style: style,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (window.hasDialogs)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsetsDirectional.only(
                                    start: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _BarButton(
                  glyph: WindowGlyph.restoreUp,
                  color: glyphColor,
                  label: labels.restore,
                  onPressed: window.restore,
                ),
                if (window.maximizable)
                  _BarButton(
                    glyph: WindowGlyph.maximize,
                    color: glyphColor,
                    label: labels.maximize,
                    onPressed: window.maximize,
                  ),
                if (window.closable)
                  _BarButton(
                    glyph: WindowGlyph.close,
                    color: glyphColor,
                    label: labels.close,
                    onPressed: () => window.close(),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.glyph,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final WindowGlyph glyph;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return labeledButton(
      context: context,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent event) => setState(() => _hovered = true),
        onExit: (PointerExitEvent event) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: GlyphIcon(widget.glyph, color: widget.color, size: 9),
          ),
        ),
      ),
    );
  }
}
