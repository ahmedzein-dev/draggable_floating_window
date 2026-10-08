import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_stack/window_stack.dart';
import 'package:window_stack_example/main.dart';

void main() {
  testWidgets('opens windows from the desktop and stacks dialogs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();
    expect(find.text('A desktop inside your Flutter app'), findsOneWidget);

    await tester.tap(find.text('Tasks').first);
    await tester.pumpAndSettle();
    expect(find.text('Review the pull request'), findsOneWidget);

    await tester.tap(find.text('Clear completed'));
    await tester.pumpAndSettle();
    expect(find.text('Clear 3 completed tasks?'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Completed tasks'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Review the pull request'), findsNothing);
    expect(find.text('0 of 2 done'), findsOneWidget);
  });

  testWidgets('the calculator stays above an active note', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp(openWelcomeWindow: false));
    await tester.tap(find.text('Calculator'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    // Any widget inside the stack can reach its controller.
    final WindowStackController controller = WindowStack.of(
      tester.element(find.byType(WindowTitleBar).first),
    );
    expect(controller.activeWindow?.title, 'Note 1');
    expect(controller.windows.last.title, 'Calculator');
  });
}
