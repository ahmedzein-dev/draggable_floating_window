import 'dart:math' as math;
import 'dart:ui';

/// Decides where a new window appears when `WindowStackController.open` is
/// called without a `position`.
///
/// Two strategies are built in:
///
/// * [WindowPlacement.cascade], the default: the first window is centered and
///   each following window is offset diagonally, so a new window never opens
///   exactly on top of an existing one.
/// * [WindowPlacement.center]: every window is centered.
///
/// Subclass [WindowPlacement] and override [place] for a custom strategy.
///
/// ```dart
/// final controller = WindowStackController(
///   placement: const WindowPlacement.cascade(step: Offset(32, 32)),
/// );
/// ```
abstract class WindowPlacement {
  /// Allows subclasses to have `const` constructors.
  const WindowPlacement();

  /// Centers every new window inside the stack.
  const factory WindowPlacement.center() = _CenterPlacement;

  /// Centers the first window, then moves each new window by [step] until it
  /// finds a spot whose top-left corner no other window uses. When a step
  /// would push the window out of the stack, cascading restarts from the
  /// stack's top-left corner.
  const factory WindowPlacement.cascade({Offset step}) = _CascadePlacement;

  /// Returns the top-left corner for a new window of [windowSize].
  ///
  /// [bounds] is the area of the stack. [occupied] holds the rectangles of the
  /// windows already shown in normal mode, bottom to top. The result is
  /// clamped into [bounds] afterwards.
  Offset place(Size windowSize, Rect bounds, List<Rect> occupied);
}

class _CenterPlacement extends WindowPlacement {
  const _CenterPlacement();

  @override
  Offset place(Size windowSize, Rect bounds, List<Rect> occupied) {
    return bounds.center - windowSize.center(Offset.zero);
  }
}

class _CascadePlacement extends WindowPlacement {
  const _CascadePlacement({this.step = const Offset(28, 28)});

  final Offset step;

  static const int _maxAttempts = 64;

  @override
  Offset place(Size windowSize, Rect bounds, List<Rect> occupied) {
    // The rectangle that the window's top-left corner may occupy.
    final Rect area = Rect.fromLTRB(
      bounds.left,
      bounds.top,
      math.max(bounds.left, bounds.right - windowSize.width),
      math.max(bounds.top, bounds.bottom - windowSize.height),
    );
    Offset clampToArea(Offset offset) => Offset(
          offset.dx.clamp(area.left, area.right),
          offset.dy.clamp(area.top, area.bottom),
        );
    bool isTaken(Offset offset) =>
        occupied.any((Rect rect) => (rect.topLeft - offset).distance < 1);

    Offset candidate = clampToArea(
      bounds.center - windowSize.center(Offset.zero),
    );
    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      if (!isTaken(candidate)) {
        return candidate;
      }
      final Offset next = candidate + step;
      final bool fits = next.dx >= area.left &&
          next.dx <= area.right &&
          next.dy >= area.top &&
          next.dy <= area.bottom;
      candidate = fits ? next : area.topLeft;
    }
    return candidate;
  }
}
