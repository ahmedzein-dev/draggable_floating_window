import 'package:flutter/widgets.dart';

import 'theme_scope.dart';

/// The text used by the default window chrome for tooltips and screen
/// readers.
///
/// The defaults are English. Pass translated labels to `WindowStack.labels`:
///
/// ```dart
/// WindowStack(
///   controller: controller,
///   labels: const WindowStackLabels(
///     close: 'Fermer',
///     minimize: 'Réduire',
///     maximize: 'Agrandir',
///     restore: 'Restaurer',
///   ),
/// );
/// ```
@immutable
class WindowStackLabels {
  /// Creates labels. Every argument has an English default.
  const WindowStackLabels({
    this.close = 'Close',
    this.minimize = 'Minimize',
    this.maximize = 'Maximize',
    this.restore = 'Restore',
    this.dismiss = 'Dismiss',
  });

  /// The label of the close button.
  final String close;

  /// The label of the minimize button.
  final String minimize;

  /// The label of the maximize button.
  final String maximize;

  /// The label of the restore button, shown on maximized and minimized
  /// windows.
  final String restore;

  /// The screen reader label of a dismissible dialog barrier.
  final String dismiss;

  /// Returns the labels of the nearest `WindowStack`, or the English defaults
  /// outside a stack.
  static WindowStackLabels of(BuildContext context) {
    return WindowStackThemeScope.maybeOf(context)?.labels ??
        const WindowStackLabels();
  }

  @override
  bool operator ==(Object other) {
    return other is WindowStackLabels &&
        other.close == close &&
        other.minimize == minimize &&
        other.maximize == maximize &&
        other.restore == restore &&
        other.dismiss == dismiss;
  }

  @override
  int get hashCode => Object.hash(close, minimize, maximize, restore, dismiss);
}
