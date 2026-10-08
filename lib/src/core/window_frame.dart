part of '../core.dart';

/// Positions one window inside the stack and animates maximize and restore.
class _WindowLayer extends StatelessWidget {
  const _WindowLayer({
    super.key,
    required this.window,
    required this.stackSize,
    required this.blocked,
    required this.titleBarBuilder,
  });

  final WindowEntry window;
  final Size stackSize;
  final bool blocked;
  final WindowTitleBarBuilder titleBarBuilder;

  @override
  Widget build(BuildContext context) {
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    return ListenableBuilder(
      listenable: window,
      builder: (BuildContext context, Widget? frame) {
        final Rect rect = window.isMaximized
            ? Offset.zero & stackSize
            : window._displayBounds(stackSize);
        final bool minimized = window.isMinimized;
        return AnimatedPositioned.fromRect(
          rect: rect,
          duration:
              window._animateBounds ? theme.animationDuration! : Duration.zero,
          curve: theme.animationCurve!,
          onEnd: window._clearBoundsAnimation,
          child: Visibility(
            // A minimized window keeps its content alive but hidden, so that
            // restoring it brings back its state, scroll position and input.
            visible: !minimized,
            maintainState: true,
            // _MinimizedTickerMode stops the animations instead.
            maintainAnimation: true,
            child: _MinimizedTickerMode(
              minimized: minimized,
              child: ExcludeFocus(
                excluding: minimized || blocked,
                child: RepaintBoundary(child: frame),
              ),
            ),
          ),
        );
      },
      child: _WindowFrame(window: window, titleBarBuilder: titleBarBuilder),
    );
  }
}

/// Stops the animations of a minimized window, a moment after it is
/// minimized so that what was animating out can finish first.
///
/// Tooltips need this: a tooltip paints in the root overlay, outside the
/// hidden window, and removes itself only when its fade-out finishes. Without
/// it, the tooltip of the minimize button stays on screen.
class _MinimizedTickerMode extends StatefulWidget {
  const _MinimizedTickerMode({required this.minimized, required this.child});

  final bool minimized;
  final Widget child;

  @override
  State<_MinimizedTickerMode> createState() => _MinimizedTickerModeState();
}

class _MinimizedTickerModeState extends State<_MinimizedTickerMode> {
  /// Longer than a tooltip's fade-out.
  static const Duration _settleDuration = Duration(milliseconds: 300);

  Timer? _settling;

  @override
  void didUpdateWidget(_MinimizedTickerMode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.minimized == oldWidget.minimized) {
      return;
    }
    _settling?.cancel();
    _settling = null;
    if (widget.minimized) {
      _settling = Timer(_settleDuration, () {
        if (mounted) {
          setState(() => _settling = null);
        }
      });
      // A tooltip under a pointer that stays still would not dismiss itself.
      // Dismissing starts an animation, so wait until this build is done.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.minimized) {
          Tooltip.dismissAllToolTips();
        }
      });
    }
  }

  @override
  void dispose() {
    _settling?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: !widget.minimized || _settling != null,
      child: widget.child,
    );
  }
}

/// The chrome of a window: shadow, outline, title bar, content, window
/// dialogs and resize handles.
class _WindowFrame extends StatefulWidget {
  const _WindowFrame({required this.window, required this.titleBarBuilder});

  final WindowEntry window;
  final WindowTitleBarBuilder titleBarBuilder;

  @override
  State<_WindowFrame> createState() => _WindowFrameState();
}

class _WindowFrameState extends State<_WindowFrame> {
  // Built once, so that rebuilding the chrome never rebuilds the content.
  late final Widget _content = KeyedSubtree(
    key: widget.window._contentKey,
    child: Builder(builder: widget.window.builder),
  );

  @override
  void initState() {
    super.initState();
    widget.window.addListener(_onWindowChanged);
  }

  @override
  void dispose() {
    widget.window.removeListener(_onWindowChanged);
    super.dispose();
  }

  void _onWindowChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = widget.window;
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    final bool active = window.isActive;
    final bool maximized = window.isMaximized;
    final BorderRadius radius =
        maximized ? BorderRadius.zero : theme.borderRadius!;
    final bool canResize = window.resizable && window.mode == WindowMode.normal;
    final double handle = theme.resizeHandleSize!;

    final Widget body = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        // Content behind an open window dialog cannot take focus, so Tab and
        // shortcuts stay inside the dialog.
        ExcludeFocus(excluding: window.hasDialogs, child: _content),
        for (final _DialogRequest<Object?> request in window._dialogs.requests)
          _DialogLayer(key: ObjectKey(request), request: request),
      ],
    );

    return Listener(
      // Any click inside a window activates it, like a native window.
      onPointerDown: (PointerDownEvent event) => window.activate(),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: window.title,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: maximized
                ? const <BoxShadow>[]
                : (active ? theme.activeShadows : theme.inactiveShadows),
          ),
          child: Material(
            color: theme.backgroundColor,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: maximized
                  ? BorderSide.none
                  : BorderSide(
                      color: active
                          ? theme.activeBorderColor!
                          : theme.borderColor!,
                    ),
            ),
            child: _WindowEntryScope(
              window: window,
              child: FocusScope(
                node: window.focusScopeNode,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Builder(
                          builder: (BuildContext context) =>
                              widget.titleBarBuilder(context, window),
                        ),
                        Expanded(child: body),
                      ],
                    ),
                    if (canResize)
                      for (final ResizeEdge edge in ResizeEdge.values)
                        _ResizeHandle(
                          window: window,
                          edge: edge,
                          thickness: handle,
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An invisible zone along an edge or in a corner that resizes the window.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.window,
    required this.edge,
    required this.thickness,
  });

  final WindowEntry window;
  final ResizeEdge edge;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final double corner = thickness * 2;
    final Widget handle = MouseRegion(
      cursor: _cursorForEdge(edge),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        dragStartBehavior: DragStartBehavior.down,
        onPanStart: (DragStartDetails details) =>
            window._startResize(edge, details.globalPosition),
        onPanUpdate: (DragUpdateDetails details) =>
            window._updateResize(details.globalPosition),
        onPanEnd: (DragEndDetails details) => window._endInteraction(),
        onPanCancel: window._endInteraction,
      ),
    );
    return switch (edge) {
      ResizeEdge.left => Positioned(
          left: 0,
          top: corner,
          bottom: corner,
          width: thickness,
          child: handle,
        ),
      ResizeEdge.right => Positioned(
          right: 0,
          top: corner,
          bottom: corner,
          width: thickness,
          child: handle,
        ),
      ResizeEdge.top => Positioned(
          top: 0,
          left: corner,
          right: corner,
          height: thickness,
          child: handle,
        ),
      ResizeEdge.bottom => Positioned(
          bottom: 0,
          left: corner,
          right: corner,
          height: thickness,
          child: handle,
        ),
      ResizeEdge.topLeft => Positioned(
          left: 0,
          top: 0,
          width: corner,
          height: corner,
          child: handle,
        ),
      ResizeEdge.topRight => Positioned(
          right: 0,
          top: 0,
          width: corner,
          height: corner,
          child: handle,
        ),
      ResizeEdge.bottomLeft => Positioned(
          left: 0,
          bottom: 0,
          width: corner,
          height: corner,
          child: handle,
        ),
      ResizeEdge.bottomRight => Positioned(
          right: 0,
          bottom: 0,
          width: corner,
          height: corner,
          child: handle,
        ),
    };
  }
}

/// Shows a minimized window in its dock slot.
class _DockItem extends StatelessWidget {
  const _DockItem({
    super.key,
    required this.window,
    required this.stackSize,
    required this.textDirection,
    required this.blocked,
    required this.builder,
  });

  final WindowEntry window;
  final Size stackSize;
  final TextDirection textDirection;
  final bool blocked;
  final MinimizedWindowBuilder builder;

  @override
  Widget build(BuildContext context) {
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    final Rect rect = dockSlotRect(
      window._dockSlot ?? 0,
      stackSize: stackSize,
      itemSize: theme.minimizedSize!,
      padding: theme.dockPadding!,
      spacing: theme.dockSpacing!,
      textDirection: textDirection,
    );
    return Positioned.fromRect(
      rect: rect,
      child: ExcludeFocus(
        excluding: blocked,
        child: _WindowEntryScope(
          window: window,
          child: Builder(
            builder: (BuildContext context) => builder(context, window),
          ),
        ),
      ),
    );
  }
}
