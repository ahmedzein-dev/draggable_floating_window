import 'package:flutter/widgets.dart';

/// Activates the next window in the order the windows were opened, skipping
/// minimized windows. Wraps around after the last window.
///
/// Bound to Ctrl+Tab by `WindowStack.defaultShortcuts`.
class ActivateNextWindowIntent extends Intent {
  /// Creates an intent that activates the next window.
  const ActivateNextWindowIntent();
}

/// Activates the previous window in the order the windows were opened,
/// skipping minimized windows. Wraps around before the first window.
///
/// Bound to Ctrl+Shift+Tab by `WindowStack.defaultShortcuts`.
class ActivatePreviousWindowIntent extends Intent {
  /// Creates an intent that activates the previous window.
  const ActivatePreviousWindowIntent();
}

/// Closes the active window, unless it was opened with `closable: false`.
///
/// Bound to Ctrl+F4, the shortcut that closes a child window in Windows
/// applications, by `WindowStack.defaultShortcuts`.
class CloseWindowIntent extends Intent {
  /// Creates an intent that closes the active window.
  const CloseWindowIntent();
}

/// Minimizes the active window, unless it was opened with
/// `minimizable: false`.
///
/// Not bound by default. Add it to `WindowStack.shortcuts` to use it.
class MinimizeWindowIntent extends Intent {
  /// Creates an intent that minimizes the active window.
  const MinimizeWindowIntent();
}

/// Maximizes the active window, or restores it when it is already maximized.
///
/// Not bound by default. Add it to `WindowStack.shortcuts` to use it.
class ToggleMaximizeWindowIntent extends Intent {
  /// Creates an intent that toggles maximize on the active window.
  const ToggleMaximizeWindowIntent();
}
