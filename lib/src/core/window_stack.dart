part of '../core.dart';

/// A desktop-style area that hosts floating windows.
///
/// Windows are opened through the [controller]. They can be dragged by their
/// title bar, resized from their edges and corners, minimized to a dock along
/// the bottom edge, maximized to fill the stack, and closed. Clicking a window
/// activates it: it moves to the top of its priority and gets keyboard focus.
/// [child] is drawn behind the windows, like a desktop background.
///
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Workspace')),
///   body: WindowStack(
///     controller: controller,
///     child: const DesktopBackground(),
///   ),
/// )
/// ```
///
/// The windows are ordinary widgets inside one Flutter view, not operating
/// system windows. Put the stack inside a page, as above, rather than in
/// `MaterialApp.builder`: then Flutter's own popups, such as [DropdownButton]
/// menus, [PopupMenuButton] menus and `showDialog`, open above the windows.
///
/// The stack must be given a bounded size. Windows always stay fully inside
/// it; when the stack shrinks, windows move and shrink to fit and return to
/// their position once there is room again.
///
/// Keyboard shortcuts work while focus is inside the stack. See
/// [defaultShortcuts].
class WindowStack extends StatefulWidget {
  /// Creates a window stack.
  const WindowStack({
    super.key,
    required this.controller,
    this.child,
    this.theme,
    this.labels = const WindowStackLabels(),
    this.titleBarBuilder,
    this.minimizedBuilder,
    this.shortcuts,
    this.clipBehavior = Clip.hardEdge,
  });

  /// Opens and arranges the windows of this stack.
  ///
  /// A controller can drive only one stack at a time.
  final WindowStackController controller;

  /// The widget behind the windows, sized to fill the stack.
  final Widget? child;

  /// The look of the windows.
  ///
  /// Unset values come from the [ThemeData] extension of the same type, then
  /// from defaults derived from the ambient [ThemeData].
  final WindowStackThemeData? theme;

  /// The text of the default chrome's tooltips and semantics labels.
  final WindowStackLabels labels;

  /// Builds the title bar of every window that was opened without its own
  /// `titleBarBuilder`. Defaults to [WindowTitleBar].
  final WindowTitleBarBuilder? titleBarBuilder;

  /// Builds the bar shown in the dock for each minimized window. Defaults to
  /// [MinimizedWindowBar].
  final MinimizedWindowBuilder? minimizedBuilder;

  /// The keyboard shortcuts of the stack. Defaults to [defaultShortcuts].
  ///
  /// Pass an empty map to disable them, or your own map to rebind them to
  /// the intents [ActivateNextWindowIntent], [ActivatePreviousWindowIntent],
  /// [CloseWindowIntent], [MinimizeWindowIntent] and
  /// [ToggleMaximizeWindowIntent].
  final Map<ShortcutActivator, Intent>? shortcuts;

  /// How to clip the windows' shadows at the stack's edges.
  final Clip clipBehavior;

  /// The default shortcuts:
  ///
  /// * Ctrl+Tab activates the next window.
  /// * Ctrl+Shift+Tab activates the previous window.
  /// * Ctrl+F4 closes the active window.
  ///
  /// Browsers reserve these keys, so on the web, provide your own bindings
  /// through [shortcuts].
  static const Map<ShortcutActivator, Intent> defaultShortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.tab, control: true):
        ActivateNextWindowIntent(),
    SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
        ActivatePreviousWindowIntent(),
    SingleActivator(LogicalKeyboardKey.f4, control: true): CloseWindowIntent(),
  };

  /// Returns the controller of the [WindowStack] that encloses [context].
  ///
  /// Throws when there is none; see [maybeOf].
  static WindowStackController of(BuildContext context) {
    final WindowStackController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('WindowStack.of() called outside a WindowStack.'),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return controller!;
  }

  /// Returns the controller of the [WindowStack] that encloses [context], or
  /// null.
  ///
  /// Does not make [context] rebuild when the controller changes. To react to
  /// changes, listen to the controller.
  static WindowStackController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_WindowStackScope>()
        ?.controller;
  }

  @override
  State<WindowStack> createState() => _WindowStackState();
}

class _WindowStackState extends State<WindowStack> {
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'WindowStack',
    skipTraversal: true,
  );
  final GlobalKey _areaKey = GlobalKey(debugLabel: 'WindowStack area');
  final ValueNotifier<MouseCursor?> _interactionCursor =
      ValueNotifier<MouseCursor?>(null);

  Size _size = Size.zero;
  TextDirection _textDirection = TextDirection.ltr;

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    ActivateNextWindowIntent: _WindowAction<ActivateNextWindowIntent>(
      this,
      enabled: (WindowStackController controller) => controller.windows.any(
        (WindowEntry window) => !window.isMinimized,
      ),
      perform: (WindowStackController controller) => controller.activateNext(),
    ),
    ActivatePreviousWindowIntent: _WindowAction<ActivatePreviousWindowIntent>(
      this,
      enabled: (WindowStackController controller) => controller.windows.any(
        (WindowEntry window) => !window.isMinimized,
      ),
      perform: (WindowStackController controller) =>
          controller.activatePrevious(),
    ),
    CloseWindowIntent: _WindowAction<CloseWindowIntent>(
      this,
      enabled: (WindowStackController controller) =>
          controller.activeWindow?.closable ?? false,
      perform: (WindowStackController controller) =>
          controller.activeWindow?.close(),
    ),
    MinimizeWindowIntent: _WindowAction<MinimizeWindowIntent>(
      this,
      enabled: (WindowStackController controller) =>
          controller.activeWindow?.minimizable ?? false,
      perform: (WindowStackController controller) =>
          controller.activeWindow?.minimize(),
    ),
    ToggleMaximizeWindowIntent: _WindowAction<ToggleMaximizeWindowIntent>(
      this,
      enabled: (WindowStackController controller) =>
          controller.activeWindow?.maximizable ?? false,
      perform: (WindowStackController controller) =>
          controller.activeWindow?.toggleMaximize(),
    ),
  };

  @override
  void initState() {
    super.initState();
    _attach(widget.controller);
  }

  @override
  void didUpdateWidget(WindowStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller);
      _attach(widget.controller);
    }
  }

  @override
  void dispose() {
    _detach(widget.controller);
    _focusNode.dispose();
    _interactionCursor.dispose();
    super.dispose();
  }

  void _attach(WindowStackController controller) {
    assert(
      controller._host == null || controller._host == this,
      'A WindowStackController can drive only one WindowStack at a time.',
    );
    controller._host = this;
    controller.addListener(_onControllerChanged);
  }

  void _detach(WindowStackController controller) {
    if (controller._host == this) {
      controller._host = null;
    }
    controller.removeListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Offset _globalToLocal(Offset globalPosition) {
    final RenderObject? box = _areaKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      return box.globalToLocal(globalPosition);
    }
    return globalPosition;
  }

  void _focusStack() {
    if (mounted) {
      _focusNode.requestFocus();
    }
  }

  void _setInteractionCursor(MouseCursor? cursor) {
    _interactionCursor.value = cursor;
  }

  @override
  Widget build(BuildContext context) {
    final WindowStackController controller = widget.controller;
    return _WindowStackScope(
      controller: controller,
      child: WindowStackThemeScope(
        theme: resolveWindowStackTheme(context, widget.theme),
        labels: widget.labels,
        child: Shortcuts(
          shortcuts: widget.shortcuts ?? WindowStack.defaultShortcuts,
          child: Actions(
            actions: _actions,
            child: Focus(
              focusNode: _focusNode,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  assert(
                    constraints.hasBoundedWidth && constraints.hasBoundedHeight,
                    'WindowStack needs a bounded width and height. Place it '
                    'in an Expanded, a SizedBox or a Scaffold body.',
                  );
                  _size = constraints.biggest;
                  _textDirection = Directionality.of(context);
                  if (!_size.isEmpty) {
                    controller._placePendingWindows(_size);
                  }
                  return _buildArea(context, controller);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArea(BuildContext context, WindowStackController controller) {
    final List<WindowEntry> windows = controller.windows;
    final bool blocked = controller.hasDialogs;
    final MinimizedWindowBuilder minimizedBuilder = widget.minimizedBuilder ??
        (BuildContext context, WindowEntry window) =>
            const MinimizedWindowBar();
    return ClipRect(
      clipBehavior: widget.clipBehavior,
      child: Stack(
        key: _areaKey,
        fit: StackFit.expand,
        children: <Widget>[
          if (widget.child != null)
            Positioned.fill(
              child: ExcludeFocus(excluding: blocked, child: widget.child!),
            ),
          for (final WindowEntry window in windows)
            _WindowLayer(
              key: ObjectKey(window),
              window: window,
              stackSize: _size,
              blocked: blocked,
              titleBarBuilder: window.titleBarBuilder ??
                  widget.titleBarBuilder ??
                  _defaultTitleBarBuilder,
            ),
          for (final WindowEntry window in windows)
            if (window.isMinimized)
              _DockItem(
                key: ValueKey<Object>(('dock', window)),
                window: window,
                stackSize: _size,
                textDirection: _textDirection,
                blocked: blocked,
                builder: minimizedBuilder,
              ),
          for (final _DialogRequest<Object?> request
              in controller._dialogs.requests)
            Positioned.fill(
              key: ObjectKey(request),
              child: _DialogLayer(request: request),
            ),
          Positioned.fill(
            child: ValueListenableBuilder<MouseCursor?>(
              valueListenable: _interactionCursor,
              builder:
                  (BuildContext context, MouseCursor? cursor, Widget? child) {
                // While a resize is in progress, keep the resize cursor
                // even when the pointer leaves the thin handle.
                return cursor == null
                    ? const SizedBox.shrink()
                    : MouseRegion(cursor: cursor);
              },
            ),
          ),
        ],
      ),
    );
  }
}

Widget _defaultTitleBarBuilder(BuildContext context, WindowEntry window) {
  return const WindowTitleBar();
}

/// Makes the controller of a [WindowStack] available to its descendants.
class _WindowStackScope extends InheritedWidget {
  const _WindowStackScope({required this.controller, required super.child});

  final WindowStackController controller;

  @override
  bool updateShouldNotify(_WindowStackScope oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// Runs a window shortcut against the stack's current controller.
class _WindowAction<T extends Intent> extends Action<T> {
  _WindowAction(this._state, {required this.enabled, required this.perform});

  final _WindowStackState _state;
  final bool Function(WindowStackController controller) enabled;
  final Object? Function(WindowStackController controller) perform;

  @override
  bool isEnabled(T intent) {
    final WindowStackController controller = _state.widget.controller;
    return _state.mounted && !controller.hasDialogs && enabled(controller);
  }

  @override
  Object? invoke(T intent) => perform(_state.widget.controller);
}
