# 0.0.1

Initial release, extracted from the windowing layer of a production Flutter desktop app and
rebuilt as a standalone package with no dependencies beyond Flutter.

## Added

- **`WindowStack` and `WindowStackController`**: floating windows inside one Flutter view, opened
  with `controller.open(...)`. Windows drag by the title bar, resize from every edge and corner,
  minimize to a dock, maximize on a button or a title bar double-click, and close with an optional
  async `onCloseRequest`.
- **Priority stacking**: windows with a higher `priority` always stay above lower ones, even while a
  lower one is active. Clicking a window raises it within its priority. `WindowEntry.priority` can
  change at runtime.
- **Dialog stacks**: `WindowEntry.showDialog` blocks one window, `WindowStackController.showDialog`
  blocks every window, and `showWindowDialog` picks the enclosing one. Dialogs stack, close with
  `Navigator.pop(context, result)`, and dismiss with Escape or the barrier.
- **Focus management**: every window has its own focus scope. Activating a window returns focus to
  where it was; closing or minimizing the active window activates the most recently used one.
- **Keyboard shortcuts**: Ctrl+Tab, Ctrl+Shift+Tab and Ctrl+F4, rebindable through
  `WindowStack.shortcuts` and five window intents.
- **Single-instance windows** through `id`, **cascade** or **center** placement, and windows that fit
  a shrinking stack and spring back when it grows.
- **Customization**: `WindowStackThemeData` (also a `ThemeExtension`), macOS-style traffic lights or
  Windows-style buttons, custom title bars from `WindowDragArea` and `WindowControls`, a custom dock bar,
  translatable labels and right-to-left layouts.
