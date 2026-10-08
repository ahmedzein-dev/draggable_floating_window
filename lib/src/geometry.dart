import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The edge or corner of a window that a resize gesture drags.
///
/// Internal to the package: apps resize windows through the window chrome or
/// `WindowEntry.setBounds`.
enum ResizeEdge {
  /// The left edge.
  left(movesLeft: true),

  /// The top edge.
  top(movesTop: true),

  /// The right edge.
  right(movesRight: true),

  /// The bottom edge.
  bottom(movesBottom: true),

  /// The top-left corner.
  topLeft(movesLeft: true, movesTop: true),

  /// The top-right corner.
  topRight(movesRight: true, movesTop: true),

  /// The bottom-left corner.
  bottomLeft(movesLeft: true, movesBottom: true),

  /// The bottom-right corner.
  bottomRight(movesRight: true, movesBottom: true);

  const ResizeEdge({
    this.movesLeft = false,
    this.movesTop = false,
    this.movesRight = false,
    this.movesBottom = false,
  });

  /// Whether this handle moves the left edge.
  final bool movesLeft;

  /// Whether this handle moves the top edge.
  final bool movesTop;

  /// Whether this handle moves the right edge.
  final bool movesRight;

  /// Whether this handle moves the bottom edge.
  final bool movesBottom;
}

/// Returns [rect] moved, and shrunk if needed, so that it lies inside [bounds].
///
/// Never throws: when [rect] is larger than [bounds] it is shrunk to the
/// bounds' size and pinned to their top-left corner.
Rect fitRectInBounds(Rect rect, Rect bounds) {
  final double width = math.max(0, math.min(rect.width, bounds.width));
  final double height = math.max(0, math.min(rect.height, bounds.height));
  final double left = rect.left.clamp(bounds.left, bounds.right - width);
  final double top = rect.top.clamp(bounds.top, bounds.bottom - height);
  return Rect.fromLTWH(left, top, width, height);
}

/// Resizes [start] by dragging [edge] by [delta].
///
/// Only the edges named by [edge] move, so dragging the right edge never
/// changes the height. The result respects [minSize] and [maxSize] and never
/// leaves [bounds]; when the bounds are too small for [minSize], the bounds win.
Rect resizeRect(
  Rect start,
  ResizeEdge edge,
  Offset delta, {
  required Size minSize,
  Size? maxSize,
  required Rect bounds,
}) {
  final double minWidth = math.min(minSize.width, bounds.width);
  final double minHeight = math.min(minSize.height, bounds.height);
  final double maxWidth = math.max(minWidth, maxSize?.width ?? double.infinity);
  final double maxHeight = math.max(
    minHeight,
    maxSize?.height ?? double.infinity,
  );

  double left = start.left;
  double top = start.top;
  double right = start.right;
  double bottom = start.bottom;

  if (edge.movesLeft) {
    left = start.left + delta.dx;
    left = math.min(left, right - minWidth);
    left = math.max(left, right - maxWidth);
    left = math.max(left, bounds.left);
  } else if (edge.movesRight) {
    right = start.right + delta.dx;
    right = math.max(right, left + minWidth);
    right = math.min(right, left + maxWidth);
    right = math.min(right, bounds.right);
  }

  if (edge.movesTop) {
    top = start.top + delta.dy;
    top = math.min(top, bottom - minHeight);
    top = math.max(top, bottom - maxHeight);
    top = math.max(top, bounds.top);
  } else if (edge.movesBottom) {
    bottom = start.bottom + delta.dy;
    bottom = math.max(bottom, top + minHeight);
    bottom = math.min(bottom, top + maxHeight);
    bottom = math.min(bottom, bounds.bottom);
  }

  return Rect.fromLTRB(left, top, right, bottom);
}

/// Returns the rectangle of dock slot [slot] for a minimized window.
///
/// Slots fill the bottom row first, starting at the leading edge (left in
/// left-to-right layouts), and wrap upward when a row is full.
Rect dockSlotRect(
  int slot, {
  required Size stackSize,
  required Size itemSize,
  required EdgeInsets padding,
  required double spacing,
  required TextDirection textDirection,
}) {
  final double usableWidth = math.max(0, stackSize.width - padding.horizontal);
  final double itemWidth = math.min(itemSize.width, usableWidth);
  final int perRow = math.max(
    1,
    ((usableWidth + spacing) / (itemWidth + spacing)).floor(),
  );
  final int row = slot ~/ perRow;
  final int column = slot % perRow;
  final double offset = column * (itemWidth + spacing);
  final double left = switch (textDirection) {
    TextDirection.ltr => padding.left + offset,
    TextDirection.rtl => stackSize.width - padding.right - offset - itemWidth,
  };
  final double top = math.max(
    padding.top,
    stackSize.height -
        padding.bottom -
        itemSize.height -
        row * (itemSize.height + spacing),
  );
  return Rect.fromLTWH(left, top, itemWidth, itemSize.height);
}
