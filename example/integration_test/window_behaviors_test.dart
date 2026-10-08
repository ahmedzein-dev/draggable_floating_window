// Exercises every window behavior in the real app with a mouse and a
// keyboard:
//
//   flutter test integration_test/window_behaviors_test.dart -d macos
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_stack/window_stack.dart';
import 'package:window_stack_example/desktop/desktop_background.dart';
import 'package:window_stack_example/main.dart';
import 'package:window_stack_example/windows/notes_window.dart';
import 'package:window_stack_example/windows/tasks_window.dart';

/// A resize handle: where to grab it, its cursor, and the expected bounds
/// after dragging it by a delta.
typedef _Handle = ({
  String name,
  Offset Function(Rect frame) grab,
  MouseCursor cursor,
  Rect Function(Rect frame, Offset delta) expected,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every window behavior works with a mouse and a keyboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ExampleApp(openWelcomeWindow: false));
    await tester.pumpAndSettle();
    final WindowStackController windows = WindowStack.of(
      tester.element(find.byType(DesktopBackground)),
    );
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(
        location: tester.getCenter(find.byType(WindowStack)));

    Finder titleOf(String title) => find.descendant(
          of: find.byType(WindowTitleBar),
          matching: find.text(title),
        );
    Finder frameOf(String title) => find
        .ancestor(of: titleOf(title), matching: find.byType(Material))
        .first;
    Finder buttonOf(Finder frame, String tooltip) =>
        find.descendant(of: frame, matching: find.byTooltip(tooltip));
    Rect frameRect(String title) => tester.getRect(frameOf(title));
    final Rect stack = tester.getRect(find.byType(WindowStack));

    Future<void> settle() async {
      await tester.pumpAndSettle();
      // Let the title bar's double-click detector time out.
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> moveMouse(Offset to) async {
      await mouse.moveTo(to);
      await tester.pump();
    }

    Future<void> click(Offset at) async {
      await moveMouse(at);
      await mouse.down(at);
      await tester.pump();
      await mouse.up();
      await settle();
    }

    Future<void> clickOn(Finder finder) =>
        click(tester.getCenter(finder.first));

    Future<void> drag(Offset from, Offset by) async {
      await moveMouse(from);
      await mouse.down(from);
      await tester.pump();
      // Several small moves, like a real mouse.
      const int steps = 12;
      for (int i = 1; i <= steps; i++) {
        await mouse.moveTo(from + by * (i / steps));
        await tester.pump();
      }
      await mouse.up();
      await settle();
    }

    Future<void> doubleClick(Offset at) async {
      await moveMouse(at);
      for (int i = 0; i < 2; i++) {
        await mouse.down(at);
        await tester.pump();
        await mouse.up();
        await tester.pump(const Duration(milliseconds: 60));
      }
      await settle();
    }

    Future<void> controlKey(LogicalKeyboardKey key,
        {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyEvent(key);
      if (shift) {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settle();
    }

    Future<void> openFromMenu(String item) async {
      await clickOn(find.text('Open'));
      await clickOn(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text(item),
        ),
      );
    }

    // Open windows from a desktop icon and from the menu bar.
    await clickOn(find.text('Tasks'));
    await openFromMenu('New note');
    await openFromMenu('Calculator');
    expect(windows.windows.map((WindowEntry window) => window.title), <String>[
      'Tasks',
      'Note 1',
      'Calculator',
    ]);
    final WindowEntry tasks = windows.windowById('tasks')!;
    final WindowEntry note = windows.windows[1];
    final WindowEntry calculator = windows.windowById('calculator')!;
    expect(windows.activeWindow, calculator);

    // Lay the windows out side by side, so no click below lands on the
    // always-on-top calculator by accident.
    tasks.setBounds(const Rect.fromLTWH(40, 40, 420, 440));
    note.setBounds(const Rect.fromLTWH(480, 40, 440, 360));
    calculator.moveTo(Offset(windows.size.width - 310, 40));
    await settle();

    // Clicking a window activates it; the calculator keeps its high priority
    // and stays on top.
    await clickOn(titleOf('Tasks'));
    expect(windows.activeWindow, tasks);
    expect(windows.windows.last, calculator);

    // Dragging the title bar moves the window by exactly the drag distance.
    Rect before = frameRect('Tasks');
    await drag(tester.getCenter(titleOf('Tasks')), const Offset(120, 60));
    expect(
      frameRect('Tasks'),
      rectMoreOrLessEquals(before.shift(const Offset(120, 60))),
    );

    // A window cannot be dragged out of the stack.
    await drag(tester.getCenter(titleOf('Tasks')), const Offset(-2000, -2000));
    expect(frameRect('Tasks').topLeft, offsetMoreOrLessEquals(stack.topLeft));
    await drag(tester.getCenter(titleOf('Tasks')), const Offset(4000, 4000));
    expect(
      frameRect('Tasks').bottomRight,
      offsetMoreOrLessEquals(stack.bottomRight),
    );

    // Each of the eight resize handles moves only its own edges and shows
    // the matching cursor.
    tasks.setBounds(const Rect.fromLTWH(200, 140, 420, 440));
    await settle();
    const double inset = 4;
    final List<_Handle> handles = <_Handle>[
      (
        name: 'right',
        grab: (Rect r) => Offset(r.right - inset, r.center.dy),
        cursor: SystemMouseCursors.resizeLeftRight,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left, r.top, r.right + d.dx, r.bottom),
      ),
      (
        name: 'left',
        grab: (Rect r) => Offset(r.left + inset, r.center.dy),
        cursor: SystemMouseCursors.resizeLeftRight,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left + d.dx, r.top, r.right, r.bottom),
      ),
      (
        name: 'bottom',
        grab: (Rect r) => Offset(r.center.dx, r.bottom - inset),
        cursor: SystemMouseCursors.resizeUpDown,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left, r.top, r.right, r.bottom + d.dy),
      ),
      (
        name: 'top',
        grab: (Rect r) => Offset(r.center.dx, r.top + inset),
        cursor: SystemMouseCursors.resizeUpDown,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left, r.top + d.dy, r.right, r.bottom),
      ),
      (
        name: 'bottom-right',
        grab: (Rect r) => r.bottomRight - const Offset(inset, inset),
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left, r.top, r.right + d.dx, r.bottom + d.dy),
      ),
      (
        name: 'top-left',
        grab: (Rect r) => r.topLeft + const Offset(inset, inset),
        cursor: SystemMouseCursors.resizeUpLeftDownRight,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left + d.dx, r.top + d.dy, r.right, r.bottom),
      ),
      (
        name: 'top-right',
        grab: (Rect r) => r.topRight + const Offset(-inset, inset),
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left, r.top + d.dy, r.right + d.dx, r.bottom),
      ),
      (
        name: 'bottom-left',
        grab: (Rect r) => r.bottomLeft + const Offset(inset, -inset),
        cursor: SystemMouseCursors.resizeUpRightDownLeft,
        expected: (Rect r, Offset d) =>
            Rect.fromLTRB(r.left + d.dx, r.top, r.right, r.bottom + d.dy),
      ),
    ];
    const Offset delta = Offset(30, 24);
    for (final _Handle handle in handles) {
      before = frameRect('Tasks');
      final Offset grab = handle.grab(before);
      await moveMouse(grab);
      expect(
        RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
        handle.cursor,
        reason: 'cursor over the ${handle.name} edge',
      );
      await drag(grab, delta);
      expect(
        frameRect('Tasks'),
        rectMoreOrLessEquals(handle.expected(before, delta)),
        reason: 'dragging the ${handle.name} edge',
      );
    }

    // Resizing stops at the minimum size.
    before = frameRect('Tasks');
    await drag(
      Offset(before.right - inset, before.center.dy),
      const Offset(-1000, 0),
    );
    expect(frameRect('Tasks').width, moreOrLessEquals(tasks.minSize.width));

    // Maximize with the button, restore with a title bar double-click.
    tasks.setBounds(const Rect.fromLTWH(40, 40, 420, 440));
    await settle();
    before = frameRect('Tasks');
    await clickOn(buttonOf(frameOf('Tasks'), 'Maximize'));
    expect(tasks.isMaximized, isTrue);
    expect(frameRect('Tasks'), rectMoreOrLessEquals(stack));
    await doubleClick(tester.getCenter(titleOf('Tasks')));
    expect(tasks.mode, WindowMode.normal);
    expect(frameRect('Tasks'), rectMoreOrLessEquals(before));

    // Minimize to the dock and restore from the dock bar; the content keeps
    // its state.
    await clickOn(
      find
          .descendant(
            of: find.byType(TasksWindow),
            matching: find.byType(Checkbox),
          )
          .at(1),
    );
    expect(find.text('4 of 5 done'), findsOneWidget);
    await clickOn(buttonOf(frameOf('Tasks'), 'Minimize'));
    expect(tasks.isMinimized, isTrue);
    expect(find.byType(TasksWindow), findsNothing);
    expect(windows.activeWindow, isNot(tasks));
    final Finder dockBar = find.byType(MinimizedWindowBar);
    expect(dockBar, findsOneWidget);
    expect(
      tester.getRect(dockBar).bottomLeft,
      offsetMoreOrLessEquals(stack.bottomLeft + const Offset(10, -10)),
    );
    await clickOn(find.descendant(of: dockBar, matching: find.text('Tasks')));
    expect(tasks.mode, WindowMode.normal);
    expect(frameRect('Tasks'), rectMoreOrLessEquals(before));
    expect(find.text('4 of 5 done'), findsOneWidget);

    // Focus memory: activating a window returns focus to its field.
    final Finder noteField = find.descendant(
      of: find.byType(NotesWindow),
      matching: find.byType(EditableText),
    );
    final Finder taskField = find.descendant(
      of: find.byType(TasksWindow),
      matching: find.byType(EditableText),
    );
    bool hasFocus(Finder field) =>
        tester.widget<EditableText>(field).focusNode.hasFocus;
    await clickOn(noteField);
    await tester.enterText(noteField, 'Draft');
    await settle();
    expect(note.title, 'Note 1 •');
    await clickOn(taskField);
    expect(hasFocus(taskField), isTrue);
    await clickOn(titleOf('Note 1 •'));
    expect(windows.activeWindow, note);
    expect(hasFocus(noteField), isTrue);

    // Ctrl+Tab and Ctrl+Shift+Tab cycle the windows in opening order.
    await controlKey(LogicalKeyboardKey.tab);
    expect(windows.activeWindow, calculator);
    await controlKey(LogicalKeyboardKey.tab);
    expect(windows.activeWindow, tasks);
    await controlKey(LogicalKeyboardKey.tab, shift: true);
    expect(windows.activeWindow, calculator);

    // A dialog stack inside Tasks, while the calculator stays usable.
    await clickOn(titleOf('Tasks'));
    await clickOn(find.text('Clear completed'));
    await clickOn(find.text('Review'));
    expect(tasks.dialogCount, 2);
    final Finder calculatorText = find.descendant(
      of: frameOf('Calculator'),
      matching: find.text('7'),
    );
    await clickOn(calculatorText);
    expect(calculatorText, findsNWidgets(2), reason: 'key and display show 7');
    await clickOn(find.text('Back'));
    expect(tasks.dialogCount, 1);
    await clickOn(find.text('Clear'));
    expect(tasks.hasDialogs, isFalse);
    expect(find.text('0 of 1 done'), findsOneWidget);

    // Closing a note with unsaved changes asks first.
    await clickOn(buttonOf(frameOf('Note 1 •'), 'Close'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await clickOn(find.text('Keep editing'));
    expect(note.isClosed, isFalse);
    await clickOn(buttonOf(frameOf('Note 1 •'), 'Close'));
    await clickOn(find.text('Discard'));
    expect(note.isClosed, isTrue);

    // Ctrl+F4 closes the active window.
    await clickOn(titleOf('Tasks'));
    await controlKey(LogicalKeyboardKey.f4);
    expect(tasks.isClosed, isTrue);
    expect(windows.activeWindow, calculator);

    // Windows-style buttons work the same way.
    await openFromMenu('Settings');
    final WindowEntry settings = windows.windowById('settings')!;
    settings.moveTo(const Offset(40, 40));
    await settle();
    await clickOn(find.text('Windows'));
    await clickOn(buttonOf(frameOf('Settings'), 'Maximize'));
    expect(settings.isMaximized, isTrue);
    await clickOn(buttonOf(frameOf('Settings'), 'Restore'));
    expect(settings.mode, WindowMode.normal);
    await clickOn(buttonOf(frameOf('Settings'), 'Minimize'));
    expect(settings.isMinimized, isTrue);
    await clickOn(buttonOf(find.byType(MinimizedWindowBar), 'Close'));
    expect(settings.isClosed, isTrue);

    // Last, the calculator's own close button.
    await clickOn(buttonOf(frameOf('Calculator'), 'Close'));
    expect(windows.windows, isEmpty);
    expect(windows.activeWindow, isNull);
  });
}
