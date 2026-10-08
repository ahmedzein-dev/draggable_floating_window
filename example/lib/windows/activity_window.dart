import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

/// Lists the open windows from front to back, the way they are stacked, and
/// drives them through their [WindowEntry].
class ActivityWindow extends StatelessWidget {
  const ActivityWindow({super.key, required this.controller});

  final WindowStackController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    // The controller notifies on everything that changes the stack:
    // opening, closing, activation, mode, priority and titles.
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final List<WindowEntry> frontToBack =
            controller.windows.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Front to back',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: colors.primary),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: frontToBack.length,
                itemBuilder: (BuildContext context, int index) =>
                    _WindowRow(window: frontToBack[index]),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: <Widget>[
                  TextButton.icon(
                    onPressed: controller.activatePrevious,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Previous'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: controller.activateNext,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.window});

  final WindowEntry window;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> badges = <String>[
      if (window.isActive) 'active',
      if (window.priority > WindowPriority.normal) 'on top',
      if (window.mode != WindowMode.normal) window.mode.name,
      if (window.hasDialogs)
        '${window.dialogCount} dialog${window.dialogCount == 1 ? '' : 's'}',
    ];
    return ListTile(
      dense: true,
      selected: window.isActive,
      selectedTileColor: colors.primaryContainer.withValues(alpha: 0.35),
      leading: IconTheme.merge(
        data: const IconThemeData(size: 20),
        child: window.icon ?? const Icon(Icons.web_asset),
      ),
      title: Text(window.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: badges.isEmpty ? null : Text(badges.join(' · ')),
      onTap: window.activate,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (window.minimizable)
            IconButton(
              tooltip: window.isMinimized ? 'Restore' : 'Minimize',
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              onPressed: window.isMinimized ? window.restore : window.minimize,
              icon: Icon(
                window.isMinimized
                    ? Icons.open_in_full_rounded
                    : Icons.minimize_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Close',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            onPressed: () => window.close(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
