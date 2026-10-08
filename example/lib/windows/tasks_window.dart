import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

import 'dialogs.dart';

/// A checklist. "Clear completed" opens a window dialog, and its "Review"
/// button opens a second dialog on top of it: a dialog stack inside one
/// window.
class TasksWindow extends StatefulWidget {
  const TasksWindow({super.key});

  @override
  State<TasksWindow> createState() => _TasksWindowState();
}

class _Task {
  _Task(this.title, {this.done = false});

  final String title;
  bool done;
}

class _TasksWindowState extends State<TasksWindow> {
  final TextEditingController _newTask = TextEditingController();
  final FocusNode _newTaskFocus = FocusNode();
  final List<_Task> _tasks = <_Task>[
    _Task('Review the pull request', done: true),
    _Task('Reply to the support ticket'),
    _Task('Prepare the release notes', done: true),
    _Task('Book the meeting room'),
    _Task('Update the roadmap', done: true),
  ];

  @override
  void dispose() {
    _newTask.dispose();
    _newTaskFocus.dispose();
    super.dispose();
  }

  void _add() {
    final String title = _newTask.text.trim();
    if (title.isEmpty) {
      return;
    }
    setState(() => _tasks.add(_Task(title)));
    _newTask.clear();
    _newTaskFocus.requestFocus();
  }

  Future<void> _clearCompleted() async {
    final List<String> completed = <String>[
      for (final _Task task in _tasks)
        if (task.done) task.title,
    ];
    if (completed.isEmpty) {
      return;
    }
    // Blocks this window only. The dialog closes with Navigator.pop, exactly
    // like a dialog shown with Flutter's showDialog.
    final bool? clear = await showWindowDialog<bool>(
      context: context,
      builder: (BuildContext context) =>
          ClearCompletedDialog(completed: completed),
    );
    if ((clear ?? false) && mounted) {
      setState(() => _tasks.removeWhere((_Task task) => task.done));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int done = _tasks.where((_Task task) => task.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _newTask,
                  focusNode: _newTaskFocus,
                  onSubmitted: (_) => _add(),
                  decoration: const InputDecoration(
                    hintText: 'Add a task',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Add task',
                onPressed: _add,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: <Widget>[
              for (final _Task task in _tasks)
                CheckboxListTile(
                  dense: true,
                  value: task.done,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (bool? value) =>
                      setState(() => task.done = value ?? false),
                  title: Text(
                    task.title,
                    style: task.done
                        ? TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: colors.onSurfaceVariant,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$done of ${_tasks.length} done',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              TextButton.icon(
                onPressed: done == 0 ? null : _clearCompleted,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('Clear completed'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
