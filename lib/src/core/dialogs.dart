part of '../core.dart';

/// A dialog waiting in a window's or a stack's dialog stack.
class _DialogRequest<T> {
  _DialogRequest({
    required this.owner,
    required this.builder,
    required this.barrierDismissible,
    required this.barrierColor,
    required this.barrierLabel,
  });

  final _DialogStack owner;
  final WidgetBuilder builder;
  final bool barrierDismissible;
  final Color? barrierColor;
  final String? barrierLabel;

  final Completer<T?> _completer = Completer<T?>();

  /// The widget that had focus when the dialog opened.
  FocusNode? _previousFocus;

  /// The route hosting the dialog's content in the currently mounted layer.
  _WindowDialogRoute<T>? _route;

  /// The focus scope around the dialog's content, owned by the mounted layer.
  FocusScopeNode? _focusScope;

  // Resolved from the stack's theme by the layer before the route builds.
  Color? _themeBarrierColor;
  String _themeBarrierLabel = const WindowStackLabels().dismiss;
  Duration _entranceDuration = Duration.zero;

  Future<T?> get future => _completer.future;

  void _complete(Object? result) {
    if (!_completer.isCompleted) {
      _completer.complete(result as T?);
    }
  }

  _WindowDialogRoute<T> _attachRoute() {
    return _route = _WindowDialogRoute<T>(this);
  }

  void _detachRoute(_WindowDialogRoute<Object?> route) {
    if (identical(_route, route)) {
      _route = null;
    }
  }
}

/// A last-in, first-out stack of dialogs, owned by a window or a stack.
class _DialogStack {
  _DialogStack({
    required this.onChanged,
    required this.canTakeFocus,
    required this.focusFallback,
    this.ownsFocus,
  });

  /// Called when a dialog opens or closes.
  final VoidCallback onChanged;

  /// Whether a newly shown dialog should take keyboard focus right away.
  final bool Function() canTakeFocus;

  /// Moves focus somewhere sensible when the widget focused before a closed
  /// dialog no longer exists.
  final VoidCallback focusFallback;

  /// Whether focus may return to [node] when a dialog closes. A window's
  /// dialogs only return focus to widgets inside that window.
  final bool Function(FocusNode node)? ownsFocus;

  final List<_DialogRequest<Object?>> _requests = <_DialogRequest<Object?>>[];

  /// The open dialogs, bottom to top. Do not modify.
  List<_DialogRequest<Object?>> get requests => _requests;

  bool get isEmpty => _requests.isEmpty;

  bool get isNotEmpty => _requests.isNotEmpty;

  int get length => _requests.length;

  /// The focus scope of the top dialog, if it is mounted.
  FocusScopeNode? get topFocusScope {
    return _requests.isEmpty ? null : _requests.last._focusScope;
  }

  Future<T?> push<T>(_DialogRequest<T> request) {
    request._previousFocus = FocusManager.instance.primaryFocus;
    _requests.add(request);
    onChanged();
    return request.future;
  }

  bool pop(Object? result) {
    if (_requests.isEmpty) {
      return false;
    }
    complete(_requests.last, result);
    return true;
  }

  void complete(_DialogRequest<Object?> request, Object? result) {
    if (!_requests.contains(request)) {
      return;
    }
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    final FocusScopeNode? scope = request._focusScope;
    // Only move focus back if it was inside the dialog. A dialog closed from
    // code while the user works elsewhere must not steal focus.
    final bool hadFocus = focus == null || (scope != null && scope.hasFocus);
    _requests.remove(request);
    request._complete(result);
    onChanged();
    if (hadFocus) {
      final FocusNode? previous = request._previousFocus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final bool canRestore = previous != null &&
            (previous.context?.mounted ?? false) &&
            previous.canRequestFocus &&
            (ownsFocus?.call(previous) ?? true);
        if (canRestore) {
          previous.requestFocus();
        } else {
          focusFallback();
        }
      });
    }
  }

  /// Completes every dialog with null without notifying.
  void clear() {
    final List<_DialogRequest<Object?>> pending = _requests.reversed.toList();
    _requests.clear();
    for (final _DialogRequest<Object?> request in pending) {
      request._complete(null);
    }
  }
}

/// Hosts a dialog's content inside the dialog's own [Navigator], so that
/// `Navigator.pop(context, result)` inside the dialog closes the dialog
/// instead of the page that holds the [WindowStack].
class _WindowDialogRoute<T> extends ModalRoute<T> {
  _WindowDialogRoute(this.request)
      : super(settings: const RouteSettings(name: 'window_stack_dialog'));

  final _DialogRequest<T> request;

  // This route is the only one in its Navigator, and popping the only route
  // of a Navigator would leave it empty. A local history entry makes a pop
  // remove the entry instead of the route, which also lets Escape, the
  // barrier and `Navigator.maybePop` pop it, as with `showDialog`. The
  // dialog then closes and its layer, with this Navigator, goes away.
  late final LocalHistoryEntry _closeEntry = LocalHistoryEntry(
    onRemove: () => _closeRequested = true,
  );
  bool _closeRequested = false;

  @override
  bool get opaque => false;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => request.barrierColor ?? request._themeBarrierColor;

  @override
  bool get barrierDismissible => request.barrierDismissible;

  @override
  String? get barrierLabel =>
      request.barrierLabel ?? request._themeBarrierLabel;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  void install() {
    super.install();
    addLocalHistoryEntry(_closeEntry);
  }

  @override
  bool didPop(T? result) {
    if (_closeRequested) {
      // A second pop arrived before the layer was removed.
      return false;
    }
    // Removes the newest local history entry. Entries added by the content,
    // such as an open drawer, are removed before the close entry.
    final bool popped = super.didPop(result);
    if (_closeRequested) {
      request.owner.complete(request, result);
    }
    return popped;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Centers widgets that do not position themselves. Material dialogs
    // fill the area and align themselves, through Dialog.alignment.
    final Widget dialog = Center(
      child: _DialogEntrance(
        duration: request._entranceDuration,
        child: Builder(builder: request.builder),
      ),
    );
    final FocusScopeNode? scope = request._focusScope;
    // The scope sits inside the route, below the route's handler for Escape.
    return scope == null ? dialog : FocusScope(node: scope, child: dialog);
  }
}

/// Fades and scales a dialog in when it first appears.
class _DialogEntrance extends StatelessWidget {
  const _DialogEntrance({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(scale: 0.95 + 0.05 * value, child: child),
        );
      },
    );
  }
}

/// Shows one dialog: its barrier and content, inside a dedicated [Navigator].
class _DialogLayer extends StatefulWidget {
  const _DialogLayer({super.key, required this.request});

  final _DialogRequest<Object?> request;

  @override
  State<_DialogLayer> createState() => _DialogLayerState();
}

class _DialogLayerState extends State<_DialogLayer> {
  late final _WindowDialogRoute<Object?> _route;
  final FocusScopeNode _focusScope = FocusScopeNode(
    debugLabel: 'Window dialog',
  );

  @override
  void initState() {
    super.initState();
    widget.request._focusScope = _focusScope;
    _route = widget.request._attachRoute();
    _focusScope.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.request.owner.canTakeFocus()) {
        _focusScope.requestFocus();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final WindowStackThemeData theme = WindowStackThemeData.of(context);
    widget.request
      .._themeBarrierColor = theme.barrierColor
      .._themeBarrierLabel = WindowStackLabels.of(context).dismiss
      .._entranceDuration = theme.animationDuration!;
  }

  @override
  void dispose() {
    widget.request._detachRoute(_route);
    if (identical(widget.request._focusScope, _focusScope)) {
      widget.request._focusScope = null;
    }
    _focusScope
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  /// A dialog on an inactive window must not take focus from the window the
  /// user works in, for example through an `autofocus` field. Hand focus
  /// back; the dialog gets it when its window is activated.
  void _onFocusChanged() {
    if (!_focusScope.hasFocus || widget.request.owner.canTakeFocus()) {
      return;
    }
    final FocusNode? previous = widget.request._previousFocus;
    if (previous != null &&
        (previous.context?.mounted ?? false) &&
        previous.canRequestFocus) {
      previous.requestFocus();
    } else {
      _focusScope.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      // The layer decides when the dialog takes focus, so a dialog shown on
      // an inactive window does not steal it.
      requestFocus: false,
      onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) {
        return <Route<dynamic>>[_route];
      },
    );
  }
}
