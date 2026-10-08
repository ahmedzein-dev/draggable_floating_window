import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_stack/window_stack.dart';

Widget _content(BuildContext context) => const SizedBox();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WindowStackController controller;

  setUp(() => controller = WindowStackController());
  tearDown(() => controller.dispose());

  WindowEntry open(String id, {int priority = WindowPriority.normal}) {
    return controller.open(
      id: id,
      title: id,
      builder: _content,
      priority: priority,
    );
  }

  List<String> stackingOrder() =>
      controller.windows.map((WindowEntry window) => window.id).toList();

  group('stacking order', () {
    test('new windows open on top and become active', () {
      open('a');
      open('b');
      final WindowEntry c = open('c');
      expect(stackingOrder(), <String>['a', 'b', 'c']);
      expect(controller.activeWindow, c);
      expect(c.isActive, isTrue);
    });

    test('activating a window brings it to the top', () {
      final WindowEntry a = open('a');
      open('b');
      open('c');
      a.activate();
      expect(stackingOrder(), <String>['b', 'c', 'a']);
      expect(controller.activeWindow, a);
    });

    test('a higher priority always stays above a lower one', () {
      final WindowEntry a = open('a');
      open('tool', priority: WindowPriority.high);
      final WindowEntry b = open('b');
      expect(stackingOrder(), <String>['a', 'b', 'tool']);

      a.activate();
      expect(stackingOrder(), <String>['b', 'a', 'tool']);
      expect(controller.activeWindow, a);

      open('background', priority: WindowPriority.low);
      expect(stackingOrder(), <String>['background', 'b', 'a', 'tool']);

      b.activate();
      expect(stackingOrder(), <String>['background', 'a', 'b', 'tool']);
    });

    test('changing the priority re-sorts the stack', () {
      final WindowEntry a = open('a');
      open('b');
      a.priority = WindowPriority.high;
      expect(stackingOrder(), <String>['b', 'a']);
      a.priority = WindowPriority.normal;
      expect(stackingOrder(), <String>['a', 'b']);
    });

    test('opening an existing id activates that window instead', () {
      final WindowEntry a = open('a');
      open('b');
      final WindowEntry again = open('a');
      expect(again, same(a));
      expect(controller.windows, hasLength(2));
      expect(stackingOrder(), <String>['b', 'a']);
    });

    test('generated ids are unique', () {
      final WindowEntry first = controller.open(builder: _content);
      final WindowEntry second = controller.open(builder: _content);
      expect(first.id, isNot(second.id));
    });
  });

  group('activation', () {
    test('closing the active window activates the most recently used one', () {
      final WindowEntry a = open('a');
      final WindowEntry b = open('b');
      final WindowEntry c = open('c');
      a.activate();
      b.activate();
      expect(controller.activeWindow, b);

      b.close();
      expect(controller.activeWindow, a);
      expect(c.isActive, isFalse);
    });

    test('minimizing the active window activates the next visible one', () {
      final WindowEntry a = open('a');
      final WindowEntry b = open('b');
      b.minimize();
      expect(b.isMinimized, isTrue);
      expect(controller.activeWindow, a);

      a.minimize();
      expect(controller.activeWindow, isNull);
    });

    test('activating a minimized window restores it', () {
      open('a');
      final WindowEntry b = open('b');
      b.minimize();
      b.activate();
      expect(b.mode, WindowMode.normal);
      expect(controller.activeWindow, b);
    });

    test('restoring returns a minimized window to its previous mode', () {
      final WindowEntry a = open('a');
      a.maximize();
      a.minimize();
      expect(a.isMinimized, isTrue);
      a.restore();
      expect(a.isMaximized, isTrue);
      a.restore();
      expect(a.mode, WindowMode.normal);
    });

    test('activateNext and activatePrevious cycle in opening order', () {
      final WindowEntry a = open('a');
      final WindowEntry b = open('b');
      final WindowEntry c = open('c');
      b.minimize();
      expect(controller.activeWindow, c);

      // b is minimized, so the cycle is a, c.
      expect(controller.activateNext(), isTrue);
      expect(controller.activeWindow, a);
      expect(controller.activateNext(), isTrue);
      expect(controller.activeWindow, c);
      expect(controller.activatePrevious(), isTrue);
      expect(controller.activeWindow, a);
    });

    test('activateNext does nothing when every window is minimized', () {
      open('a').minimize();
      expect(controller.activateNext(), isFalse);
    });
  });

  group('closing', () {
    test('onCloseRequest can keep a window open', () async {
      bool allow = false;
      int closed = 0;
      final WindowEntry a = controller.open(
        builder: _content,
        onCloseRequest: () => allow,
        onClosed: () => closed++,
      );

      expect(await a.close(), isFalse);
      expect(a.isClosed, isFalse);
      expect(closed, 0);

      allow = true;
      expect(await a.close(), isTrue);
      expect(a.isClosed, isTrue);
      expect(closed, 1);
      expect(controller.windows, isEmpty);
    });

    test('force skips onCloseRequest', () async {
      final WindowEntry a = controller.open(
        builder: _content,
        onCloseRequest: () => false,
      );
      expect(await a.close(force: true), isTrue);
      expect(a.isClosed, isTrue);
    });

    test('closeAll asks every window', () async {
      open('a');
      controller.open(
          id: 'keep', builder: _content, onCloseRequest: () => false);
      open('b');
      await controller.closeAll();
      expect(stackingOrder(), <String>['keep']);
      await controller.closeAll(force: true);
      expect(controller.windows, isEmpty);
    });

    test('a closed window ignores further calls', () async {
      final WindowEntry a = open('a');
      await a.close();
      a
        ..maximize()
        ..minimize()
        ..title = 'changed';
      expect(a.mode, WindowMode.normal);
      expect(a.title, 'a');
      expect(await a.showDialog<int>(builder: _content), isNull);
    });
  });

  group('dialog stacks', () {
    test('window dialogs pop in last-in, first-out order', () async {
      final WindowEntry a = open('a');
      final Future<String?> first = a.showDialog<String>(builder: _content);
      final Future<String?> second = a.showDialog<String>(builder: _content);
      expect(a.dialogCount, 2);

      expect(a.popDialog('top'), isTrue);
      expect(await second, 'top');
      expect(a.dialogCount, 1);

      expect(a.popDialog('bottom'), isTrue);
      expect(await first, 'bottom');
      expect(a.hasDialogs, isFalse);
      expect(a.popDialog(), isFalse);
    });

    test('window dialogs are independent per window', () async {
      final WindowEntry a = open('a');
      final WindowEntry b = open('b');
      final Future<int?> onA = a.showDialog<int>(builder: _content);
      unawaited(b.showDialog<int>(builder: _content));

      a.popDialog(1);
      expect(await onA, 1);
      expect(a.hasDialogs, isFalse);
      expect(b.dialogCount, 1);
    });

    test('closing a window completes its dialogs with null', () async {
      final WindowEntry a = open('a');
      final Future<bool?> dialog = a.showDialog<bool>(builder: _content);
      await a.close();
      expect(await dialog, isNull);
    });

    test('stack dialogs pop in last-in, first-out order', () async {
      final Future<int?> first = controller.showDialog<int>(builder: _content);
      final Future<int?> second = controller.showDialog<int>(
        builder: _content,
      );
      expect(controller.hasDialogs, isTrue);
      expect(controller.dialogCount, 2);

      controller.popDialog(2);
      controller.popDialog(1);
      expect(await second, 2);
      expect(await first, 1);
      expect(controller.hasDialogs, isFalse);
    });
  });

  group('notifications', () {
    test('the controller notifies on structural changes', () {
      int notifications = 0;
      controller.addListener(() => notifications++);
      final WindowEntry a = open('a');
      expect(notifications, 1);
      open('b');
      a.activate();
      a.minimize();
      a.restore();
      a.title = 'renamed';
      expect(notifications, 6);
    });

    test('entries notify their own listeners', () {
      final WindowEntry a = open('a');
      int notifications = 0;
      a.addListener(() => notifications++);
      a.setBounds(const Rect.fromLTWH(10, 10, 300, 200));
      a.title = 'renamed';
      a.maximize();
      expect(notifications, greaterThanOrEqualTo(3));
      expect(a.bounds, const Rect.fromLTWH(10, 10, 300, 200));
    });
  });
}
