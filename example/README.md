# draggable_floating_window example

A small "Workspace" desktop that shows every feature of
[draggable_floating_window](https://pub.dev/packages/draggable_floating_window): different window types,
an always-on-top window, the active-window highlight, window dialog stacks,
stack-level dialogs, the minimized dock and keyboard shortcuts.

```bash
flutter run -d macos   # or -d windows, -d linux, -d chrome
```

| File | Shows |
|------|-------|
| `lib/app/window_launcher.dart` | Opening each window type with `WindowStackController.open` |
| `lib/windows/notes_window.dart` | `onCloseRequest` with a "Discard changes?" window dialog |
| `lib/windows/tasks_window.dart` | Stacked window dialogs and `Navigator.pop` results |
| `lib/windows/calculator_window.dart` | `WindowPriority.high` and a custom title bar action |
| `lib/windows/activity_window.dart` | Reading the stacking order and driving windows from code |
| `lib/windows/settings_window.dart` | Theme extension, controls style and a stack-level dialog |

## Tests

```bash
flutter test                                                   # widget tests
flutter test integration_test/window_behaviors_test.dart -d macos
```

`window_behaviors_test.dart` drives the real app with a mouse and a keyboard: dragging and
clamping, all eight resize edges and their cursors, minimum size, minimize and restore from the
dock, maximize and restore, closing, keep-on-top, focus memory, Ctrl+Tab, Ctrl+F4 and both kinds of
dialogs.

## README screenshots and demo GIF

The screenshots come from `integration_test/screenshots_test.dart`, which prints the folder it
saved them to:

```bash
flutter test integration_test/screenshots_test.dart -d macos
```

The demo GIF is a real screen recording. Record the app with Cmd+Shift+5 ("Record Selected
Portion"), then turn the recording into a GIF:

```bash
swift tool/extract_frames.swift recording.mov frames 15 1280
dart run tool/make_demo_gif.dart frames demo.gif
gifsicle -O3 demo.gif -o demo.gif
```
