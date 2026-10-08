part of '../core.dart';

class _EntryNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// One open window of a [WindowStack].
///
/// Entries are created by [WindowStackController.open] and live until the
/// window closes. Use an entry to read the window's state and to drive it from
/// code:
///
/// ```dart
/// final WindowEntry notes = controller.open(
///   title: 'Notes',
///   builder: (context) => const NotesEditor(),
/// );
///
/// notes.title = 'Notes (unsaved)';
/// notes.maximize();
/// final bool? discard = await notes.showDialog<bool>(
///   builder: (context) => const DiscardChangesDialog(),
/// );
/// ```
///
/// Inside the window's content, [WindowEntry.of] returns the entry of the
/// enclosing window:
///
/// ```dart
/// TextButton(
///   onPressed: () => WindowEntry.of(context).close(),
///   child: const Text('Done'),
/// )
/// ```
///
/// An entry is a [Listenable] that notifies when anything about the window
/// changes, including every step of a drag. After the window closes,
/// [isClosed] is true, methods do nothing and listeners can no longer be
/// added.
class WindowEntry implements Listenable {
  WindowEntry._({
    required this.controller,
    required this.id,
    required this.builder,
    required String title,
    required Widget? icon,
    required int priority,
    required this.minSize,
    required this.maxSize,
    required this.resizable,
    required this.draggable,
    required this.minimizable,
    required this.maximizable,
    required this.closable,
    required this.titleBarBuilder,
    required this.onCloseRequest,
    required this.onClosed,
    required Size? requestedSize,
    required Offset? requestedPosition,
  })  : _title = title,
        _icon = icon,
        _priority = priority,
        _requestedSize = requestedSize,
        _requestedPosition = requestedPosition;

  /// The controller that opened this window.
  final WindowStackController controller;

  /// Identifies the window. Either the id passed to
  /// [WindowStackController.open] or a generated one.
  final String id;

  /// Builds the window's content.
  final WidgetBuilder builder;

  /// The smallest size the user can resize the window to.
  final Size minSize;

  /// The largest size the user can resize the window to, or null for no limit
  /// other than the stack itself.
  final Size? maxSize;

  /// Whether the user can resize the window by dragging its edges.
  final bool resizable;

  /// Whether the user can move the window by dragging its title bar.
  final bool draggable;

  /// Whether the window shows a minimize button and responds to
  /// [MinimizeWindowIntent]. [minimize] does nothing when this is false.
  final bool minimizable;

  /// Whether the window shows a maximize button, maximizes on a title bar
  /// double-click and responds to [ToggleMaximizeWindowIntent]. [maximize]
  /// does nothing when this is false.
  final bool maximizable;

  /// Whether the window shows a close button and responds to
  /// [CloseWindowIntent]. [close] still works when this is false.
  final bool closable;

  /// Builds this window's title bar instead of [WindowStack.titleBarBuilder].
  final WindowTitleBarBuilder? titleBarBuilder;

  /// Called before the window closes, unless it is closed with
  /// `close(force: true)`. Return `false` to keep the window open.
  final WindowCloseRequestCallback? onCloseRequest;

  /// Called after the window has closed.
  final VoidCallback? onClosed;

  final _EntryNotifier _changes = _EntryNotifier();
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'WindowEntry content');

  /// The focus scope that holds the window's content.
  ///
  /// It remembers the last focused widget, so activating the window returns
  /// keyboard focus to where the user left off. Owned by the window; do not
  /// dispose it.
  late final FocusScopeNode focusScopeNode = FocusScopeNode(
    debugLabel: 'WindowEntry($id)',
  );

  late final _DialogStack _dialogs = _DialogStack(
    onChanged: _notify,
    canTakeFocus: () => isActive && !controller.hasDialogs,
    focusFallback: () {
      if (isActive && !controller.hasDialogs) {
        _requestFocus();
      }
    },
    ownsFocus: (FocusNode node) =>
        node == focusScopeNode || node.ancestors.contains(focusScopeNode),
  );

  String _title;
  Widget? _icon;
  int _priority;
  WindowMode _mode = WindowMode.normal;
  WindowMode _modeBeforeMinimize = WindowMode.normal;
  Rect _bounds = Rect.zero;
  bool _placed = false;
  Size? _requestedSize;
  Offset? _requestedPosition;
  int _activationOrder = 0;
  int? _dockSlot;
  bool _closed = false;
  bool _closeRequestPending = false;
  bool _animateBounds = false;
  bool _disposed = false;
  bool _focusRequestPending = false;

  /// The widget that had focus when the window was last deactivated or
  /// minimized. Restored on activation.
  FocusNode? _lastFocus;

  // Pointer interaction state, in the stack's coordinate space.
  Offset? _interactionStart;
  Rect? _interactionStartBounds;
  ResizeEdge? _resizeEdge;

  /// The title shown in the title bar, in the dock and to screen readers.
  String get title => _title;
  set title(String value) {
    if (value == _title || _closed) {
      return;
    }
    _title = value;
    _notify();
    controller._notifyIfAlive();
  }

  /// An optional widget shown before the title, such as an [Icon].
  Widget? get icon => _icon;
  set icon(Widget? value) {
    if (value == _icon || _closed) {
      return;
    }
    _icon = value;
    _notify();
    controller._notifyIfAlive();
  }

  /// The stacking priority. Windows with a higher priority always stay above
  /// windows with a lower one. See [WindowPriority].
  ///
  /// Changing it re-sorts the stack immediately, so it can implement a
  /// "keep on top" toggle.
  int get priority => _priority;
  set priority(int value) {
    if (value == _priority || _closed) {
      return;
    }
    _priority = value;
    _notify();
    controller._onPriorityChanged();
  }

  /// How the window is currently displayed.
  WindowMode get mode => _mode;

  /// Whether the window is minimized to the dock.
  bool get isMinimized => _mode == WindowMode.minimized;

  /// Whether the window fills the stack.
  bool get isMaximized => _mode == WindowMode.maximized;

  /// Whether this is the [WindowStackController.activeWindow].
  bool get isActive => controller._activeWindow == this;

  /// Whether the window has closed. A closed window ignores every method.
  bool get isClosed => _closed;

  /// The window's position and size in normal mode, in the stack's
  /// coordinate space.
  ///
  /// While the window is maximized or minimized, this is where it returns to
  /// on [restore]. When the stack is smaller than the window's last position
  /// allows, the window is drawn moved and shrunk to fit and this returns that
  /// fitted rectangle; it springs back once the stack is large enough again.
  /// [Rect.zero] until the window has been laid out for the first time.
  Rect get bounds {
    if (!_placed) {
      return Rect.zero;
    }
    return _displayBounds(controller.size);
  }

  /// Whether a window dialog is open on this window.
  bool get hasDialogs => _dialogs.isNotEmpty;

  /// The number of window dialogs open on this window.
  int get dialogCount => _dialogs.length;

  /// Makes this the active window. See [WindowStackController.activate].
  void activate() => controller.activate(this);

  /// Closes the window.
  ///
  /// Unless [force] is true, [onCloseRequest] runs first and can keep the
  /// window open. Dialogs still open on the window complete with null.
  /// Returns whether the window is closed afterwards.
  Future<bool> close({bool force = false}) {
    return controller._close(this, force: force);
  }

  /// Minimizes the window to the dock and activates the most recently used
  /// window that is still visible.
  ///
  /// Does nothing when [minimizable] is false.
  void minimize() => controller._minimize(this);

  /// Makes the window fill the stack and activates it.
  ///
  /// Does nothing when [maximizable] is false.
  void maximize() => controller._maximize(this);

  /// Returns a minimized window to the mode it had before, or a maximized
  /// window to [bounds], and activates it.
  void restore() => controller._restore(this);

  /// Restores the window if it is maximized, otherwise maximizes it.
  void toggleMaximize() => isMaximized ? restore() : maximize();

  /// Moves the window so its top-left corner is at [position], keeping its
  /// size. See [setBounds].
  void moveTo(Offset position, {bool animate = false}) {
    if (!_placed) {
      _requestedPosition = position;
      return;
    }
    setBounds(position & _bounds.size, animate: animate);
  }

  /// Resizes the window, keeping its top-left corner. The size is clamped to
  /// [minSize] and [maxSize]. See [setBounds].
  void resizeTo(Size size, {bool animate = false}) {
    if (!_placed) {
      _requestedSize = size;
      return;
    }
    setBounds(_bounds.topLeft & size, animate: animate);
  }

  /// Sets the window's position and size in normal mode.
  ///
  /// The rectangle is clamped to [minSize] and [maxSize] and moved inside the
  /// stack. When the window is maximized or minimized, it sets where the
  /// window returns to on [restore]. With [animate], a window in normal mode
  /// glides to its new bounds.
  void setBounds(Rect bounds, {bool animate = false}) {
    if (_closed) {
      return;
    }
    final Size size = Size(
      bounds.width.clamp(minSize.width, maxSize?.width ?? double.infinity),
      bounds.height.clamp(minSize.height, maxSize?.height ?? double.infinity),
    );
    Rect rect = bounds.topLeft & size;
    if (controller._hasLayout) {
      rect = fitRectInBounds(rect, controller._area);
    }
    _bounds = rect;
    _placed = true;
    _requestedSize = null;
    _requestedPosition = null;
    _animateBounds = animate && _mode == WindowMode.normal;
    _notify();
  }

  /// Shows a dialog over this window's content and returns the value it is
  /// closed with.
  ///
  /// The dialog is modal to this window only: its content cannot be used
  /// while the dialog is open, but the title bar still works and every other
  /// window stays usable. Opening another dialog while one is showing stacks
  /// it on top; closing the top dialog returns to the one below, and keyboard
  /// focus goes back to where it was.
  ///
  /// Close the dialog from inside with `Navigator.pop(context, result)`, as
  /// with Flutter's `showDialog`, or from anywhere with [popDialog]. When
  /// [barrierDismissible] is true, tapping the barrier or pressing Escape
  /// closes the dialog with a null result. If the window closes, open dialogs
  /// complete with null.
  ///
  /// ```dart
  /// final bool? discard = await window.showDialog<bool>(
  ///   barrierDismissible: false,
  ///   builder: (context) => AlertDialog(
  ///     title: const Text('Discard changes?'),
  ///     actions: [
  ///       TextButton(
  ///         onPressed: () => Navigator.pop(context, false),
  ///         child: const Text('Keep editing'),
  ///       ),
  ///       FilledButton(
  ///         onPressed: () => Navigator.pop(context, true),
  ///         child: const Text('Discard'),
  ///       ),
  ///     ],
  ///   ),
  /// );
  /// ```
  Future<T?> showDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
  }) {
    if (_closed) {
      return Future<T?>.value();
    }
    return _dialogs.push<T>(
      _DialogRequest<T>(
        owner: _dialogs,
        builder: builder,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        barrierLabel: barrierLabel,
      ),
    );
  }

  /// Closes the top window dialog with [result]. Returns false when no
  /// window dialog is open.
  bool popDialog<T extends Object?>([T? result]) => _dialogs.pop(result);

  /// Returns the window that encloses [context].
  ///
  /// Works in a window's content, title bar, dialogs and dock bar. Throws
  /// when [context] is not inside a window; see [maybeOf].
  static WindowEntry of(BuildContext context) {
    final WindowEntry? window = maybeOf(context);
    assert(() {
      if (window == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('WindowEntry.of() called outside a window.'),
          ErrorDescription(
            'No window of a WindowStack encloses the context that was used.',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return window!;
  }

  /// Returns the window that encloses [context], or null.
  ///
  /// Does not make [context] rebuild when the window changes. To react to
  /// changes, listen to the returned entry, for example with a
  /// [ListenableBuilder].
  static WindowEntry? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_WindowEntryScope>()?.window;
  }

  @override
  void addListener(VoidCallback listener) => _changes.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    _changes.removeListener(listener);
  }

  @override
  String toString() => 'WindowEntry($id, $title, ${_mode.name})';

  // Internal API.

  void _notify() {
    if (!_disposed) {
      _changes.notify();
    }
  }

  void _dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    focusScopeNode.dispose();
    _changes.dispose();
  }

  bool get _hasFocus => !_disposed && focusScopeNode.hasFocus;

  Rect _displayBounds(Size stackSize) {
    if (stackSize.isEmpty) {
      return _bounds;
    }
    return fitRectInBounds(_bounds, Offset.zero & stackSize);
  }

  /// Remembers which widget in this window has focus, so that activating the
  /// window later can return to it.
  ///
  /// The focus scope keeps a history too, but on desktop a focused text field
  /// unfocuses itself when the mouse goes down outside it, for example on
  /// another window, and that clears the history.
  void _rememberFocus() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    _lastFocus = focus != null &&
            focus != focusScopeNode &&
            focus.ancestors.contains(focusScopeNode)
        ? focus
        : null;
  }

  bool _canRestore(FocusNode node, FocusScopeNode within) {
    return (node.context?.mounted ?? false) &&
        node.canRequestFocus &&
        (node == within || node.ancestors.contains(within));
  }

  /// Moves keyboard focus into the window: into its top dialog if one is
  /// open, otherwise back to the widget that last had focus in it.
  void _requestFocus() {
    if (_disposed) {
      return;
    }
    final FocusNode target = _focusTarget();
    if (target.parent != null && target.canRequestFocus) {
      target.requestFocus();
      return;
    }
    // The window cannot take focus yet: it is about to be built for the first
    // time, or it is coming back from the dock and is still excluded from
    // focus until the next frame. A FocusScopeNode ignores focus requests in
    // that state, so ask once more after the frame, if a WindowStack is there
    // to build it.
    if (_focusRequestPending || controller._host == null) {
      return;
    }
    _focusRequestPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusRequestPending = false;
      if (_disposed || !isActive || controller.hasDialogs) {
        return;
      }
      final FocusNode retry = _focusTarget();
      if (retry.parent != null && retry.canRequestFocus) {
        retry.requestFocus();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// The top dialog, the remembered widget, or the window's own scope.
  FocusNode _focusTarget() {
    final FocusScopeNode scope = _dialogs.topFocusScope ?? focusScopeNode;
    final FocusNode? remembered = _lastFocus;
    if (remembered != null && _canRestore(remembered, scope)) {
      return remembered;
    }
    return scope;
  }

  void _clearBoundsAnimation() {
    _animateBounds = false;
  }

  void _startMove(Offset globalPosition) {
    if (_closed || !draggable || _mode != WindowMode.normal) {
      return;
    }
    _interactionStart = controller._toLocal(globalPosition);
    _interactionStartBounds = bounds;
    _resizeEdge = null;
    _animateBounds = false;
  }

  void _updateMove(Offset globalPosition) {
    final Offset? start = _interactionStart;
    final Rect? startBounds = _interactionStartBounds;
    if (start == null || startBounds == null || _resizeEdge != null) {
      return;
    }
    final Offset delta = controller._toLocal(globalPosition) - start;
    _bounds = fitRectInBounds(startBounds.shift(delta), controller._area);
    _notify();
  }

  void _startResize(ResizeEdge edge, Offset globalPosition) {
    if (_closed || !resizable || _mode != WindowMode.normal) {
      return;
    }
    _interactionStart = controller._toLocal(globalPosition);
    _interactionStartBounds = bounds;
    _resizeEdge = edge;
    _animateBounds = false;
    controller._host?._setInteractionCursor(_cursorForEdge(edge));
  }

  void _updateResize(Offset globalPosition) {
    final Offset? start = _interactionStart;
    final Rect? startBounds = _interactionStartBounds;
    final ResizeEdge? edge = _resizeEdge;
    if (start == null || startBounds == null || edge == null) {
      return;
    }
    final Offset delta = controller._toLocal(globalPosition) - start;
    _bounds = resizeRect(
      startBounds,
      edge,
      delta,
      minSize: minSize,
      maxSize: maxSize,
      bounds: controller._area,
    );
    _notify();
  }

  void _endInteraction() {
    final bool wasResizing = _resizeEdge != null;
    _interactionStart = null;
    _interactionStartBounds = null;
    _resizeEdge = null;
    if (wasResizing) {
      controller._host?._setInteractionCursor(null);
    }
  }
}

MouseCursor _cursorForEdge(ResizeEdge edge) {
  return switch (edge) {
    ResizeEdge.left || ResizeEdge.right => SystemMouseCursors.resizeLeftRight,
    ResizeEdge.top || ResizeEdge.bottom => SystemMouseCursors.resizeUpDown,
    ResizeEdge.topLeft ||
    ResizeEdge.bottomRight =>
      SystemMouseCursors.resizeUpLeftDownRight,
    ResizeEdge.topRight ||
    ResizeEdge.bottomLeft =>
      SystemMouseCursors.resizeUpRightDownLeft,
  };
}

/// Makes a [WindowEntry] available to the widgets inside its window.
class _WindowEntryScope extends InheritedWidget {
  const _WindowEntryScope({required this.window, required super.child});

  final WindowEntry window;

  @override
  bool updateShouldNotify(_WindowEntryScope oldWidget) {
    return window != oldWidget.window;
  }
}
