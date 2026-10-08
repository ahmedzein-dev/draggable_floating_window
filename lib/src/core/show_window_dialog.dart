part of '../core.dart';

/// Shows a dialog in the window that encloses [context] and returns the value
/// it is closed with.
///
/// Inside a window's content, title bar or dialogs, this calls
/// [WindowEntry.showDialog]: the dialog blocks only that window. Elsewhere
/// inside a [WindowStack], such as its [WindowStack.child], it calls
/// [WindowStackController.showDialog]: the dialog blocks every window.
///
/// The arguments match Flutter's `showDialog`, and the dialog closes with
/// `Navigator.pop(context, result)` the same way, so existing dialog widgets
/// such as [AlertDialog] work unchanged:
///
/// ```dart
/// final bool? delete = await showWindowDialog<bool>(
///   context: context,
///   builder: (context) => AlertDialog(
///     title: const Text('Delete this task?'),
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.pop(context, false),
///         child: const Text('Cancel'),
///       ),
///       FilledButton(
///         onPressed: () => Navigator.pop(context, true),
///         child: const Text('Delete'),
///       ),
///     ],
///   ),
/// );
/// ```
///
/// Throws when [context] is not inside a [WindowStack].
Future<T?> showWindowDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
}) {
  final WindowEntry? window =
      context.getInheritedWidgetOfExactType<_WindowEntryScope>()?.window;
  if (window != null) {
    return window.showDialog<T>(
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
    );
  }
  final WindowStackController? controller =
      context.getInheritedWidgetOfExactType<_WindowStackScope>()?.controller;
  if (controller == null) {
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary('showWindowDialog() called outside a WindowStack.'),
      ErrorDescription(
        'showWindowDialog() shows dialogs in the window, or the WindowStack, '
        'that encloses the given context. No WindowStack encloses it.',
      ),
      ErrorHint(
        "Use Flutter's showDialog() for dialogs outside a WindowStack.",
      ),
      context.describeElement('The context used was'),
    ]);
  }
  return controller.showDialog<T>(
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
  );
}
