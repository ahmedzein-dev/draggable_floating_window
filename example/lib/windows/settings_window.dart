import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

import '../app/workspace_settings.dart';

/// Changes the app's appearance, and shows that Flutter's own popups, such as
/// the accent [DropdownButton], open above every window.
class SettingsWindow extends StatelessWidget {
  const SettingsWindow({super.key});

  @override
  Widget build(BuildContext context) {
    final WorkspaceSettings settings = WorkspaceSettingsScope.of(context);
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Appearance', style: text.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const <ButtonSegment<ThemeMode>>[
            ButtonSegment<ThemeMode>(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_outlined),
              label: Text('Light'),
            ),
            ButtonSegment<ThemeMode>(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_outlined),
              label: Text('Dark'),
            ),
          ],
          selected: <ThemeMode>{settings.themeMode},
          onSelectionChanged: (Set<ThemeMode> value) =>
              settings.themeMode = value.single,
        ),
        const SizedBox(height: 16),
        Text('Window buttons', style: text.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<WindowControlsStyle>(
          segments: const <ButtonSegment<WindowControlsStyle>>[
            ButtonSegment<WindowControlsStyle>(
              value: WindowControlsStyle.trafficLights,
              label: Text('Traffic lights'),
            ),
            ButtonSegment<WindowControlsStyle>(
              value: WindowControlsStyle.windows,
              label: Text('Windows'),
            ),
          ],
          selected: <WindowControlsStyle>{settings.controlsStyle},
          onSelectionChanged: (Set<WindowControlsStyle> value) =>
              settings.controlsStyle = value.single,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(child: Text('Accent color', style: text.titleSmall)),
            DropdownButton<Color>(
              value: settings.accent,
              onChanged: (Color? color) {
                if (color != null) {
                  settings.accent = color;
                }
              },
              items: <DropdownMenuItem<Color>>[
                for (final ({String name, Color color}) accent
                    in WorkspaceSettings.accents)
                  DropdownMenuItem<Color>(
                    value: accent.color,
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(radius: 7, backgroundColor: accent.color),
                        const SizedBox(width: 8),
                        Text(accent.name),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Divider(height: 32),
        Text('Dialogs', style: text.titleSmall),
        const SizedBox(height: 8),
        Text(
          'A window dialog blocks one window. A stack dialog blocks all of '
          'them.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: () => showWindowDialog<void>(
                context: context,
                builder: (BuildContext context) => const _InfoDialog(
                  title: 'Window dialog',
                  message: 'Only Settings is blocked. Click another window: it '
                      'still works.',
                ),
              ),
              child: const Text('Window dialog'),
            ),
            OutlinedButton(
              onPressed: () => WindowStack.of(context).showDialog<void>(
                builder: (BuildContext context) => const _InfoDialog(
                  title: 'Stack dialog',
                  message: 'Every window is blocked until this closes.',
                ),
              ),
              child: const Text('Stack dialog'),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoDialog extends StatelessWidget {
  const _InfoDialog({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
