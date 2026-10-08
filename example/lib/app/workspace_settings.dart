import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

/// App-wide appearance settings, changed from the Settings window.
class WorkspaceSettings extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accent = accents.first.color;
  WindowControlsStyle _controlsStyle = WindowControlsStyle.trafficLights;

  /// The accent colors offered in the Settings window.
  static const List<({String name, Color color})> accents =
      <({String name, Color color})>[
    (name: 'Indigo', color: Color(0xFF5B6CFF)),
    (name: 'Teal', color: Color(0xFF14B8A6)),
    (name: 'Amber', color: Color(0xFFF59E0B)),
    (name: 'Rose', color: Color(0xFFF43F5E)),
  ];

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    _themeMode = value;
    notifyListeners();
  }

  Color get accent => _accent;
  set accent(Color value) {
    _accent = value;
    notifyListeners();
  }

  WindowControlsStyle get controlsStyle => _controlsStyle;
  set controlsStyle(WindowControlsStyle value) {
    _controlsStyle = value;
    notifyListeners();
  }

  /// Builds the app theme. The window look is configured once, as a
  /// [ThemeExtension], so it follows light and dark mode.
  ThemeData theme(Brightness brightness) {
    final ColorScheme colors = ColorScheme.fromSeed(
      seedColor: _accent,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      visualDensity: VisualDensity.compact,
      extensions: <ThemeExtension<dynamic>>[
        WindowStackThemeData(
          controlsStyle: _controlsStyle,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          activeBorderColor: colors.primary.withValues(alpha: 0.75),
        ),
      ],
    );
  }
}

/// Makes the [WorkspaceSettings] available to every window.
class WorkspaceSettingsScope extends InheritedNotifier<WorkspaceSettings> {
  const WorkspaceSettingsScope({
    super.key,
    required WorkspaceSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static WorkspaceSettings of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<WorkspaceSettingsScope>()!
        .notifier!;
  }
}
