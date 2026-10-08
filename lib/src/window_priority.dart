/// Named stacking priorities for `WindowStackController.open`.
///
/// A window's priority is a plain `int`. Windows with a higher priority are
/// always drawn above windows with a lower priority, no matter which window
/// is active. Within the same priority, the most recently activated window is
/// on top.
///
/// Dialogs are not part of this ordering: a stack-level dialog always covers
/// every window, and a window dialog always covers its own window's content.
///
/// ```dart
/// controller.open(
///   title: 'Calculator',
///   priority: WindowPriority.high, // stays above normal windows
///   builder: (context) => const Calculator(),
/// );
/// ```
abstract final class WindowPriority {
  /// Stays below windows with [normal] priority, for example a background
  /// monitor that should never cover the user's work.
  static const int low = -100;

  /// The default priority.
  static const int normal = 0;

  /// Stays above windows with [normal] priority, for example a calculator or
  /// a tool palette that must remain visible while other windows are used.
  static const int high = 100;
}
