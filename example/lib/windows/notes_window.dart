import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

/// The data behind one note window, shared with its close confirmation.
class NoteDocument {
  NoteDocument({required this.name, this.text = ''});

  final String name;
  String text;
  bool isDirty = false;
}

/// A plain text editor. The window title gets a dot while there are unsaved
/// changes, and closing asks first (see `WindowLauncher.openNote`).
class NotesWindow extends StatefulWidget {
  const NotesWindow({super.key, required this.note});

  final NoteDocument note;

  @override
  State<NotesWindow> createState() => _NotesWindowState();
}

class _NotesWindowState extends State<NotesWindow> {
  late final TextEditingController _text = TextEditingController(
    text: widget.note.text,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => widget.note.text = value);
    _setDirty(true);
  }

  void _save() {
    _setDirty(false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('${widget.note.name} saved'),
        behavior: SnackBarBehavior.floating,
        width: 240,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _setDirty(bool dirty) {
    if (widget.note.isDirty == dirty) {
      return;
    }
    setState(() => widget.note.isDirty = dirty);
    // The window's title is mutable: show unsaved changes in the title bar
    // and in the dock.
    WindowEntry.of(context).title =
        dirty ? '${widget.note.name} •' : widget.note.name;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int words = RegExp(r'\S+').allMatches(_text.text).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _text,
              autofocus: true,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Start typing…',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$words ${words == 1 ? 'word' : 'words'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              if (widget.note.isDirty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Unsaved',
                    style: TextStyle(color: colors.tertiary),
                  ),
                ),
              FilledButton.tonal(
                onPressed: widget.note.isDirty ? _save : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
