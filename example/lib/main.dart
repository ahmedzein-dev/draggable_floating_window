import 'package:flutter/material.dart';

import 'app/workspace_settings.dart';
import 'desktop/desktop_screen.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, this.openWelcomeWindow = true});

  /// Whether the desktop opens with the Welcome window.
  final bool openWelcomeWindow;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final WorkspaceSettings _settings = WorkspaceSettings();

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceSettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            title: 'draggable_floating_window example',
            debugShowCheckedModeBanner: false,
            themeMode: _settings.themeMode,
            theme: _settings.theme(Brightness.light),
            darkTheme: _settings.theme(Brightness.dark),
            home: DesktopScreen(openWelcomeWindow: widget.openWelcomeWindow),
          );
        },
      ),
    );
  }
}
