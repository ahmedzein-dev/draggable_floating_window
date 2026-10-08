part of '../core.dart';

/// Signature for building a window's title bar.
///
/// The returned widget replaces the whole title bar. Wrap the parts that
/// should move the window in a [WindowDragArea], and use [WindowControls] for
/// the standard buttons. Call [WindowEntry.of] to reach the window from
/// widgets further down.
typedef WindowTitleBarBuilder = Widget Function(
    BuildContext context, WindowEntry window);

/// Signature for building the bar that represents a minimized window in the
/// dock. See [MinimizedWindowBar] for the default.
typedef MinimizedWindowBuilder = Widget Function(
    BuildContext context, WindowEntry window);

/// Signature for [WindowEntry.onCloseRequest]. Return `false` to keep the
/// window open.
typedef WindowCloseRequestCallback = FutureOr<bool> Function();

/// Opens, arranges and focuses the windows of a [WindowStack].
///
/// The controller owns the windows: their stacking order, which one is
/// active, the dock slots of minimized windows and the stack-level dialog
/// stack. Create one per [WindowStack], usually in a [State], and dispose it
/// with the state.
///
/// ```dart
/// class _HomeState extends State<Home> {
///   final WindowStackController _windows = WindowStackController();
///
///   @override
///   void dispose() {
///     _windows.dispose();
///     super.dispose();
///   }
///
///   void _openNotes() {
///     _windows.open(
///       title: 'Notes',
///       size: const Size(480, 360),
///       builder: (context) => const NotesEditor(),
///     );
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return WindowStack(controller: _windows);
///   }
/// }
/// ```
///
/// The controller notifies its listeners when windows open or close, change
/// stacking order, mode, priority or title, when the active window changes and
/// when stack-level dialogs open or close. Moving and resizing a window
/// notifies only that window's [WindowEntry].
class WindowStackController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [placement] decides where windows opened without a position appear.
  /// [defaultSizeFactor] sizes windows opened without a size as a fraction of
  /// the stack: the default is 70% of its width and 85% of its height.
  WindowStackController({
    this.placement = const WindowPlacement.cascade(),
    this.defaultSizeFactor = const Size(0.7, 0.85),
  }) : assert(
          defaultSizeFactor.width > 0 &&
              defaultSizeFactor.width <= 1 &&
              defaultSizeFactor.height > 0 &&
              defaultSizeFactor.height <= 1,
          'defaultSizeFactor must be a fraction of the stack, in (0, 1].',
        );

  /// Decides where windows opened without a `position` appear.
  final WindowPlacement placement;

  /// The size of windows opened without a `size`, as a fraction of the
  /// stack's width and height.
  final Size defaultSizeFactor;

  final List<WindowEntry> _windows = <WindowEntry>[];
  List<WindowEntry>? _stackingOrder;
  WindowEntry? _activeWindow;
  int _activationCounter = 0;
  int _idCounter = 0;
  _WindowStackState? _host;
  bool _disposed = false;

  late final _DialogStack _dialogs = _DialogStack(
    onChanged: notifyListeners,
    canTakeFocus: () => true,
    focusFallback: _focusActiveWindowOrStack,
  );

  /// The open windows from bottom to top, in the order they are drawn.
  ///
  /// Windows with a higher [WindowEntry.priority] come later. Within a
  /// priority, the most recently activated window comes last. Minimized
  /// windows keep their place in this list.
  List<WindowEntry> get windows {
    return _stackingOrder ??= List<WindowEntry>.unmodifiable(
      _windows.toList()..sort(_compareStacking),
    );
  }

  /// The window that receives keyboard input, or null when no window is
  /// open or every window is minimized.
  WindowEntry? get activeWindow => _activeWindow;

  /// Whether a stack-level dialog is open. While one is, the windows cannot
  /// be used.
  bool get hasDialogs => _dialogs.isNotEmpty;

  /// The number of stack-level dialogs that are open.
  int get dialogCount => _dialogs.length;

  /// The size of the attached [WindowStack] at its last layout, or
  /// [Size.zero] before it has been laid out.
  Size get size => _host?._size ?? Size.zero;

  /// Returns the open window with [id], or null.
  WindowEntry? windowById(String id) {
    for (final WindowEntry window in _windows) {
      if (window.id == id) {
        return window;
      }
    }
    return null;
  }

  /// Opens a window, makes it the active window and returns it.
  ///
  /// [builder] builds the window's content. It is called when the content
  /// needs to build, not every time the [WindowStack] rebuilds, so keep the
  /// content self-contained.
  ///
  /// If [id] matches a window that is already open, nothing new is opened:
  /// that window is restored if minimized, activated and returned, and the
  /// other arguments are ignored. Use ids for windows that should exist only
  /// once, such as a settings window or a record that is already being
  /// edited.
  ///
  /// [size] defaults to [defaultSizeFactor] of the stack. [position] is the
  /// top-left corner; when null, [placement] chooses one. Both are clamped so
  /// the window fits inside the stack. The user cannot resize the window
  /// below [minSize] or above [maxSize].
  ///
  /// Windows with a higher [priority] always stay above windows with a lower
  /// one; see [WindowPriority].
  ///
  /// The flags hide the matching title bar buttons and disable the matching
  /// gestures and shortcuts. Programmatic calls such as [WindowEntry.close]
  /// still work.
  ///
  /// [onCloseRequest] runs before the window closes through the close button,
  /// a shortcut or [WindowEntry.close]; return `false` to keep it open, for
  /// example after asking about unsaved changes. [onClosed] runs after the
  /// window has closed.
  ///
  /// ```dart
  /// final WindowEntry invoice = controller.open(
  ///   id: 'invoice-1042',
  ///   title: 'Invoice #1042',
  ///   size: const Size(720, 520),
  ///   builder: (context) => const InvoiceForm(),
  ///   onClosed: () => debugPrint('Invoice window closed'),
  /// );
  /// ```
  WindowEntry open({
    String? id,
    required WidgetBuilder builder,
    String title = '',
    Widget? icon,
    Size? size,
    Offset? position,
    Size minSize = const Size(240, 160),
    Size? maxSize,
    int priority = WindowPriority.normal,
    bool resizable = true,
    bool draggable = true,
    bool minimizable = true,
    bool maximizable = true,
    bool closable = true,
    WindowTitleBarBuilder? titleBarBuilder,
    WindowCloseRequestCallback? onCloseRequest,
    VoidCallback? onClosed,
  }) {
    assert(!_disposed, 'A WindowStackController was used after dispose.');
    assert(
      maxSize == null ||
          (maxSize.width >= minSize.width && maxSize.height >= minSize.height),
      'maxSize must not be smaller than minSize.',
    );
    if (id != null) {
      final WindowEntry? existing = windowById(id);
      if (existing != null) {
        activate(existing);
        return existing;
      }
    }
    final WindowEntry window = WindowEntry._(
      controller: this,
      id: id ?? 'window-${++_idCounter}',
      builder: builder,
      title: title,
      icon: icon,
      priority: priority,
      minSize: minSize,
      maxSize: maxSize,
      resizable: resizable,
      draggable: draggable,
      minimizable: minimizable,
      maximizable: maximizable,
      closable: closable,
      titleBarBuilder: titleBarBuilder,
      onCloseRequest: onCloseRequest,
      onClosed: onClosed,
      requestedSize: size,
      requestedPosition: position,
    );
    window._activationOrder = ++_activationCounter;
    _windows.add(window);
    _stackingOrder = null;
    if (_hasLayout) {
      _place(window, size: this.size);
    }
    _setActive(window, focus: true, raise: false);
    notifyListeners();
    return window;
  }

  /// Makes [window] the active window: brings it to the top of its priority,
  /// restores it if minimized, and moves keyboard focus into it.
  ///
  /// Focus returns to the widget that was focused when the window was last
  /// active. While a stack-level dialog is open, focus stays in the dialog.
  ///
  /// Same as [WindowEntry.activate].
  void activate(WindowEntry window) {
    assert(window.controller == this);
    if (window._closed) {
      return;
    }
    final bool wasMinimized = window.isMinimized;
    if (wasMinimized) {
      _restoreFromMinimized(window);
    }
    final bool alreadyFront = window._activationOrder == _activationCounter &&
        _activeWindow == window;
    if (alreadyFront && !wasMinimized) {
      if (!window._hasFocus) {
        _scheduleFocus();
      }
      return;
    }
    _setActive(window, focus: true);
    notifyListeners();
  }

  /// Activates the next window in opening order, skipping minimized windows
  /// and wrapping around. Returns whether a window was activated.
  bool activateNext() => _activateRelative(1);

  /// Activates the previous window in opening order, skipping minimized
  /// windows and wrapping around. Returns whether a window was activated.
  bool activatePrevious() => _activateRelative(-1);

  /// Closes every window, top to bottom.
  ///
  /// Unless [force] is true, each window's [WindowEntry.onCloseRequest] can
  /// keep it open. Completes when every window has been handled.
  Future<void> closeAll({bool force = false}) async {
    for (final WindowEntry window in windows.reversed.toList()) {
      await window.close(force: force);
    }
  }

  /// Shows a dialog above every window and returns the value it is closed
  /// with.
  ///
  /// While a stack-level dialog is open, the windows, the dock and the
  /// [WindowStack.child] cannot be used and window shortcuts are disabled.
  /// Dialogs opened while another one is showing stack on top of it; closing
  /// the top one returns to the one below.
  ///
  /// Close the dialog from inside with `Navigator.pop(context, result)`, as
  /// with Flutter's `showDialog`, or from anywhere with [popDialog]. When
  /// [barrierDismissible] is true, tapping the barrier or pressing Escape
  /// closes the dialog with a null result. [barrierColor] defaults to
  /// [WindowStackThemeData.barrierColor].
  ///
  /// To block only one window, use [WindowEntry.showDialog] instead. To block
  /// the whole app, use Flutter's `showDialog`.
  ///
  /// ```dart
  /// final bool? confirmed = await controller.showDialog<bool>(
  ///   builder: (context) => AlertDialog(
  ///     title: const Text('Close all windows?'),
  ///     actions: [
  ///       TextButton(
  ///         onPressed: () => Navigator.pop(context, false),
  ///         child: const Text('Cancel'),
  ///       ),
  ///       FilledButton(
  ///         onPressed: () => Navigator.pop(context, true),
  ///         child: const Text('Close all'),
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
    assert(!_disposed, 'A WindowStackController was used after dispose.');
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

  /// Closes the top stack-level dialog with [result]. Returns false when no
  /// stack-level dialog is open.
  bool popDialog<T extends Object?>([T? result]) => _dialogs.pop(result);

  @override
  void dispose() {
    _disposed = true;
    _dialogs.clear();
    for (final WindowEntry window in _windows) {
      window._closed = true;
      window._dialogs.clear();
      window._dispose();
    }
    _windows.clear();
    _stackingOrder = null;
    _activeWindow = null;
    super.dispose();
  }

  // Internal API used by WindowEntry and WindowStack.

  bool get _hasLayout => !size.isEmpty;

  Rect get _area => Offset.zero & size;

  static int _compareStacking(WindowEntry a, WindowEntry b) {
    final int byPriority = a.priority.compareTo(b.priority);
    if (byPriority != 0) {
      return byPriority;
    }
    return a._activationOrder.compareTo(b._activationOrder);
  }

  Offset _toLocal(Offset globalPosition) {
    return _host?._globalToLocal(globalPosition) ?? globalPosition;
  }

  /// Places windows that were opened before the stack had a size. Called
  /// during layout, so it must not notify listeners.
  void _placePendingWindows(Size stackSize) {
    for (final WindowEntry window in _windows) {
      if (!window._placed) {
        _place(window, size: stackSize);
      }
    }
  }

  void _place(WindowEntry window, {required Size size}) {
    final Rect area = Offset.zero & size;
    final Size requested = window._requestedSize ??
        Size(
          size.width * defaultSizeFactor.width,
          size.height * defaultSizeFactor.height,
        );
    final Size windowSize = Size(
      requested.width
          .clamp(
            window.minSize.width,
            window.maxSize?.width ?? double.infinity,
          )
          .clamp(0.0, size.width),
      requested.height
          .clamp(
            window.minSize.height,
            window.maxSize?.height ?? double.infinity,
          )
          .clamp(0.0, size.height),
    );
    final List<Rect> occupied = <Rect>[
      for (final WindowEntry other in windows)
        if (other != window && other._placed && other.mode == WindowMode.normal)
          other._displayBounds(size),
    ];
    final Offset origin = window._requestedPosition ??
        placement.place(windowSize, area, occupied);
    window._bounds = fitRectInBounds(origin & windowSize, area);
    window._placed = true;
    window._requestedSize = null;
    window._requestedPosition = null;
  }

  void _setActive(
    WindowEntry window, {
    required bool focus,
    bool raise = true,
  }) {
    if (window._closed) {
      return;
    }
    final WindowEntry? previous = _activeWindow;
    if (previous != null && previous != window) {
      previous._rememberFocus();
    }
    if (raise && window._activationOrder != _activationCounter) {
      window._activationOrder = ++_activationCounter;
      _stackingOrder = null;
    }
    _activeWindow = window;
    if (previous != window) {
      previous?._notify();
      window._notify();
    }
    if (focus) {
      _scheduleFocus();
    }
  }

  bool _focusScheduled = false;

  /// Moves focus into the active window once the current event has been
  /// handled.
  ///
  /// Activation usually happens on a pointer down. On desktop, the same
  /// pointer down makes a focused text field in another window unfocus
  /// itself, which focuses that other window's scope. Focusing afterwards
  /// lets the activated window win.
  void _scheduleFocus() {
    if (_focusScheduled) {
      return;
    }
    _focusScheduled = true;
    scheduleMicrotask(() {
      _focusScheduled = false;
      if (!_disposed) {
        _focusActiveWindowOrStack();
      }
    });
  }

  /// Moves focus into the active window, or to the stack itself when no
  /// window is active. Does nothing while a stack-level dialog is open.
  void _focusActiveWindowOrStack() {
    if (_dialogs.isNotEmpty) {
      return;
    }
    final WindowEntry? active = _activeWindow;
    if (active != null) {
      active._requestFocus();
    } else {
      _host?._focusStack();
    }
  }

  /// Activates the most recently used visible window other than [except].
  void _activateMostRecent({WindowEntry? except, required bool focus}) {
    WindowEntry? best;
    for (final WindowEntry window in _windows) {
      if (window == except || window._closed || window.isMinimized) {
        continue;
      }
      if (best == null || window._activationOrder > best._activationOrder) {
        best = window;
      }
    }
    if (best != null) {
      _setActive(best, focus: focus, raise: false);
    } else {
      _activeWindow = null;
      if (focus) {
        _scheduleFocus();
      }
    }
  }

  bool _activateRelative(int step) {
    final List<WindowEntry> candidates = <WindowEntry>[
      for (final WindowEntry window in _windows)
        if (!window._closed && !window.isMinimized) window,
    ];
    if (candidates.isEmpty) {
      return false;
    }
    final int current =
        _activeWindow == null ? -1 : candidates.indexOf(_activeWindow!);
    final int next = current == -1
        ? (step > 0 ? 0 : candidates.length - 1)
        : (current + step) % candidates.length;
    activate(candidates[next]);
    return true;
  }

  int _firstFreeDockSlot() {
    final Set<int> used = <int>{
      for (final WindowEntry window in _windows)
        if (window._dockSlot != null) window._dockSlot!,
    };
    int slot = 0;
    while (used.contains(slot)) {
      slot++;
    }
    return slot;
  }

  void _minimize(WindowEntry window) {
    if (window._closed || !window.minimizable || window.isMinimized) {
      return;
    }
    final bool hadFocus = window._hasFocus;
    if (hadFocus) {
      window._rememberFocus();
    }
    window._endInteraction();
    window._modeBeforeMinimize = window._mode;
    window._mode = WindowMode.minimized;
    window._dockSlot = _firstFreeDockSlot();
    window._animateBounds = false;
    if (_activeWindow == window) {
      _activeWindow = null;
      _activateMostRecent(except: window, focus: hadFocus);
    }
    window._notify();
    notifyListeners();
  }

  void _restoreFromMinimized(WindowEntry window) {
    window._mode = window._modeBeforeMinimize;
    window._dockSlot = null;
    window._notify();
  }

  void _maximize(WindowEntry window) {
    if (window._closed || !window.maximizable || window.isMaximized) {
      return;
    }
    window._endInteraction();
    window._dockSlot = null;
    window._mode = WindowMode.maximized;
    window._animateBounds = true;
    _setActive(window, focus: true);
    window._notify();
    notifyListeners();
  }

  void _restore(WindowEntry window) {
    if (window._closed) {
      return;
    }
    switch (window._mode) {
      case WindowMode.normal:
        return;
      case WindowMode.minimized:
        _restoreFromMinimized(window);
      case WindowMode.maximized:
        window._mode = WindowMode.normal;
        window._animateBounds = true;
        window._notify();
    }
    _setActive(window, focus: true);
    notifyListeners();
  }

  Future<bool> _close(WindowEntry window, {required bool force}) async {
    if (window._closed) {
      return true;
    }
    final WindowCloseRequestCallback? onCloseRequest = window.onCloseRequest;
    if (!force && onCloseRequest != null) {
      if (window._closeRequestPending) {
        return false;
      }
      window._closeRequestPending = true;
      final bool allowed;
      try {
        allowed = await onCloseRequest();
      } finally {
        window._closeRequestPending = false;
      }
      if (window._closed) {
        return true;
      }
      if (!allowed) {
        return false;
      }
    }
    _remove(window);
    return true;
  }

  void _remove(WindowEntry window) {
    final bool hadFocus =
        window._hasFocus || FocusManager.instance.primaryFocus == null;
    window._endInteraction();
    window._closed = true;
    _windows.remove(window);
    _stackingOrder = null;
    window._dialogs.clear();
    if (_activeWindow == window) {
      _activeWindow = null;
      _activateMostRecent(except: window, focus: hadFocus);
    }
    notifyListeners();
    window.onClosed?.call();
    if (_host != null) {
      // Dispose after the frame that removes the window's widgets, which still
      // reference its listenable and focus scope until then.
      WidgetsBinding.instance.addPostFrameCallback((_) => window._dispose());
    } else {
      window._dispose();
    }
  }

  void _onPriorityChanged() {
    _stackingOrder = null;
    _notifyIfAlive();
  }

  void _notifyIfAlive() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
