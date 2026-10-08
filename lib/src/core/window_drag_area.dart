part of '../core.dart';

/// Makes [child] a handle that moves the enclosing window when dragged.
///
/// The default [WindowTitleBar] wraps its title in a drag area. Use this
/// widget when you build your own title bar with
/// [WindowStackController.open]'s `titleBarBuilder` or
/// [WindowStack.titleBarBuilder], or to let a toolbar inside the content move
/// the window as well.
///
/// Double-clicking the area maximizes or restores the window when
/// [maximizeOnDoubleTap] is true and the window is maximizable. Keep buttons
/// outside the drag area: a double-tap detector delays the taps of buttons
/// inside it.
///
/// ```dart
/// controller.open(
///   title: 'Player',
///   builder: (context) => const Player(),
///   titleBarBuilder: (context, window) => Row(
///     children: [
///       Expanded(
///         child: WindowDragArea(
///           child: Padding(
///             padding: const EdgeInsets.all(8),
///             child: Text(window.title),
///           ),
///         ),
///       ),
///       const WindowControls(),
///     ],
///   ),
/// );
/// ```
///
/// Outside a window, the drag area does nothing.
class WindowDragArea extends StatelessWidget {
  /// Creates a drag area around [child].
  const WindowDragArea({
    super.key,
    required this.child,
    this.maximizeOnDoubleTap = true,
  });

  /// The widget that moves the window when dragged.
  final Widget child;

  /// Whether double-clicking the area maximizes or restores the window.
  final bool maximizeOnDoubleTap;

  @override
  Widget build(BuildContext context) {
    final WindowEntry? window =
        context.getInheritedWidgetOfExactType<_WindowEntryScope>()?.window;
    if (window == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onPanStart: window.draggable
          ? (DragStartDetails details) =>
              window._startMove(details.globalPosition)
          : null,
      onPanUpdate: window.draggable
          ? (DragUpdateDetails details) =>
              window._updateMove(details.globalPosition)
          : null,
      onPanEnd: window.draggable
          ? (DragEndDetails details) => window._endInteraction()
          : null,
      onPanCancel: window.draggable ? window._endInteraction : null,
      onDoubleTap: maximizeOnDoubleTap && window.maximizable
          ? window.toggleMaximize
          : null,
      child: child,
    );
  }
}
