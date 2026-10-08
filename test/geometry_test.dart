import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_stack/src/geometry.dart';
import 'package:window_stack/window_stack.dart';

void main() {
  const Rect bounds = Rect.fromLTWH(0, 0, 1000, 800);

  group('fitRectInBounds', () {
    test('keeps a rectangle that already fits', () {
      const Rect rect = Rect.fromLTWH(100, 100, 300, 200);
      expect(fitRectInBounds(rect, bounds), rect);
    });

    test('moves a rectangle back inside every edge', () {
      expect(
        fitRectInBounds(const Rect.fromLTWH(-50, -20, 300, 200), bounds),
        const Rect.fromLTWH(0, 0, 300, 200),
      );
      expect(
        fitRectInBounds(const Rect.fromLTWH(900, 700, 300, 200), bounds),
        const Rect.fromLTWH(700, 600, 300, 200),
      );
    });

    test('shrinks a rectangle larger than the bounds instead of throwing', () {
      expect(
        fitRectInBounds(const Rect.fromLTWH(40, 40, 1500, 900), bounds),
        const Rect.fromLTWH(0, 0, 1000, 800),
      );
    });
  });

  group('resizeRect', () {
    const Rect start = Rect.fromLTWH(200, 200, 400, 300);
    const Size minSize = Size(240, 160);

    Rect resize(ResizeEdge edge, Offset delta, {Size? maxSize}) {
      return resizeRect(
        start,
        edge,
        delta,
        minSize: minSize,
        maxSize: maxSize,
        bounds: bounds,
      );
    }

    test('an edge moves only its own axis', () {
      expect(
        resize(ResizeEdge.right, const Offset(50, 70)),
        const Rect.fromLTRB(200, 200, 650, 500),
      );
      expect(
        resize(ResizeEdge.bottom, const Offset(50, 70)),
        const Rect.fromLTRB(200, 200, 600, 570),
      );
      expect(
        resize(ResizeEdge.left, const Offset(-30, 70)),
        const Rect.fromLTRB(170, 200, 600, 500),
      );
      expect(
        resize(ResizeEdge.top, const Offset(50, -40)),
        const Rect.fromLTRB(200, 160, 600, 500),
      );
    });

    test('a corner moves both axes', () {
      expect(
        resize(ResizeEdge.topLeft, const Offset(-20, -30)),
        const Rect.fromLTRB(180, 170, 600, 500),
      );
      expect(
        resize(ResizeEdge.bottomRight, const Offset(20, 30)),
        const Rect.fromLTRB(200, 200, 620, 530),
      );
      expect(
        resize(ResizeEdge.topRight, const Offset(20, -30)),
        const Rect.fromLTRB(200, 170, 620, 500),
      );
      expect(
        resize(ResizeEdge.bottomLeft, const Offset(-20, 30)),
        const Rect.fromLTRB(180, 200, 600, 530),
      );
    });

    test('respects the minimum size, keeping the opposite edge fixed', () {
      expect(
        resize(ResizeEdge.left, const Offset(500, 0)),
        const Rect.fromLTRB(360, 200, 600, 500),
      );
      expect(
        resize(ResizeEdge.bottom, const Offset(0, -500)),
        const Rect.fromLTRB(200, 200, 600, 360),
      );
    });

    test('respects the maximum size', () {
      expect(
        resize(
          ResizeEdge.right,
          const Offset(300, 0),
          maxSize: const Size(500, 400),
        ),
        const Rect.fromLTRB(200, 200, 700, 500),
      );
    });

    test('never leaves the bounds', () {
      expect(
        resize(ResizeEdge.topLeft, const Offset(-900, -900)),
        const Rect.fromLTRB(0, 0, 600, 500),
      );
      expect(
        resize(ResizeEdge.bottomRight, const Offset(900, 900)),
        const Rect.fromLTRB(200, 200, 1000, 800),
      );
    });

    test('lets the bounds win when they are smaller than the minimum', () {
      const Rect tiny = Rect.fromLTWH(0, 0, 200, 100);
      final Rect result = resizeRect(
        const Rect.fromLTWH(0, 0, 150, 80),
        ResizeEdge.bottomRight,
        const Offset(500, 500),
        minSize: minSize,
        bounds: tiny,
      );
      expect(result, tiny);
    });
  });

  group('dockSlotRect', () {
    Rect slot(int index, {TextDirection direction = TextDirection.ltr}) {
      return dockSlotRect(
        index,
        stackSize: const Size(650, 500),
        itemSize: const Size(200, 40),
        padding: const EdgeInsets.all(10),
        spacing: 10,
        textDirection: direction,
      );
    }

    test('fills the bottom row from the leading edge', () {
      expect(slot(0), const Rect.fromLTWH(10, 450, 200, 40));
      expect(slot(1), const Rect.fromLTWH(220, 450, 200, 40));
      expect(slot(2), const Rect.fromLTWH(430, 450, 200, 40));
    });

    test('wraps upward when a row is full', () {
      expect(slot(3), const Rect.fromLTWH(10, 400, 200, 40));
    });

    test('starts at the right edge in right-to-left layouts', () {
      expect(
        slot(0, direction: TextDirection.rtl),
        const Rect.fromLTWH(440, 450, 200, 40),
      );
      expect(
        slot(1, direction: TextDirection.rtl),
        const Rect.fromLTWH(230, 450, 200, 40),
      );
    });
  });

  group('WindowPlacement', () {
    const Size size = Size(400, 300);

    test('center centers every window', () {
      const WindowPlacement placement = WindowPlacement.center();
      expect(placement.place(size, bounds, const <Rect>[]),
          const Offset(300, 250));
      expect(
        placement.place(size, bounds, const <Rect>[
          Rect.fromLTWH(300, 250, 400, 300),
        ]),
        const Offset(300, 250),
      );
    });

    test('cascade offsets windows that would land on an occupied spot', () {
      const WindowPlacement placement = WindowPlacement.cascade(
        step: Offset(20, 20),
      );
      expect(placement.place(size, bounds, const <Rect>[]),
          const Offset(300, 250));
      expect(
        placement.place(size, bounds, const <Rect>[
          Rect.fromLTWH(300, 250, 400, 300),
        ]),
        const Offset(320, 270),
      );
      expect(
        placement.place(size, bounds, const <Rect>[
          Rect.fromLTWH(300, 250, 400, 300),
          Rect.fromLTWH(320, 270, 400, 300),
        ]),
        const Offset(340, 290),
      );
    });

    test('cascade restarts at the top-left corner instead of overflowing', () {
      const WindowPlacement placement = WindowPlacement.cascade(
        step: Offset(300, 300),
      );
      expect(
        placement.place(size, bounds, const <Rect>[
          Rect.fromLTWH(300, 250, 400, 300),
        ]),
        Offset.zero,
      );
    });
  });
}
