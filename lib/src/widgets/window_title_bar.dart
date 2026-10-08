import 'package:flutter/material.dart';

import '../core.dart';
import '../theme/window_stack_theme.dart';
import 'window_controls.dart';

/// The default title bar of a window.
///
/// Shows the window's icon and title on a bar that moves the window when
/// dragged and maximizes or restores it on double-click, plus the window's
/// [WindowControls]. Its colors and text follow the active state of the
/// window, so the focused window stands out.
///
/// With [WindowControlsStyle.trafficLights] the buttons sit at the leading
/// edge and the title is centered; with [WindowControlsStyle.windows] the
/// title is at the leading edge and the buttons at the trailing edge.
///
/// [actions] are extra widgets placed before the trailing edge, for example a
/// "keep on top" toggle:
///
/// ```dart
/// controller.open(
///   title: 'Calculator',
///   builder: (context) => const Calculator(),
///   titleBarBuilder: (context, window) => WindowTitleBar(
///     actions: [
///       IconButton(
///         iconSize: 16,
///         icon: const Icon(Icons.push_pin_outlined),
///         onPressed: () => window.priority = WindowPriority.high,
///       ),
///     ],
///   ),
/// );
/// ```
///
/// Must be used inside a window.
class WindowTitleBar extends StatelessWidget {
  /// Creates the default title bar.
  const WindowTitleBar({super.key, this.actions = const <Widget>[]});

  /// Widgets shown at the trailing end of the bar, before any trailing window
  /// buttons.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = WindowEntry.of(context);
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    return ListenableBuilder(
      listenable: window,
      builder: (BuildContext context, Widget? child) {
        final bool active = window.isActive;
        final bool trafficLights =
            theme.controlsStyle == WindowControlsStyle.trafficLights;
        final TextStyle style =
            active ? theme.titleTextStyle! : theme.inactiveTitleTextStyle!;

        final Widget title = Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (window.icon != null) ...<Widget>[
              IconTheme.merge(
                data: IconThemeData(size: 16, color: style.color),
                child: window.icon!,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                window.title,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        return Container(
          height: theme.titleBarHeight,
          color: active ? theme.titleBarColor : theme.inactiveTitleBarColor,
          child: Row(
            children: <Widget>[
              if (trafficLights) const WindowControls(),
              Expanded(
                child: WindowDragArea(
                  child: Padding(
                    // Balance the traffic lights so the title is centered
                    // on the whole bar.
                    padding: trafficLights
                        ? EdgeInsetsDirectional.only(
                            end: actions.isEmpty
                                ? WindowControls.trafficLightsWidth
                                : 8,
                          )
                        : const EdgeInsetsDirectional.only(start: 12, end: 8),
                    child: Align(
                      alignment: trafficLights
                          ? Alignment.center
                          : AlignmentDirectional.centerStart,
                      child: title,
                    ),
                  ),
                ),
              ),
              ...actions,
              if (!trafficLights) const WindowControls(),
            ],
          ),
        );
      },
    );
  }
}
