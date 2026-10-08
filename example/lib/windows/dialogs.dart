import 'package:flutter/material.dart';
import 'package:draggable_floating_window/draggable_floating_window.dart';

/// Asked by a note window before it closes with unsaved changes.
class DiscardChangesDialog extends StatelessWidget {
  const DiscardChangesDialog({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls instead of overflowing when its window is small.
      scrollable: true,
      icon: const Icon(Icons.edit_note_rounded),
      title: const Text('Discard changes?'),
      content: Text('$name has unsaved changes.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Discard'),
        ),
      ],
    );
  }
}

/// The first dialog of the Tasks window's dialog stack.
class ClearCompletedDialog extends StatelessWidget {
  const ClearCompletedDialog({super.key, required this.completed});

  final List<String> completed;

  @override
  Widget build(BuildContext context) {
    final int count = completed.length;
    return AlertDialog(
      // Scrolls instead of overflowing when its window is small.
      scrollable: true,
      // Sits a little high, so the dialog stacked on top of it leaves its
      // title visible.
      alignment: const Alignment(0, -0.6),
      title: Text('Clear $count completed ${count == 1 ? 'task' : 'tasks'}?'),
      content: const Text('Cleared tasks cannot be brought back.'),
      actions: <Widget>[
        TextButton(
          // Opens a second dialog on top of this one, in the same window.
          // Closing it returns here.
          onPressed: () => showWindowDialog<void>(
            context: context,
            builder: (BuildContext context) =>
                CompletedTasksDialog(completed: completed),
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
    );
  }
}

/// The second dialog of the Tasks window's dialog stack.
class CompletedTasksDialog extends StatelessWidget {
  const CompletedTasksDialog({super.key, required this.completed});

  final List<String> completed;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls instead of overflowing when its window is small.
      scrollable: true,
      alignment: const Alignment(0, 0.9),
      title: const Text('Completed tasks'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String task in completed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_outline, size: 18),
                  const SizedBox(width: 8),
                  Flexible(child: Text(task)),
                ],
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back'),
        ),
      ],
    );
  }
}

/// Shown above every window by the menu bar's About item.
class AboutWorkspaceDialog extends StatelessWidget {
  const AboutWorkspaceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls instead of overflowing when its window is small.
      scrollable: true,
      icon: const Icon(Icons.dashboard_customize_outlined),
      title: const Text('Workspace'),
      content: const SizedBox(
        width: 340,
        child: Text(
          'An example desktop built with the draggable_floating_window '
          'package. This is a stack-level dialog: every window is blocked '
          'until it closes. '
          'Window dialogs, like the ones in Tasks and Notes, block only their '
          'own window.',
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

/// Confirms closing every window.
class CloseAllDialog extends StatelessWidget {
  const CloseAllDialog({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Scrolls instead of overflowing when its window is small.
      scrollable: true,
      title: Text('Close $count ${count == 1 ? 'window' : 'windows'}?'),
      content: const Text('Notes with unsaved changes will still ask.'),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Close all'),
        ),
      ],
    );
  }
}
