import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_stack/window_stack.dart';

import '../app/window_launcher.dart';

/// Flutter's [MenuBar]. Its menus open in the app's overlay, above the
/// windows, because the [WindowStack] is part of the page.
class DesktopMenuBar extends StatelessWidget {
  const DesktopMenuBar({super.key, required this.launcher});

  final WindowLauncher launcher;

  WindowStackController get _windows => launcher.controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _windows,
      builder: (BuildContext context, Widget? child) {
        final WindowEntry? active = _windows.activeWindow;
        return Material(
          color: colors.surfaceContainer,
          child: Row(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.dashboard_customize_outlined,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Workspace',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MenuBar(
                  style: const MenuStyle(
                    elevation: WidgetStatePropertyAll<double>(0),
                    backgroundColor: WidgetStatePropertyAll<Color>(
                      Colors.transparent,
                    ),
                  ),
                  children: <Widget>[
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.sticky_note_2_outlined),
                          onPressed: launcher.openNote,
                          child: const Text('New note'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.checklist_rounded),
                          onPressed: launcher.openTasks,
                          child: const Text('Tasks'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.calculate_outlined),
                          onPressed: launcher.openCalculator,
                          child: const Text('Calculator'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.layers_outlined),
                          onPressed: launcher.openActivity,
                          child: const Text('Activity'),
                        ),
                        MenuItemButton(
                          leadingIcon: const Icon(Icons.tune_rounded),
                          onPressed: launcher.openSettings,
                          child: const Text('Settings'),
                        ),
                      ],
                      child: const Text('Open'),
                    ),
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          shortcut: const SingleActivator(
                            LogicalKeyboardKey.tab,
                            control: true,
                          ),
                          onPressed: _windows.windows.isEmpty
                              ? null
                              : _windows.activateNext,
                          child: const Text('Next window'),
                        ),
                        MenuItemButton(
                          shortcut: const SingleActivator(
                            LogicalKeyboardKey.tab,
                            control: true,
                            shift: true,
                          ),
                          onPressed: _windows.windows.isEmpty
                              ? null
                              : _windows.activatePrevious,
                          child: const Text('Previous window'),
                        ),
                        const Divider(),
                        MenuItemButton(
                          onPressed: active?.minimizable ?? false
                              ? active!.minimize
                              : null,
                          child: const Text('Minimize'),
                        ),
                        MenuItemButton(
                          onPressed: active?.maximizable ?? false
                              ? active!.toggleMaximize
                              : null,
                          child: Text(
                            active?.isMaximized ?? false
                                ? 'Restore'
                                : 'Maximize',
                          ),
                        ),
                        MenuItemButton(
                          shortcut: const SingleActivator(
                            LogicalKeyboardKey.f4,
                            control: true,
                          ),
                          onPressed:
                              active == null ? null : () => active.close(),
                          child: const Text('Close window'),
                        ),
                        const Divider(),
                        MenuItemButton(
                          onPressed: _windows.windows.isEmpty
                              ? null
                              : launcher.closeAll,
                          child: const Text('Close all…'),
                        ),
                      ],
                      child: const Text('Window'),
                    ),
                    SubmenuButton(
                      menuChildren: <Widget>[
                        MenuItemButton(
                          onPressed: launcher.openWelcome,
                          child: const Text('Welcome'),
                        ),
                        MenuItemButton(
                          onPressed: launcher.showAbout,
                          child: const Text('About Workspace'),
                        ),
                      ],
                      child: const Text('Help'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
