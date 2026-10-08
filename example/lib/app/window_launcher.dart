import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

import '../windows/activity_window.dart';
import '../windows/calculator_window.dart';
import '../windows/dialogs.dart';
import '../windows/notes_window.dart';
import '../windows/settings_window.dart';
import '../windows/tasks_window.dart';
import '../windows/welcome_window.dart';

/// Opens every window type of the example.
///
/// Keeping the `open` calls in one place makes the window types easy to
/// compare: sizes, ids for single-instance windows, priorities and close
/// confirmation.
class WindowLauncher {
  WindowLauncher(this.controller);

  final WindowStackController controller;

  int _noteCount = 0;

  void openWelcome() {
    controller.open(
      id: 'welcome',
      title: 'Welcome',
      icon: const Icon(Icons.waving_hand_outlined),
      size: const Size(520, 430),
      builder: (BuildContext context) => WelcomeWindow(launcher: this),
    );
  }

  /// Notes can be opened many times. Each one asks before closing with
  /// unsaved changes.
  WindowEntry openNote({String text = ''}) {
    final NoteDocument note = NoteDocument(
      name: 'Note ${++_noteCount}',
      text: text,
    );
    late final WindowEntry window;
    window = controller.open(
      title: note.name,
      icon: const Icon(Icons.sticky_note_2_outlined),
      size: const Size(440, 360),
      // Window dialogs are laid out inside the window, so keep room for the
      // "Discard changes?" dialog.
      minSize: const Size(360, 320),
      builder: (BuildContext context) => NotesWindow(note: note),
      onCloseRequest: () async {
        if (!note.isDirty) {
          return true;
        }
        // A window dialog: only this note is blocked while it is open.
        final bool? discard = await window.showDialog<bool>(
          barrierDismissible: false,
          builder: (BuildContext context) =>
              DiscardChangesDialog(name: note.name),
        );
        return discard ?? false;
      },
    );
    return window;
  }

  /// A single-instance window: opening it again brings it to the front.
  void openTasks() {
    controller.open(
      id: 'tasks',
      title: 'Tasks',
      icon: const Icon(Icons.checklist_rounded),
      size: const Size(420, 440),
      minSize: const Size(360, 400),
      builder: (BuildContext context) => const TasksWindow(),
    );
  }

  /// A small tool that stays above normal windows, even when they are active.
  void openCalculator() {
    controller.open(
      id: 'calculator',
      title: 'Calculator',
      icon: const Icon(Icons.calculate_outlined),
      size: const Size(290, 400),
      priority: WindowPriority.high,
      resizable: false,
      maximizable: false,
      builder: (BuildContext context) => const CalculatorWindow(),
      titleBarBuilder: (BuildContext context, WindowEntry window) =>
          const WindowTitleBar(actions: <Widget>[KeepOnTopButton()]),
    );
  }

  void openActivity() {
    controller.open(
      id: 'activity',
      title: 'Activity',
      icon: const Icon(Icons.layers_outlined),
      size: const Size(380, 420),
      minSize: const Size(320, 260),
      builder: (BuildContext context) => ActivityWindow(controller: controller),
    );
  }

  void openSettings() {
    controller.open(
      id: 'settings',
      title: 'Settings',
      icon: const Icon(Icons.tune_rounded),
      size: const Size(420, 440),
      minSize: const Size(360, 320),
      builder: (BuildContext context) => const SettingsWindow(),
    );
  }

  /// A stack-level dialog: it covers and blocks every window.
  Future<void> showAbout() {
    return controller.showDialog<void>(
      builder: (BuildContext context) => const AboutWorkspaceDialog(),
    );
  }

  /// Asks once, then closes every window. Notes with unsaved changes still
  /// ask for themselves.
  Future<void> closeAll() async {
    if (controller.windows.isEmpty) {
      return;
    }
    final bool? confirmed = await controller.showDialog<bool>(
      builder: (BuildContext context) =>
          CloseAllDialog(count: controller.windows.length),
    );
    if (confirmed ?? false) {
      await controller.closeAll();
    }
  }
}
