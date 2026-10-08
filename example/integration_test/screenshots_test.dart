// Saves the screenshots used in the package README and on pub.dev:
//
//   flutter test integration_test/screenshots_test.dart -d macos
//
// The PNG files go to a `window_stack_screenshots` folder in the app's
// temporary directory; the test prints the path. The app is laid out at
// 1280x800 and scaled to fit the window, so the size of the macOS window does
// not matter.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_stack/window_stack.dart';
import 'package:window_stack_example/desktop/desktop_background.dart';
import 'package:window_stack_example/main.dart';
import 'package:window_stack_example/windows/notes_window.dart';

const Size _canvas = Size(1280, 800);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saves the screenshots', (WidgetTester tester) async {
    final Directory folder = Directory(
      '${Directory.systemTemp.path}/window_stack_screenshots',
    )..createSync(recursive: true);
    debugPrint('WINDOW_STACK_SCREENSHOTS=${folder.path}');
    final GlobalKey boundary = GlobalKey();

    await tester.pumpWidget(
      FittedBox(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: _canvas,
          child: RepaintBoundary(
            key: boundary,
            child: Builder(
              builder: (BuildContext context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: _canvas),
                child: const ExampleApp(openWelcomeWindow: false),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final WindowStackController windows = WindowStack.of(
      tester.element(find.byType(DesktopBackground)),
    );

    Future<void> tap(Finder finder) async {
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
    }

    Future<void> save(String name) async {
      await tester.pump(const Duration(milliseconds: 400));
      final RenderRepaintBoundary box =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await box.toImage(pixelRatio: 2);
      final ByteData? png = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      image.dispose();
      File('${folder.path}/$name.png').writeAsBytesSync(
        png!.buffer.asUint8List(),
      );
    }

    WindowEntry note() => windows.windows.firstWhere(
          (WindowEntry window) => window.title.startsWith('Note'),
        );

    // Overview: several window types, the active one in front and the
    // calculator above it.
    await tap(find.text('New note'));
    await tester.enterText(
      find.descendant(
        of: find.byType(NotesWindow),
        matching: find.byType(TextField),
      ),
      'Q3 report\n\n• Send the draft to finance on Thursday\n'
      '• Ask Dana for the updated forecast\n• Book the review meeting',
    );
    await tap(find.text('Activity'));
    await tap(find.text('Calculator'));
    await tap(find.text('Tasks'));
    windows.windowById('activity')!.moveTo(const Offset(850, 300));
    windows.windowById('calculator')!.moveTo(const Offset(965, 24));
    note().moveTo(const Offset(450, 60));
    windows.windowById('tasks')!.moveTo(const Offset(120, 230));
    await tester.pumpAndSettle();
    windows.windowById('tasks')!.activate();
    await tester.pumpAndSettle();
    await save('overview');

    // A dialog stack inside the Tasks window.
    await tap(find.text('Clear completed'));
    await tap(find.text('Review'));
    await save('dialog_stack');
    await tap(find.text('Back'));
    await tap(find.text('Cancel'));

    // Light theme, Windows-style buttons, the dock, and a dropdown menu that
    // opens above the windows.
    await tap(find.text('Settings'));
    windows.windowById('settings')!.moveTo(const Offset(400, 120));
    await tester.pumpAndSettle();
    await tap(find.text('Light'));
    await tap(find.text('Windows'));
    note().minimize();
    windows.windowById('activity')!.minimize();
    await tester.pumpAndSettle();
    await tap(find.byType(DropdownButton<Color>));
    await save('light_windows_style');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });
}
