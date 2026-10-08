import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

/// Shows the active window and the keyboard shortcuts.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.controller});

  final WindowStackController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle style = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: colors.onSurfaceVariant,
        );
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final List<WindowEntry> windows = controller.windows;
        final int minimized =
            windows.where((WindowEntry window) => window.isMinimized).length;
        final WindowEntry? active = controller.activeWindow;
        return Container(
          height: 28,
          color: colors.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.circle,
                size: 8,
                color: active == null ? colors.outline : colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                active == null ? 'No active window' : 'Active: ${active.title}',
                style: style,
              ),
              const SizedBox(width: 16),
              Text(
                '${windows.length} open'
                '${minimized == 0 ? '' : ', $minimized minimized'}',
                style: style,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Ctrl+Tab next window  ·  Ctrl+Shift+Tab previous  ·  '
                  'Ctrl+F4 close',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: style,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
