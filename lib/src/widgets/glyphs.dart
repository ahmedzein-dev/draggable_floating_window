import 'package:flutter/material.dart';

/// The symbols drawn on window buttons. Painted rather than taken from an icon
/// font, so the package works in apps that do not bundle Material icons.
enum WindowGlyph {
  /// A cross.
  close,

  /// A horizontal line.
  minimize,

  /// A square outline (Windows) or a plus (traffic lights).
  maximize,

  /// Two overlapping squares.
  restore,

  /// An upward chevron, used to restore a minimized window.
  restoreUp,
}

/// Paints a [WindowGlyph] in a square of [size].
class GlyphIcon extends StatelessWidget {
  /// Creates a glyph.
  const GlyphIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 10,
    this.strokeWidth = 1.2,
    this.plusForMaximize = false,
  });

  /// The symbol to paint.
  final WindowGlyph glyph;

  /// The stroke color.
  final Color color;

  /// The width and height of the glyph.
  final double size;

  /// The stroke width.
  final double strokeWidth;

  /// Whether [WindowGlyph.maximize] is drawn as a plus instead of a square.
  final bool plusForMaximize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(glyph, color, strokeWidth, plusForMaximize),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, this.strokeWidth, this.plus);

  final WindowGlyph glyph;
  final Color color;
  final double strokeWidth;
  final bool plus;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final double w = size.width;
    final double h = size.height;
    switch (glyph) {
      case WindowGlyph.close:
        canvas
          ..drawLine(Offset.zero, Offset(w, h), paint)
          ..drawLine(Offset(w, 0), Offset(0, h), paint);
      case WindowGlyph.minimize:
        canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
      case WindowGlyph.maximize:
        if (plus) {
          canvas
            ..drawLine(Offset(0, h / 2), Offset(w, h / 2), paint)
            ..drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
        } else {
          canvas.drawRect(Offset.zero & size, paint);
        }
      case WindowGlyph.restore:
        final double inset = w * 0.25;
        canvas
          ..drawRect(Rect.fromLTWH(0, inset, w - inset, h - inset), paint)
          ..drawPath(
            Path()
              ..moveTo(inset, inset)
              ..lineTo(inset, 0)
              ..lineTo(w, 0)
              ..lineTo(w, h - inset)
              ..lineTo(w - inset, h - inset),
            paint,
          );
      case WindowGlyph.restoreUp:
        canvas.drawPath(
          Path()
            ..moveTo(0, h * 0.7)
            ..lineTo(w / 2, h * 0.25)
            ..lineTo(w, h * 0.7),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) {
    return glyph != oldDelegate.glyph ||
        color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        plus != oldDelegate.plus;
  }
}

/// Wraps [child] in a [Tooltip] when an [Overlay] is available, and always in
/// button semantics with [label].
Widget labeledButton({
  required BuildContext context,
  required String label,
  required Widget child,
}) {
  final Widget button = Semantics(button: true, label: label, child: child);
  if (Overlay.maybeOf(context) == null) {
    return button;
  }
  return Tooltip(
    message: label,
    excludeFromSemantics: true,
    waitDuration: const Duration(milliseconds: 600),
    child: button,
  );
}
