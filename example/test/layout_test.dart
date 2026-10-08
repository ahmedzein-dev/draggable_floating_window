import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draggable_floating_window/draggable_floating_window.dart';
import 'package:draggable_floating_window_example/main.dart';
import 'package:draggable_floating_window_example/windows/notes_window.dart';
import 'package:draggable_floating_window_example/windows/settings_window.dart';

/// Flutter reports any overflow as a test failure, so these tests check that
/// nothing overflows at the smallest app window the macOS runner allows, with
/// every window shrunk to its minimum size and every dialog open.
void main() {
  for (final Size size in const <Size>[Size(720, 480), Size(1280, 800)]) {
    testWidgets(
        'nothing overflows at ${size.width.toInt()}x'
        '${size.height.toInt()}', (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const ExampleApp());
      await tester.pumpAndSettle();
      final WindowStackController windows = WindowStack.of(
        tester.element(find.byType(WindowTitleBar).first),
      );

      Future<void> tap(Finder finder) async {
        await tester.tap(finder.first, warnIfMissed: false);
        await tester.pumpAndSettle();
      }

      // Open every window type from the menu bar: its menus open above the
      // windows, so a window covering a desktop icon does not get in the way.
      for (final String item in <String>[
        'New note',
        'Tasks',
        'Calculator',
        'Activity',
        'Settings',
      ]) {
        await tap(find.text('Open'));
        await tap(
          find.descendant(
            of: find.byType(MenuItemButton),
            matching: find.text(item),
          ),
        );
      }
      expect(windows.windows, hasLength(6));

      // Shrink every resizable window to its minimum size.
      for (final WindowEntry window in windows.windows) {
        window.resizeTo(Size.zero);
      }
      await tester.pumpAndSettle();

      // The dialog stack in Tasks.
      windows.windowById('tasks')!.activate();
      await tester.pumpAndSettle();
      await tap(find.text('Clear completed'));
      await tap(find.text('Review'));
      expect(windows.windowById('tasks')!.dialogCount, 2);
      await tap(find.text('Back'));
      await tap(find.text('Cancel'));

      // The close confirmation of a note with unsaved changes.
      final WindowEntry note = windows.windows.firstWhere(
        (WindowEntry window) => window.title.startsWith('Note'),
      );
      note.activate();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(NotesWindow),
          matching: find.byType(TextField),
        ),
        'Draft',
      );
      await tester.pumpAndSettle();
      final Future<bool> closing = note.close();
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tap(find.text('Keep editing'));
      expect(await closing, isFalse);

      // A window dialog and a stack dialog from Settings.
      windows.windowById('settings')!.activate();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Window dialog'),
        80,
        scrollable: find
            .descendant(
              of: find.byType(SettingsWindow),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tap(find.text('Window dialog'));
      await tap(find.text('OK'));
      await tap(find.text('Stack dialog'));
      await tap(find.text('OK'));

      // Everything minimized to the dock.
      for (final WindowEntry window in windows.windows) {
        window.minimize();
      }
      await tester.pumpAndSettle();
      expect(find.byType(MinimizedWindowBar), findsNWidgets(6));
    });
  }
}
