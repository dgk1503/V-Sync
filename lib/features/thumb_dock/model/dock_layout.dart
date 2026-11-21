import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show EdgeInsets;

/// What a finger is over while the Thumb Dock is open.
class DockHit {
  const DockHit.main(this.index) : isSub = false;
  const DockHit.sub(this.index) : isSub = true;

  /// Position in the main column (top to bottom) or, for a sub item, in the
  /// shortcut row that grows out of Academics.
  final int index;
  final bool isSub;

  @override
  bool operator ==(Object other) =>
      other is DockHit && other.index == index && other.isSub == isSub;

  @override
  int get hashCode => Object.hash(index, isSub);

  @override
  String toString() => isSub ? 'sub($index)' : 'main($index)';
}

/// Where everything sits while the dock is open, and what a finger is over.
///
/// Pure geometry, no widgets: the dock draws from it and hit-tests against it,
/// so what the user sees and what a touch means can never drift apart. The main
/// items form a column against the screen edge the dock lives on; Academics
/// opens a row of shortcuts inward from its own item.
class DockLayout {
  const DockLayout({
    required this.size,
    required this.padding,
    required this.rightSide,
    required this.handleY,
    required this.mainCount,
    required this.academicsIndex,
    required this.subCount,
  });

  final Size size;
  final EdgeInsets padding;
  final bool rightSide;

  /// Vertical centre of the handle, in screen pixels.
  final double handleY;
  final int mainCount;

  /// Which main item opens the shortcut row, or null when there is none.
  final int? academicsIndex;
  final int subCount;

  static const double itemSize = 48;
  static const double itemGap = 10;
  static const double subSize = 44;
  static const double subGap = 8;

  /// Gap between the Academics item and the first shortcut.
  static const double subLead = 14;

  /// Most shortcuts that still fit on a 360 dp wide phone.
  static const int maxSubs = 5;

  /// Distance from the screen edge to the centre of the main column.
  static const double columnInset = 46;

  /// Which way the shortcut row grows: away from the edge the dock is on.
  double get _inward => rightSide ? -1 : 1;

  double get columnX => rightSide ? size.width - columnInset : columnInset;

  double get columnHeight =>
      mainCount * itemSize + math.max(0, mainCount - 1) * itemGap;

  double get columnTop {
    final lo = padding.top + 56;
    final hi = size.height - padding.bottom - columnHeight - 24;
    return (handleY - columnHeight / 2).clamp(lo, math.max(lo, hi)).toDouble();
  }

  Offset mainCenter(int i) =>
      Offset(columnX, columnTop + itemSize / 2 + i * (itemSize + itemGap));

  Offset subCenter(int j) {
    final y = mainCenter(academicsIndex ?? 0).dy;
    final x =
        columnX +
        _inward *
            (itemSize / 2 + subLead + subSize / 2 + j * (subSize + subGap));
    return Offset(x, y);
  }

  /// What the finger at [p] is over. Shortcuts only count while their row is
  /// open ([subsOpen]).
  DockHit? hit(Offset p, {required bool subsOpen}) {
    if (subsOpen && academicsIndex != null && subCount > 0) {
      final row = mainCenter(academicsIndex!).dy;
      final fromColumn = _inward * (p.dx - columnX);
      if ((p.dy - row).abs() <= 30 && fromColumn > itemSize / 2 + 4) {
        var best = 0;
        var bestDistance = double.infinity;
        for (var j = 0; j < subCount; j++) {
          final d = (p.dx - subCenter(j).dx).abs();
          if (d < bestDistance) {
            bestDistance = d;
            best = j;
          }
        }
        if (bestDistance <= subSize / 2 + subGap / 2 + 4) {
          return DockHit.sub(best);
        }
        return null;
      }
    }

    if ((p.dx - columnX).abs() > 46) return null;
    final top = columnTop - 12;
    final bottom = columnTop + columnHeight + 12;
    if (p.dy < top || p.dy > bottom) return null;
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < mainCount; i++) {
      final d = (p.dy - mainCenter(i).dy).abs();
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return DockHit.main(best);
  }
}
