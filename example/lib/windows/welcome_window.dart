import 'package:flutter/material.dart';

import '../app/window_launcher.dart';

/// The first window: what to try in the example.
class WelcomeWindow extends StatelessWidget {
  const WelcomeWindow({super.key, required this.launcher});

  final WindowLauncher launcher;

  static const List<(IconData, String)> _tips = <(IconData, String)>[
    (Icons.open_with_rounded, 'Drag a title bar to move a window.'),
    (Icons.aspect_ratio_rounded, 'Drag an edge or a corner to resize.'),
    (Icons.fullscreen_rounded, 'Double-click a title bar to maximize.'),
    (Icons.keyboard_rounded, 'Ctrl+Tab switches windows. Ctrl+F4 closes one.'),
    (Icons.push_pin_outlined, 'The calculator stays on top of the others.'),
    (Icons.layers_outlined, 'Tasks → Clear completed → Review stacks dialogs.'),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      children: <Widget>[
        Text(
          'A desktop inside your Flutter app',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Every window here is a widget in one Flutter view.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final (IconData icon, String tip) in _tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(child: Text(tip)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            FilledButton.icon(
              onPressed: launcher.openTasks,
              icon: const Icon(Icons.checklist_rounded),
              label: const Text('Open Tasks'),
            ),
            FilledButton.tonalIcon(
              onPressed: launcher.openCalculator,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Open Calculator'),
            ),
          ],
        ),
      ],
    );
  }
}
