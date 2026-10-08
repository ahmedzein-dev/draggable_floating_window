/// How a window is currently displayed inside its `WindowStack`.
enum WindowMode {
  /// Shown at its own position and size. The window can be dragged and
  /// resized.
  normal,

  /// Collapsed to a small bar in the dock along the bottom edge of the
  /// `WindowStack`. The window's content stays alive but is hidden and cannot
  /// take keyboard focus.
  minimized,

  /// Fills the whole `WindowStack`. Restoring returns the window to the
  /// position and size it had before.
  maximized,
}
