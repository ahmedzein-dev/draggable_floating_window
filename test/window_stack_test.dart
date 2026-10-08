import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:draggable_floating_window/draggable_floating_window.dart';

const Size _surface = Size(1000, 700);

Future<WindowStackController> _pumpStack(
  WidgetTester tester, {
  WindowStackThemeData? theme,
  ThemeData? appTheme,
  Map<ShortcutActivator, Intent>? shortcuts,
  Widget? background,
}) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final WindowStackController controller = WindowStackController(
    placement: const WindowPlacement.center(),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: WindowStack(
          controller: controller,
          theme: theme,
          shortcuts: shortcuts,
          child: background,
        ),
      ),
    ),
  );
  return controller;
}

WindowEntry _open(
  WindowStackController controller,
  String title, {
  Rect bounds = const Rect.fromLTWH(100, 100, 400, 300),
  WidgetBuilder? builder,
  int priority = WindowPriority.normal,
  bool resizable = true,
  Size minSize = const Size(240, 160),
  WindowCloseRequestCallback? onCloseRequest,
  VoidCallback? onClosed,
}) {
  return controller.open(
    id: title,
    title: title,
    position: bounds.topLeft,
    size: bounds.size,
    priority: priority,
    resizable: resizable,
    minSize: minSize,
    onCloseRequest: onCloseRequest,
    onClosed: onClosed,
    builder: builder ??
        (BuildContext context) => Center(child: Text('$title content')),
  );
}

Finder _titleOf(String title) {
  return find.descendant(
    of: find.byType(WindowTitleBar),
    matching: find.text(title),
  );
}

/// The window frame (its [Material]) that shows [title] in its title bar.
Finder _frameOf(String title) {
  return find
      .ancestor(of: _titleOf(title), matching: find.byType(Material))
      .first;
}

Finder _buttonOf(String title, String tooltip) {
  return find.descendant(
      of: _frameOf(title), matching: find.byTooltip(tooltip));
}

Finder _dockBarOf(String title) {
  return find.ancestor(
    of: find.descendant(
      of: find.byType(MinimizedWindowBar),
      matching: find.text(title),
    ),
    matching: find.byType(MinimizedWindowBar),
  );
}

/// Pumps until animations finish and pending double-tap timers have fired.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pressControlWith(WidgetTester tester, LogicalKeyboardKey key,
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
  await tester.pumpAndSettle();
}

/// Content with a counter button, to check whether taps reach a window.
class _TapCounter extends StatefulWidget {
  const _TapCounter({required this.label});

  final String label;

  @override
  State<_TapCounter> createState() => _TapCounterState();
}

class _TapCounterState extends State<_TapCounter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('${widget.label}: $taps'),
      ),
    );
  }
}

void main() {
  group('rendering', () {
    testWidgets('shows windows with their titles and content',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(
        tester,
        background: const Text('background'),
      );
      _open(controller, 'Notes');
      _open(controller, 'Tasks',
          bounds: const Rect.fromLTWH(520, 100, 400, 300));
      await tester.pump();

      expect(find.text('background'), findsOneWidget);
      expect(_titleOf('Notes'), findsOneWidget);
      expect(_titleOf('Tasks'), findsOneWidget);
      expect(find.text('Notes content'), findsOneWidget);
      expect(
        tester.getRect(_frameOf('Notes')),
        const Rect.fromLTWH(100, 100, 400, 300),
      );
    });

    testWidgets('windows opened before the first layout are placed',
        (WidgetTester tester) async {
      tester.view.physicalSize = _surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final WindowStackController controller = WindowStackController(
        placement: const WindowPlacement.center(),
      );
      addTearDown(controller.dispose);
      final WindowEntry window = controller.open(
        title: 'Early',
        size: const Size(400, 300),
        builder: (BuildContext context) => const SizedBox(),
      );
      expect(window.bounds, Rect.zero);

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WindowStack(controller: controller))),
      );
      expect(window.bounds, const Rect.fromLTWH(300, 200, 400, 300));
    });

    testWidgets('default size is a fraction of the stack',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = controller.open(
        title: 'Sized',
        builder: (BuildContext context) => const SizedBox(),
      );
      expect(window.bounds.size, const Size(700, 595));
    });

    testWidgets('chrome rebuilds do not rebuild the content',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      int builds = 0;
      _open(
        controller,
        'Counted',
        builder: (BuildContext context) {
          builds++;
          return const SizedBox();
        },
      );
      await tester.pump();
      await tester.drag(_titleOf('Counted'), const Offset(40, 30));
      await _settle(tester);
      controller.windowById('Counted')!.title = 'Renamed';
      await tester.pump();
      expect(builds, 1);
    });
  });

  group('dragging', () {
    testWidgets('dragging the title bar moves the window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.drag(_titleOf('Notes'), const Offset(120, 80));
      await _settle(tester);
      expect(window.bounds, const Rect.fromLTWH(220, 180, 400, 300));
    });

    testWidgets('a window cannot be dragged out of the stack',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.drag(_titleOf('Notes'), const Offset(-500, -500));
      await _settle(tester);
      expect(window.bounds.topLeft, Offset.zero);

      await tester.drag(_titleOf('Notes'), const Offset(2000, 2000));
      await _settle(tester);
      expect(window.bounds, const Rect.fromLTWH(600, 400, 400, 300));
    });

    testWidgets('double-clicking the title bar maximizes and restores',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      Future<void> doubleClick() async {
        await tester.tap(_titleOf('Notes'));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(_titleOf('Notes'));
        await tester.pumpAndSettle();
      }

      await doubleClick();
      expect(window.isMaximized, isTrue);
      expect(tester.getRect(_frameOf('Notes')), Offset.zero & _surface);

      await doubleClick();
      expect(window.mode, WindowMode.normal);
      expect(
        tester.getRect(_frameOf('Notes')),
        const Rect.fromLTWH(100, 100, 400, 300),
      );
      await _settle(tester);
    });
  });

  group('resizing', () {
    testWidgets('the right edge changes only the width',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.dragFrom(const Offset(497, 250), const Offset(60, 40));
      await tester.pump();
      expect(window.bounds, const Rect.fromLTWH(100, 100, 460, 300));
    });

    testWidgets('the bottom-right corner changes both axes',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.dragFrom(const Offset(496, 396), const Offset(30, 20));
      await tester.pump();
      expect(window.bounds, const Rect.fromLTWH(100, 100, 430, 320));
    });

    testWidgets('the left edge stops at the minimum size',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.dragFrom(const Offset(103, 250), const Offset(300, 0));
      await tester.pump();
      expect(window.bounds, const Rect.fromLTWH(260, 100, 240, 300));
    });

    testWidgets('resizable: false removes the handles',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Fixed', resizable: false);
      await tester.pump();

      await tester.dragFrom(const Offset(497, 250), const Offset(60, 40));
      await tester.pump();
      expect(window.bounds.size, const Size(400, 300));
    });
  });

  group('minimize, maximize and close', () {
    testWidgets('minimized windows go to the dock and keep their state',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(
        controller,
        'Notes',
        builder: (BuildContext context) => const TextField(key: Key('field')),
      );
      await tester.pump();
      await tester.enterText(find.byKey(const Key('field')), 'draft');

      await tester.tap(_buttonOf('Notes', 'Minimize'));
      await tester.pumpAndSettle();
      expect(window.isMinimized, isTrue);
      expect(find.byKey(const Key('field')), findsNothing);
      expect(
          tester.getRect(_dockBarOf('Notes')).topLeft, const Offset(10, 650));

      await tester.tap(find.descendant(
          of: _dockBarOf('Notes'), matching: find.text('Notes')));
      await tester.pumpAndSettle();
      expect(window.mode, WindowMode.normal);
      expect(find.text('draft'), findsOneWidget);
      expect(window.bounds, const Rect.fromLTWH(100, 100, 400, 300));
    });

    testWidgets('minimizing with the button hides its tooltip',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      // Hover the minimize button until its tooltip shows, then click it.
      final Offset button = tester.getCenter(_buttonOf('Notes', 'Minimize'));
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(button);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Minimize'), findsOneWidget);

      await mouse.down(button);
      await mouse.up();
      await _settle(tester);
      expect(window.isMinimized, isTrue);
      // The tooltip belongs to the hidden window but paints in the root
      // overlay, so look for it offstage too.
      expect(find.text('Minimize', skipOffstage: false), findsNothing);
    });

    testWidgets('minimizing hides tooltips shown inside the window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(
        controller,
        'Notes',
        builder: (BuildContext context) => Center(
          child: IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save),
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byIcon(Icons.save)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);

      // A shortcut or the app minimizes the window while the pointer still
      // rests on the button.
      window.minimize();
      await _settle(tester);
      expect(find.text('Save', skipOffstage: false), findsNothing);

      // The tooltip works again after the window is restored.
      window.restore();
      await _settle(tester);
      await mouse.moveTo(Offset.zero);
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.byIcon(Icons.save)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('minimizing hides a tooltip that was shown from code',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final GlobalKey<TooltipState> tooltip = GlobalKey<TooltipState>();
      final WindowEntry window = _open(
        controller,
        'Notes',
        builder: (BuildContext context) => Center(
          child: Tooltip(
            key: tooltip,
            message: 'Unsaved changes',
            triggerMode: TooltipTriggerMode.manual,
            child: const Text('Draft'),
          ),
        ),
      );
      await tester.pump();
      tooltip.currentState!.ensureTooltipVisible();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsOneWidget);

      // No pointer will dismiss this tooltip, so minimizing has to.
      window.minimize();
      await _settle(tester);
      expect(find.text('Unsaved changes', skipOffstage: false), findsNothing);
    });

    testWidgets('dock slots fill from the start and reuse freed slots',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final List<WindowEntry> windows = <WindowEntry>[
        for (final String title in <String>['A', 'B', 'C', 'D'])
          _open(controller, title),
      ];
      await tester.pump();
      windows[0].minimize();
      windows[1].minimize();
      windows[2].minimize();
      await tester.pump();
      expect(tester.getRect(_dockBarOf('A')).topLeft, const Offset(10, 650));
      expect(tester.getRect(_dockBarOf('B')).topLeft, const Offset(220, 650));
      expect(tester.getRect(_dockBarOf('C')).topLeft, const Offset(430, 650));

      windows[1].restore();
      windows[3].minimize();
      await tester.pump();
      expect(tester.getRect(_dockBarOf('D')).topLeft, const Offset(220, 650));
    });

    testWidgets('the maximize button fills the stack',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(controller, 'Notes');
      await tester.pump();

      await tester.tap(_buttonOf('Notes', 'Maximize'));
      await tester.pumpAndSettle();
      expect(window.isMaximized, isTrue);
      expect(tester.getRect(_frameOf('Notes')), Offset.zero & _surface);
    });

    testWidgets('the close button closes the window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      int closed = 0;
      _open(controller, 'Notes', onClosed: () => closed++);
      await tester.pump();

      await tester.tap(_buttonOf('Notes', 'Close'));
      await tester.pumpAndSettle();
      expect(controller.windows, isEmpty);
      expect(_titleOf('Notes'), findsNothing);
      expect(closed, 1);
    });

    testWidgets('onCloseRequest can ask with a window dialog',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      late final WindowEntry window;
      window = _open(
        controller,
        'Draft',
        onCloseRequest: () async {
          final bool? discard = await window.showDialog<bool>(
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Discard changes?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard'),
                ),
              ],
            ),
          );
          return discard ?? false;
        },
      );
      await tester.pump();

      await tester.tap(_buttonOf('Draft', 'Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(window.isClosed, isFalse);

      await tester.tap(_buttonOf('Draft', 'Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(window.isClosed, isTrue);
      expect(find.byType(WindowStack), findsOneWidget);
    });
  });

  group('stacking', () {
    testWidgets('clicking a window brings it to the front',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry a = _open(
        controller,
        'A',
        builder: (BuildContext context) => const _TapCounter(label: 'A'),
      );
      _open(
        controller,
        'B',
        bounds: const Rect.fromLTWH(250, 200, 400, 300),
        builder: (BuildContext context) => const _TapCounter(label: 'B'),
      );
      await tester.pump();

      // B covers this point.
      await tester.tapAt(const Offset(300, 300));
      await tester.pump();
      expect(find.text('B: 1'), findsOneWidget);
      expect(find.text('A: 0'), findsOneWidget);

      // Clicking A's visible title bar raises A over B.
      await tester.tap(_titleOf('A'));
      await _settle(tester);
      expect(controller.windows.last, a);
      expect(controller.activeWindow, a);

      await tester.tapAt(const Offset(300, 300));
      await tester.pump();
      expect(find.text('A: 1'), findsOneWidget);
    });

    testWidgets('a high-priority window stays above an active window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry a = _open(
        controller,
        'A',
        builder: (BuildContext context) => const _TapCounter(label: 'A'),
      );
      _open(
        controller,
        'Tool',
        bounds: const Rect.fromLTWH(250, 200, 300, 250),
        priority: WindowPriority.high,
        builder: (BuildContext context) => const _TapCounter(label: 'Tool'),
      );
      await tester.pump();

      await tester.tap(_titleOf('A'));
      await _settle(tester);
      expect(controller.activeWindow, a);
      expect(controller.windows.last.id, 'Tool');

      await tester.tapAt(const Offset(300, 300));
      await tester.pump();
      expect(find.text('Tool: 1'), findsOneWidget);
      expect(find.text('A: 0'), findsOneWidget);
    });

    testWidgets("Flutter's popup menus open above every window",
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      String? selected;
      _open(
        controller,
        'Menu',
        bounds: const Rect.fromLTWH(0, 0, 400, 300),
        builder: (BuildContext context) => Align(
          alignment: Alignment.topLeft,
          child: PopupMenuButton<String>(
            onSelected: (String value) => selected = value,
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'First', child: Text('First')),
              PopupMenuItem<String>(value: 'Second', child: Text('Second')),
              PopupMenuItem<String>(value: 'Third', child: Text('Third')),
            ],
          ),
        ),
      );
      _open(
        controller,
        'Cover',
        bounds: const Rect.fromLTWH(0, 110, 600, 400),
        priority: WindowPriority.high,
        builder: (BuildContext context) => const _TapCounter(label: 'Cover'),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final Rect third = tester.getRect(find.text('Third'));
      expect(third.top, greaterThan(110), reason: 'the item lies over Cover');

      await tester.tap(find.text('Third'));
      await tester.pumpAndSettle();
      expect(selected, 'Third');
      expect(find.text('Cover: 0'), findsOneWidget);
    });
  });

  group('focus', () {
    testWidgets('activating a window restores its focused field',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final FocusNode fieldA = FocusNode();
      final FocusNode fieldB = FocusNode();
      addTearDown(fieldA.dispose);
      addTearDown(fieldB.dispose);
      final WindowEntry a = _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(0, 0, 400, 300),
        builder: (BuildContext context) => TextField(focusNode: fieldA),
      );
      final WindowEntry b = _open(
        controller,
        'B',
        bounds: const Rect.fromLTWH(500, 0, 400, 300),
        builder: (BuildContext context) => TextField(focusNode: fieldB),
      );
      await tester.pump();

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(controller.activeWindow, a);
      expect(fieldA.hasFocus, isTrue);

      await tester.tap(_titleOf('B'));
      await _settle(tester);
      expect(controller.activeWindow, b);
      expect(fieldA.hasFocus, isFalse);

      await tester.tap(find.byType(TextField).last);
      await tester.pump();
      expect(fieldB.hasFocus, isTrue);

      await tester.tap(_titleOf('A'));
      await _settle(tester);
      expect(fieldA.hasFocus, isTrue, reason: 'focus returns where it was');

      await a.close();
      await tester.pumpAndSettle();
      expect(controller.activeWindow, b);
      expect(fieldB.hasFocus, isTrue, reason: 'focus moves to the next window');
    });

    testWidgets('the active window is highlighted',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      _open(controller, 'A', bounds: const Rect.fromLTWH(0, 0, 400, 300));
      _open(controller, 'B', bounds: const Rect.fromLTWH(500, 0, 400, 300));
      await tester.pump();

      final WindowStackThemeData theme = WindowStackThemeData.of(
        tester.element(_titleOf('A')),
      );
      Color titleBarColor(String title) {
        final Container bar = tester.widget<Container>(
          find
              .descendant(
                of: find.ancestor(
                    of: _titleOf(title), matching: find.byType(WindowTitleBar)),
                matching: find.byType(Container),
              )
              .first,
        );
        return bar.color!;
      }

      expect(titleBarColor('B'), theme.titleBarColor);
      expect(titleBarColor('A'), theme.inactiveTitleBarColor);

      await tester.tap(_titleOf('A'));
      await _settle(tester);
      expect(titleBarColor('A'), theme.titleBarColor);
      expect(titleBarColor('B'), theme.inactiveTitleBarColor);
    });
    testWidgets(
      'clicking another window keeps the focus memory on desktop',
      (WidgetTester tester) async {
        final WindowStackController controller = await _pumpStack(tester);
        final FocusNode fieldA = FocusNode();
        final FocusNode fieldB = FocusNode();
        addTearDown(fieldA.dispose);
        addTearDown(fieldB.dispose);
        final WindowEntry a = _open(
          controller,
          'A',
          bounds: const Rect.fromLTWH(0, 0, 400, 300),
          builder: (BuildContext context) => Align(
            alignment: Alignment.topCenter,
            child: TextField(key: const Key('fieldA'), focusNode: fieldA),
          ),
        );
        final WindowEntry b = _open(
          controller,
          'B',
          bounds: const Rect.fromLTWH(500, 0, 400, 300),
          builder: (BuildContext context) => Align(
            alignment: Alignment.topCenter,
            child: TextField(key: const Key('fieldB'), focusNode: fieldB),
          ),
        );
        await tester.pump();

        Future<void> mouseTap(Finder finder) async {
          await tester.tap(finder, kind: PointerDeviceKind.mouse);
          await _settle(tester);
        }

        await mouseTap(find.byKey(const Key('fieldA')));
        expect(fieldA.hasFocus, isTrue);

        // On desktop a focused field unfocuses itself when the mouse goes
        // down outside it. Clicking another window's title bar must still
        // move focus to that window, and coming back must restore the field.
        await mouseTap(_titleOf('B'));
        expect(controller.activeWindow, b);
        expect(b.focusScopeNode.hasFocus, isTrue);
        expect(fieldA.hasFocus, isFalse);

        await mouseTap(find.byKey(const Key('fieldB')));
        expect(fieldB.hasFocus, isTrue);

        await mouseTap(_titleOf('A'));
        expect(controller.activeWindow, a);
        expect(fieldA.hasFocus, isTrue);

        await mouseTap(_titleOf('B'));
        expect(fieldB.hasFocus, isTrue);

        // Minimizing and restoring keeps it too.
        b.minimize();
        await _settle(tester);
        expect(fieldA.hasFocus, isTrue);
        b.restore();
        await _settle(tester);
        expect(fieldB.hasFocus, isTrue);
      },
      variant: TargetPlatformVariant.desktop(),
    );
  });

  group('shortcuts', () {
    testWidgets('Ctrl+Tab cycles windows and Ctrl+F4 closes the active one',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry a = _open(controller, 'A');
      final WindowEntry b = _open(controller, 'B');
      final WindowEntry c = _open(controller, 'C');
      await tester.pumpAndSettle();
      expect(controller.activeWindow, c);

      await _pressControlWith(tester, LogicalKeyboardKey.tab);
      expect(controller.activeWindow, a);
      await _pressControlWith(tester, LogicalKeyboardKey.tab, shift: true);
      expect(controller.activeWindow, c);

      await _pressControlWith(tester, LogicalKeyboardKey.f4);
      expect(c.isClosed, isTrue);
      expect(a.isClosed, isFalse);
      expect(controller.activeWindow, a,
          reason: 'a was used more recently than b');
      expect(b.isActive, isFalse);
    });

    testWidgets('custom shortcuts replace the defaults',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(
        tester,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyM, control: true):
              MinimizeWindowIntent(),
        },
      );
      final WindowEntry a = _open(controller, 'A');
      final WindowEntry b = _open(controller, 'B');
      await tester.pumpAndSettle();

      await _pressControlWith(tester, LogicalKeyboardKey.tab);
      expect(controller.activeWindow, b, reason: 'Ctrl+Tab is no longer bound');

      await _pressControlWith(tester, LogicalKeyboardKey.keyM);
      expect(b.isMinimized, isTrue);
      expect(controller.activeWindow, a);
    });
  });

  group('window dialogs', () {
    Widget askButton(ValueSetter<bool?> onResult, {bool dismissible = true}) {
      return Builder(
        builder: (BuildContext context) => ElevatedButton(
          onPressed: () async {
            onResult(
              await showWindowDialog<bool>(
                context: context,
                barrierDismissible: dismissible,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Sure?'),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              ),
            );
          },
          child: const Text('Ask'),
        ),
      );
    }

    testWidgets('Navigator.pop closes the dialog with a result',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      bool? result;
      bool answered = false;
      final WindowEntry window = _open(
        controller,
        'A',
        builder: (BuildContext context) => Center(
          child: askButton((bool? value) {
            result = value;
            answered = true;
          }),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);
      expect(window.dialogCount, 1);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(answered, isTrue);
      expect(result, isTrue);
      expect(find.text('Sure?'), findsNothing);
      expect(find.byType(WindowStack), findsOneWidget,
          reason: 'the page is not popped');
    });

    testWidgets('a window dialog blocks only its own window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(0, 0, 450, 400),
        builder: (BuildContext context) => Column(
          children: <Widget>[
            askButton((_) {}),
            const Expanded(child: _TapCounter(label: 'A')),
          ],
        ),
      );
      _open(
        controller,
        'B',
        bounds: const Rect.fromLTWH(500, 0, 400, 300),
        builder: (BuildContext context) => const _TapCounter(label: 'B'),
      );
      await tester.pump();
      await tester.tap(_titleOf('A'));
      await _settle(tester);
      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();

      // A's counter fills the window's body. Tapping it outside the dialog
      // hits the barrier instead, which dismisses the dialog.
      await tester.tapAt(const Offset(30, 370));
      await tester.pumpAndSettle();
      expect(find.text('A: 0'), findsOneWidget);
      expect(find.text('Sure?'), findsNothing,
          reason: 'the barrier dismissed the dialog');

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('B: 0'));
      await tester.pumpAndSettle();
      expect(find.text('B: 1'), findsOneWidget,
          reason: 'other windows stay usable');
      expect(find.text('Sure?'), findsOneWidget);
    });

    testWidgets('Escape and the barrier dismiss with null',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final List<bool?> results = <bool?>[];
      _open(controller, 'A',
          builder: (BuildContext context) =>
              Center(child: askButton(results.add)));
      await tester.pump();

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsNothing);

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(110, 150));
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsNothing);
      expect(results, <bool?>[null, null]);
    });

    testWidgets('a non-dismissible dialog ignores Escape and the barrier',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final List<bool?> results = <bool?>[];
      _open(
        controller,
        'A',
        builder: (BuildContext context) =>
            Center(child: askButton(results.add, dismissible: false)),
      );
      await tester.pump();

      await tester.tap(find.text('Ask'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.tapAt(const Offset(110, 150));
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(results, <bool?>[true]);
    });

    testWidgets('dialogs stack and focus returns to the dialog below',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final FocusNode firstField = FocusNode();
      addTearDown(firstField.dispose);
      final WindowEntry window = _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(50, 50, 700, 550),
        builder: (BuildContext context) => const SizedBox.expand(),
      );
      await tester.pump();

      unawaited(
        window.showDialog<void>(
          builder: (BuildContext context) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                    width: 200,
                    child: TextField(focusNode: firstField, autofocus: true)),
                TextButton(
                  onPressed: () => showWindowDialog<void>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Second'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('More'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(firstField.hasFocus, isTrue);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(window.dialogCount, 2);
      expect(firstField.hasFocus, isFalse);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(window.dialogCount, 1);
      expect(find.text('Second'), findsNothing);
      expect(firstField.hasFocus, isTrue);
    });
    testWidgets('a dialog returns focus only within its own window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final FocusNode fieldA = FocusNode();
      final FocusNode fieldB = FocusNode();
      addTearDown(fieldA.dispose);
      addTearDown(fieldB.dispose);
      final WindowEntry a = _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(0, 0, 450, 400),
        builder: (BuildContext context) => Align(
          alignment: Alignment.topCenter,
          child: TextField(key: const Key('fieldA'), focusNode: fieldA),
        ),
      );
      _open(
        controller,
        'B',
        bounds: const Rect.fromLTWH(500, 0, 400, 300),
        builder: (BuildContext context) =>
            TextField(key: const Key('fieldB'), focusNode: fieldB),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('fieldA')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('fieldB')));
      await tester.pump();
      expect(fieldB.hasFocus, isTrue);

      // A dialog opened on the inactive window A does not take focus from B.
      unawaited(
        a.showDialog<void>(
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Later'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fieldB.hasFocus, isTrue);

      await tester.tap(_titleOf('A'));
      await _settle(tester);
      expect(fieldB.hasFocus, isFalse);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(controller.activeWindow, a);
      expect(fieldA.hasFocus, isTrue, reason: 'focus stays in window A');
    });

    testWidgets(
        'an autofocus field in a background dialog waits for its window',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final FocusNode fieldB = FocusNode();
      final FocusNode dialogField = FocusNode();
      addTearDown(fieldB.dispose);
      addTearDown(dialogField.dispose);
      final WindowEntry a = _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(0, 0, 450, 400),
      );
      _open(
        controller,
        'B',
        bounds: const Rect.fromLTWH(500, 0, 400, 300),
        builder: (BuildContext context) => TextField(focusNode: fieldB),
      );
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();

      unawaited(
        a.showDialog<void>(
          builder: (BuildContext context) => Dialog(
            child: SizedBox(
              width: 200,
              child: TextField(focusNode: dialogField, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fieldB.hasFocus, isTrue);
      expect(dialogField.hasFocus, isFalse);

      a.activate();
      await tester.pumpAndSettle();
      expect(dialogField.hasFocus, isTrue);
    });
  });

  group('stack dialogs', () {
    testWidgets('a stack dialog blocks every window and the shortcuts',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry a = _open(
        controller,
        'A',
        builder: (BuildContext context) => const _TapCounter(label: 'A'),
      );
      await tester.pump();

      String? result;
      unawaited(controller
          .showDialog<String>(
            barrierDismissible: false,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('About'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(context, 'ok'),
                  child: const Text('OK'),
                ),
              ],
            ),
          )
          .then((String? value) => result = value));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.text('A: 0')));
      await tester.pumpAndSettle();
      expect(find.text('A: 0'), findsOneWidget);

      await _pressControlWith(tester, LogicalKeyboardKey.f4);
      expect(a.isClosed, isFalse);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, 'ok');
      expect(controller.hasDialogs, isFalse);

      await tester.tap(find.text('A: 0'));
      await tester.pump();
      expect(find.text('A: 1'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('windows fit a shrinking stack and spring back',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      final WindowEntry window = _open(
        controller,
        'A',
        bounds: const Rect.fromLTWH(600, 400, 300, 200),
      );
      await tester.pump();

      tester.view.physicalSize = const Size(700, 500);
      await tester.pump();
      expect(window.bounds, const Rect.fromLTWH(400, 300, 300, 200));
      expect(tester.getRect(_frameOf('A')),
          const Rect.fromLTWH(400, 300, 300, 200));

      tester.view.physicalSize = _surface;
      await tester.pump();
      expect(window.bounds, const Rect.fromLTWH(600, 400, 300, 200));
    });

    testWidgets('a maximized window follows the stack size',
        (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(tester);
      _open(controller, 'A').maximize();
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();
      expect(
          tester.getRect(_frameOf('A')), const Rect.fromLTWH(0, 0, 800, 600));
    });
  });

  group('theme', () {
    testWidgets('reads the ThemeData extension and lets the widget override it',
        (WidgetTester tester) async {
      WindowStackController controller = await _pumpStack(
        tester,
        appTheme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            WindowStackThemeData(titleBarHeight: 50),
          ],
        ),
      );
      _open(controller, 'A');
      await tester.pump();
      expect(tester.getSize(find.byType(WindowTitleBar)).height, 50);

      controller = await _pumpStack(
        tester,
        theme: const WindowStackThemeData(titleBarHeight: 44),
        appTheme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            WindowStackThemeData(titleBarHeight: 50),
          ],
        ),
      );
      _open(controller, 'B');
      await tester.pump();
      expect(tester.getSize(find.byType(WindowTitleBar)).height, 44);
    });

    testWidgets('Windows-style controls work', (WidgetTester tester) async {
      final WindowStackController controller = await _pumpStack(
        tester,
        theme: const WindowStackThemeData(
            controlsStyle: WindowControlsStyle.windows),
      );
      final WindowEntry window = _open(controller, 'A');
      await tester.pump();

      final Rect close = tester.getRect(_buttonOf('A', 'Close'));
      expect(close.right, 500, reason: 'the buttons sit at the trailing edge');

      await tester.tap(_buttonOf('A', 'Maximize'));
      await tester.pumpAndSettle();
      expect(window.isMaximized, isTrue);
      expect(_buttonOf('A', 'Restore'), findsOneWidget);

      await tester.tap(_buttonOf('A', 'Close'));
      await tester.pumpAndSettle();
      expect(window.isClosed, isTrue);
    });

    testWidgets('lerp blends two themes', (WidgetTester tester) async {
      const WindowStackThemeData a =
          WindowStackThemeData(titleBarHeight: 30, dockSpacing: 0);
      const WindowStackThemeData b =
          WindowStackThemeData(titleBarHeight: 50, dockSpacing: 20);
      final WindowStackThemeData mid = a.lerp(b, 0.5);
      expect(mid.titleBarHeight, 40);
      expect(mid.dockSpacing, 10);
      expect(a.copyWith(titleBarHeight: 31).titleBarHeight, 31);
      expect(a, const WindowStackThemeData(titleBarHeight: 30, dockSpacing: 0));
    });
  });
}
