import 'package:flutter/material.dart';
import 'package:draggable_floating_window/draggable_floating_window.dart';

import '../app/window_launcher.dart';
import 'desktop_background.dart';
import 'desktop_menu_bar.dart';
import 'status_bar.dart';

/// The example's only page: a menu bar, the window area and a status bar.
class DesktopScreen extends StatefulWidget {
  const DesktopScreen({super.key, this.openWelcomeWindow = true});

  /// Whether to greet the user with the Welcome window.
  final bool openWelcomeWindow;

  @override
  State<DesktopScreen> createState() => _DesktopScreenState();
}

class _DesktopScreenState extends State<DesktopScreen> {
  final WindowStackController _windows = WindowStackController();
  late final WindowLauncher _launcher = WindowLauncher(_windows);

  @override
  void initState() {
    super.initState();
    if (widget.openWelcomeWindow) {
      _launcher.openWelcome();
    }
  }

  @override
  void dispose() {
    _windows.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DesktopMenuBar(launcher: _launcher),
          Expanded(
            // The WindowStack lives inside the page, so the menu bar's
            // menus, dropdowns and Flutter dialogs open above the windows.
            child: WindowStack(
              controller: _windows,
              child: DesktopBackground(launcher: _launcher),
            ),
          ),
          StatusBar(controller: _windows),
        ],
      ),
    );
  }
}
