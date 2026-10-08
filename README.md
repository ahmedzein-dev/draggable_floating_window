# Draggable Floating Window

[![Pub Version](https://img.shields.io/pub/v/draggable_floating_window.svg)](https://pub.dev/packages/draggable_floating_window)
[![Pub Points](https://img.shields.io/pub/points/draggable_floating_window)](https://pub.dev/packages/draggable_floating_window/score)
[![Likes](https://img.shields.io/pub/likes/draggable_floating_window)](https://pub.dev/packages/draggable_floating_window/score)

Floating, draggable, resizable windows inside your Flutter app. A desktop windowing layer with
priority-stacked windows, their own dialog stacks and keyboard focus management, all in one Flutter
view. Everything starts with the `WindowStack` widget.

Out of the box, a Flutter desktop app runs in a single window, and Flutter has no widget for windows
*inside* it. Back-office tools, admin consoles and accounting apps need that layer: operators keep
an invoice, a statement and two lookups open at once, switch between them all day, and expect each
one to behave like a native window. `draggable_floating_window` adds that layer with no dependencies
beyond Flutter. It was extracted from a production Flutter desktop app.

> The windows are widgets in your app's single Flutter view (an in-app, MDI-style window manager).
> They do not create operating-system windows. See [Platform notes](#platform-notes-and-limitations).

## Demo

<img src="https://raw.githubusercontent.com/ahmedzein-dev/draggable_floating_window/main/assets/demo.gif" width="860" alt="Dragging windows, priority stacking, focus switching, a dialog stack inside a window, the dock and maximize" />

*Dragging and stacking windows, the always-on-top calculator, focus switching with the mouse and
Ctrl+Tab, a dialog stack inside the Tasks window while the other windows stay usable, the dock, and
closing a note with unsaved changes.*

| Overview | Dialog stack | Light theme, Windows-style buttons |
|:--------:|:------------:|:----------------------------------:|
| <img src="https://raw.githubusercontent.com/ahmedzein-dev/draggable_floating_window/main/screenshots/overview.webp" width="280" alt="Several windows, the active one highlighted, a calculator kept on top" /> | <img src="https://raw.githubusercontent.com/ahmedzein-dev/draggable_floating_window/main/screenshots/dialog_stack.webp" width="280" alt="Two stacked dialogs inside the Tasks window" /> | <img src="https://raw.githubusercontent.com/ahmedzein-dev/draggable_floating_window/main/screenshots/light_windows_style.webp" width="280" alt="Light theme, Windows-style buttons, minimized windows in the dock and a dropdown open above the windows" /> |

## Features

### 🪟 Windows
- 🖱️ **Drag** by the title bar, **resize** from any edge or corner, with resize cursors
- 📐 **Always inside the stack**: windows are clamped while dragging and resizing, shrink to fit when
  the stack gets smaller, and spring back when it grows again
- ⬇️ **Minimize to a dock** along the bottom edge; content keeps its state, scroll position and input
- ⬆️ **Maximize** with the button or a title bar double-click; restore returns the previous bounds
- 🔁 **Single-instance windows**: open with an `id`, and opening it again brings the existing one forward
- 🛑 **Close confirmation** with an async `onCloseRequest`, for unsaved changes

### 🗂️ Priority stacking
- 🔝 **Priority bands**: a window with a higher `priority` always stays above lower ones, even while
  a lower window is active (calculators, tool palettes)
- 🎯 **Click to raise**: any click inside a window activates it and brings it to the front of its band
- 🔀 **Change priority at runtime** for a "keep on top" toggle

### 💬 Dialog stacks
- 🧱 **Window dialogs** block only their window; every other window stays usable
- 🌐 **Stack dialogs** block every window, for app-level confirmations
- 📚 **Real stacks**: a dialog opened from a dialog goes on top; closing it returns to the one below
- ↩️ **`Navigator.pop(context, result)` works** inside both, so `AlertDialog` code works unchanged
- ⎋ **Escape and the barrier** dismiss, with `barrierDismissible` like `showDialog`

### ⌨️ Focus management
- 🔦 **Visible active window**: highlighted title bar, outline, shadow and traffic lights
- 🧠 **Focus memory**: each window has its own focus scope; coming back to a window returns focus to
  the field you left
- ➡️ **Focus handoff**: closing or minimizing the active window activates the most recently used one
- ⌨️ **Shortcuts**: Ctrl+Tab and Ctrl+Shift+Tab cycle windows, Ctrl+F4 closes; all rebindable

### 🎨 Customization
- 🎨 **Theme** through `WindowStackThemeData`, also usable as a `ThemeExtension`
- 🍎 **macOS traffic lights or Windows-style buttons**, built in
- 🧩 **Custom title bars and dock bars** from building blocks: `WindowDragArea`, `WindowControls`
- 🌍 **RTL** layouts and translatable button labels

## Installation

```bash
flutter pub add draggable_floating_window
```

---

## Quick Start

Create a `WindowStackController`, put a `WindowStack` in your page, and open windows:

```dart
import 'package:flutter/material.dart';
import 'package:draggable_floating_window/draggable_floating_window.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  final WindowStackController _windows = WindowStackController();

  @override
  void dispose() {
    _windows.dispose();
    super.dispose();
  }

  void _openInvoice(int number) {
    _windows.open(
      id: 'invoice-$number', // opening it again focuses the existing window
      title: 'Invoice #$number',
      icon: const Icon(Icons.receipt_long_outlined),
      size: const Size(640, 480),
      builder: (context) => InvoiceForm(number: number),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openInvoice(1042),
          ),
        ],
      ),
      // Windows float above `child`, like a desktop above its wallpaper.
      body: WindowStack(
        controller: _windows,
        child: const ColoredBox(color: Color(0xFF1E293B)),
      ),
    );
  }
}
```

Inside a window, reach it with `WindowEntry.of(context)`:

```dart
FilledButton(
  onPressed: () => WindowEntry.of(context).close(),
  child: const Text('Done'),
)
```

---

## Common Use Cases

### Ask before closing with unsaved changes

```dart
late final WindowEntry window;
window = controller.open(
  title: 'Notes',
  builder: (context) => NotesEditor(document: document),
  onCloseRequest: () async {
    if (!document.isDirty) return true;
    final discard = await window.showDialog<bool>(
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  },
);
```

### A tool that stays on top

```dart
controller.open(
  id: 'calculator',
  title: 'Calculator',
  size: const Size(290, 400),
  priority: WindowPriority.high, // above every normal window
  resizable: false,
  maximizable: false,
  builder: (context) => const Calculator(),
);
```

### A dialog stack inside a window

`showWindowDialog` shows the dialog in the window that encloses `context`. A dialog opened from
inside another dialog stacks on top of it:

```dart
final bool? clear = await showWindowDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Clear 3 completed tasks?'),
    actions: [
      TextButton(
        // Opens a second dialog on top of this one, in the same window.
        onPressed: () => showWindowDialog<void>(
          context: context,
          builder: (context) => const CompletedTasksDialog(),
        ),
        child: const Text('Review'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Clear'),
      ),
    ],
  ),
);
```

### Which dialog to use

| You want to block | Use |
|---|---|
| One window | `window.showDialog(...)`, or `showWindowDialog(context: ...)` from inside the window |
| Every window, but not the rest of the page | `controller.showDialog(...)` |
| The whole app | Flutter's `showDialog(...)` |

---

## API Overview

| Type | What it does |
|------|--------------|
| `WindowStack` | The widget that hosts the windows, the dock and stack-level dialogs. `child` is drawn behind the windows. |
| `WindowStackController` | Opens and arranges windows: `open`, `activate`, `activateNext`, `activatePrevious`, `closeAll`, `showDialog`, `popDialog`, `windows` (bottom to top), `activeWindow`, `windowById`. |
| `WindowEntry` | One open window: `title`, `icon`, `priority`, `mode`, `bounds`, `isActive`, `close`, `minimize`, `maximize`, `restore`, `toggleMaximize`, `moveTo`, `resizeTo`, `setBounds`, `showDialog`, `popDialog`. `WindowEntry.of(context)` inside a window. |
| `showWindowDialog` | Shows a dialog in the enclosing window, or the enclosing stack. |
| `WindowPriority` | Named priorities: `low`, `normal`, `high`. Any `int` works. |
| `WindowMode` | `normal`, `minimized`, `maximized`. |
| `WindowPlacement` | Where new windows appear: `cascade()` (default), `center()`, or your own subclass. |
| `WindowStackThemeData` | The look of the windows. Also a `ThemeExtension`. |
| `WindowTitleBar`, `WindowControls`, `WindowDragArea`, `MinimizedWindowBar` | The default chrome, and building blocks for your own. |
| `ActivateNextWindowIntent`, `ActivatePreviousWindowIntent`, `CloseWindowIntent`, `MinimizeWindowIntent`, `ToggleMaximizeWindowIntent` | Intents for keyboard shortcuts. |
| `WindowStackLabels` | Tooltip and screen reader text, for translation. |

### `WindowStackController.open` Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `builder` | `WidgetBuilder` | Builds the window's content. Called once, not on every stack rebuild. | required |
| `id` | `String?` | Identifies the window. Opening an id that is already open activates that window instead. | generated |
| `title` | `String` | Shown in the title bar, the dock and to screen readers. Mutable through `WindowEntry.title`. | `''` |
| `icon` | `Widget?` | Shown before the title. | `null` |
| `size` | `Size?` | Initial size, clamped to the stack. | 70% × 85% of the stack |
| `position` | `Offset?` | Initial top-left corner. | from `placement` |
| `minSize` / `maxSize` | `Size` / `Size?` | Limits for resizing. | `240×160` / none |
| `priority` | `int` | Higher priorities always stay above lower ones. | `WindowPriority.normal` |
| `resizable`, `draggable` | `bool` | Allow resizing and moving. | `true` |
| `minimizable`, `maximizable`, `closable` | `bool` | Show the button and allow the gesture and shortcut. | `true` |
| `titleBarBuilder` | `WindowTitleBarBuilder?` | A title bar for this window only. | stack's |
| `onCloseRequest` | `FutureOr<bool> Function()?` | Return `false` to keep the window open. | `null` |
| `onClosed` | `VoidCallback?` | Called after the window closes. | `null` |

---

## Customization

### Theme

Pass a `WindowStackThemeData` to `WindowStack.theme`, or register it in your `ThemeData` so it
follows light and dark mode. Unset values come from your `ColorScheme`.

```dart
MaterialApp(
  theme: ThemeData(
    colorSchemeSeed: Colors.indigo,
    extensions: const [
      WindowStackThemeData(
        controlsStyle: WindowControlsStyle.windows,
        borderRadius: BorderRadius.all(Radius.circular(8)),
        titleBarHeight: 32,
      ),
    ],
  ),
  home: const Workspace(),
);
```

| Property | Description | Default |
|----------|-------------|---------|
| `backgroundColor` | Behind the window content | `surface` |
| `titleBarColor` / `inactiveTitleBarColor` | Title bar of the active / other windows | `surfaceContainerHigh` / `surfaceContainer` |
| `titleTextStyle` / `inactiveTitleTextStyle` | Title text of the active / other windows | `titleSmall` in `onSurface` / `onSurfaceVariant` |
| `titleBarHeight` | Height of the default title bar | `36` |
| `borderRadius` | Corners of windows in normal mode | `10` |
| `borderColor` / `activeBorderColor` | Outline of other windows / the active window | `outlineVariant` / `primary` at 60% |
| `activeShadows` / `inactiveShadows` | Shadows of the active / other windows | soft drop shadows |
| `controlsStyle` | `trafficLights` or `windows` | `trafficLights` |
| `closeButtonColor`, `minimizeButtonColor`, `maximizeButtonColor` | Traffic light colors; close is also the Windows-style close hover | red, amber, green |
| `inactiveButtonColor` | Traffic lights of inactive windows | `outlineVariant` |
| `resizeHandleSize` | Thickness of the invisible resize zones | `8` |
| `minimizedSize`, `dockPadding`, `dockSpacing` | Size and layout of minimized windows | `200×40`, `10`, `10` |
| `minimizedBarColor`, `minimizedTextStyle` | Look of minimized windows | `surfaceContainerHighest`, `labelLarge` |
| `barrierColor` | Default dialog barrier | black at 30% |
| `animationDuration`, `animationCurve` | Maximize, restore and dialog entrance; `Duration.zero` turns them off | `180ms`, `easeOutCubic` |

### Custom title bar

Build your own bar with `WindowDragArea` (moves the window, double-click maximizes) and
`WindowControls` (the buttons). Add extra actions to the default bar with `WindowTitleBar(actions:)`.

```dart
WindowStack(
  controller: controller,
  titleBarBuilder: (context, window) => Container(
    height: 40,
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Row(
      children: [
        Expanded(
          child: WindowDragArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(window.title),
              ),
            ),
          ),
        ),
        const WindowControls(style: WindowControlsStyle.windows),
      ],
    ),
  ),
);
```

Replace the dock bar with `WindowStack.minimizedBuilder`, choose where windows open with
`WindowStackController(placement: WindowPlacement.center())`, and translate the button labels
with `WindowStack.labels`.

---

## Focus and Keyboard

- **Activation**: any click inside a window, or `window.activate()`, makes it the active window and
  brings it to the front of its priority band.
- **Focus memory**: every window has its own `FocusScope`. Returning to a window puts the cursor back
  in the field you left.
- **Focus handoff**: when the active window closes or minimizes, the most recently used visible window
  becomes active and gets focus. A window closed from code while you type elsewhere does not steal
  focus.
- **Dialogs**: a new dialog takes focus, Tab stays inside it, and closing it returns focus to where it
  was. A dialog on a window that is not active waits until the window is activated.
- **Minimized windows** keep their state but cannot take focus.

| Shortcut | Action |
|----------|--------|
| Ctrl+Tab | Activate the next window (in opening order, skipping minimized ones) |
| Ctrl+Shift+Tab | Activate the previous window |
| Ctrl+F4 | Close the active window |
| Escape | Close the top dialog, when `barrierDismissible` is true |

Shortcuts apply while focus is inside the stack and are disabled while a stack dialog is open.
Rebind them, or add minimize and maximize:

```dart
WindowStack(
  controller: controller,
  shortcuts: {
    ...WindowStack.defaultShortcuts,
    const SingleActivator(LogicalKeyboardKey.keyM, control: true):
        const MinimizeWindowIntent(),
    const SingleActivator(LogicalKeyboardKey.enter, alt: true):
        const ToggleMaximizeWindowIntent(),
  },
);
```

---

## Platform Notes and Limitations

- **Platforms**: pure Dart and Flutter, so it runs everywhere Flutter does. It is designed for pointer
  and keyboard use on macOS, Windows, Linux and the web; on phones the resize zones are small for
  fingers.
- **One Flutter view**: windows cannot leave the app window, appear on another monitor or in the
  taskbar. For real operating-system windows, look at `desktop_multi_window`, `multiview_desktop` or
  Flutter's experimental multi-window API. To control the app's own window, use `window_manager`;
  it works alongside this package.
- **Place the stack inside a page**, not in `MaterialApp.builder`. Then Flutter's popups opened from
  windows (`DropdownButton`, `PopupMenuButton`, `MenuAnchor`, `showDatePicker`, `showDialog`) open
  above every window, which is how a native app behaves.
- **Window content is not a route**: `Navigator.pop(context)` in a window's content pops the page that
  holds the stack. Close windows with `WindowEntry.of(context).close()`. Inside window and stack
  dialogs, `Navigator.pop` is fine: each dialog has its own `Navigator`. Wrap a window's content in your
  own `Navigator` if it needs in-window navigation.
- **Window dialogs are laid out inside the window body**. Keep them smaller than the window, give the
  window a larger `minSize`, or use `AlertDialog(scrollable: true)` so a tall dialog scrolls instead of
  overflowing.
- **SnackBars** shown from window content appear on the page's `Scaffold`. Wrap the content in its own
  `ScaffoldMessenger` and `Scaffold` to show them inside the window.
- **Web**: browsers reserve Ctrl+Tab and Ctrl+F4 (and Ctrl+W closes the tab), so pass your own
  `shortcuts` there.
- **No persistence**: window positions are not saved. `WindowEntry.bounds` and `mode` hold what you need
  to save and restore a layout.

### Related packages

Several packages offer draggable, resizable panels inside a Flutter app, such as
`draggable_overlay_window`, `simple_floating_panel`, `panel_view`, `flutter_mdi_gui` and
`floating_windows`. Compare them for your case. `draggable_floating_window` focuses on many windows at once:
priority bands, dialog stacks per window with `Navigator.pop` support, focus memory and handoff,
keyboard shortcuts, and a minimized dock.

---

## 📌 Full Example

The [example app](https://github.com/ahmedzein-dev/draggable_floating_window/tree/main/example) is a small
"Workspace" desktop: notes with close confirmation, a task list with a dialog stack, an always-on-top
calculator, an activity window that shows the stacking order live, and settings for theme and
window buttons. It runs on macOS, Windows, Linux and the web.

```bash
cd example
flutter run -d macos
```

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue or submit a pull request.

## 🙌 Support

- 🐛 **Bug reports:** Please open issues on [GitHub Issues](https://github.com/ahmedzein-dev/draggable_floating_window/issues)
- 💡 **Feature requests:** Share your ideas on [GitHub Discussions](https://github.com/ahmedzein-dev/draggable_floating_window/discussions)
- ⭐ **Enjoying this package?** Please give it a star on [GitHub](https://github.com/ahmedzein-dev/draggable_floating_window) or like it on [pub.dev](https://pub.dev/packages/draggable_floating_window)

## License

This project is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.
