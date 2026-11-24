import 'dart:math';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/skeleton/video_card_h.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

mixin GridMixin<T extends StatefulWidget> on State<T> {
  late final gridDelegate = Grid.videoCardHDelegate(context);

  Widget get gridSkeleton => SliverGrid.builder(
    gridDelegate: gridDelegate,
    itemBuilder: (_, _) => const VideoCardHSkeleton(),
    itemCount: 10,
  );
}

abstract class Grid {
  static final double smallCardWidth = Pref.smallCardWidth;

  /// H 卡片瓦片宽度下限：至少留 180dp 文字区。
  ///
  /// 封面宽度不是固定值：瓦片高度由 [childAspectRatio] 决定，封面宽 = 高 ×
  /// [StyleString.aspectRatio]，因此封面占瓦片宽的比例恒为
  /// `aspectRatio / childAspectRatio`。窄窗口（480~700dp：平板竖屏、分屏、
  /// 小窗）若只按 maxCrossAxisExtent 算列数，会得到两列 ~317dp 的瓦片，
  /// 文字区只剩 ~150dp，播放数/弹幕数横向溢出被切掉。
  static double videoCardHMinWidth({
    required double minHeight,
    required double childAspectRatio,
    double crossAxisSpacing = 0,
  }) {
    const textMinWidth = 180.0;
    const padding = StyleString.safeSpace * 2;
    final fixed = padding + crossAxisSpacing + textMinWidth;
    // ① 瓦片高度按 childAspectRatio 缩放时，封面占宽比例恒定。
    final coverRatio = StyleString.aspectRatio / childAspectRatio;
    final byRatio = fixed / (1 - coverRatio);
    // ② 瓦片高度被 minHeight 托底（窄瓦片）时，封面宽固定。
    final byFloor = minHeight * StyleString.aspectRatio + fixed;
    return max(byFloor, byRatio);
  }

  static SliverGridDelegateWithExtentAndRatio videoCardHDelegate(
    BuildContext context, {
    double minHeight = 90,
  }) => SliverGridDelegateWithExtentAndRatio(
    mainAxisSpacing: 2,
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
    childAspectRatio: StyleString.aspectRatio * 2.2,
    minHeight: MediaQuery.textScalerOf(context).scale(minHeight),
    minCrossAxisExtent: videoCardHMinWidth(
      minHeight: MediaQuery.textScalerOf(context).scale(minHeight),
      childAspectRatio: StyleString.aspectRatio * 2.2,
    ),
  );
}

class SliverGridDelegateWithExtentAndRatio extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with tiles that have a maximum
  /// cross-axis extent.
  ///
  /// The [maxCrossAxisExtent], [mainAxisExtent], [mainAxisSpacing],
  /// and [crossAxisSpacing] arguments must not be negative.
  /// The [childAspectRatio] argument must be greater than zero.
  SliverGridDelegateWithExtentAndRatio({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent = 0.0,
    this.minHeight = 0.0,
    this.minCrossAxisExtent,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0),
       assert(minHeight >= 0),
       assert(minCrossAxisExtent == null || minCrossAxisExtent > 0);

  final double minHeight;

  /// 瓦片宽度下限；为 null 时只按 [maxCrossAxisExtent] 算列数。
  /// H 卡片左侧封面宽度由瓦片高度决定（固定 aspectRatio），瓦片一窄右侧
  /// 文字区就放不下播放数/弹幕数而横向溢出。
  final double? minCrossAxisExtent;

  /// The maximum extent of tiles in the cross axis.
  ///
  /// This delegate will select a cross-axis extent for the tiles that is as
  /// large as possible subject to the following conditions:
  ///
  ///  - The extent evenly divides the cross-axis extent of the grid.
  ///  - The extent is at most [maxCrossAxisExtent].
  ///
  /// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
  /// [maxCrossAxisExtent] is 150.0, this delegate will create a grid with 4
  /// columns that are 125.0 pixels wide.
  final double maxCrossAxisExtent;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// The extent of each tile in the main axis. If provided, it would add
  /// after [childAspectRatio] is used.
  final double mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(maxCrossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  SliverGridLayout? layoutCache;
  double? crossAxisExtentCache;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    // invoked before each frame
    assert(_debugAssertIsValid(constraints.crossAxisExtent));
    if (layoutCache != null &&
        constraints.crossAxisExtent == crossAxisExtentCache) {
      return layoutCache!;
    }
    crossAxisExtentCache = constraints.crossAxisExtent;
    int crossAxisCount =
        ((constraints.crossAxisExtent - crossAxisSpacing) /
                (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    if (minCrossAxisExtent case final minExtent?) {
      crossAxisCount = max(
        1,
        min(
          crossAxisCount,
          (constraints.crossAxisExtent / (minExtent + crossAxisSpacing))
              .floor(),
        ),
      );
    }
    final double usableCrossAxisExtent = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent = max(
      minHeight,
      childCrossAxisExtent / childAspectRatio + mainAxisExtent,
    );
    return layoutCache = SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithExtentAndRatio oldDelegate) {
    final flag =
        oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.mainAxisExtent != mainAxisExtent ||
        oldDelegate.minCrossAxisExtent != minCrossAxisExtent ||
        oldDelegate.minHeight != minHeight;
    if (flag) layoutCache = null;
    return flag;
  }
}

class SliverGridDelegateWithMaxCrossAxisExtent extends SliverGridDelegate {
  /// Creates a delegate that makes grid layouts with tiles that have a maximum
  /// cross-axis extent.
  ///
  /// The [maxCrossAxisExtent], [mainAxisExtent], [mainAxisSpacing],
  /// and [crossAxisSpacing] arguments must not be negative.
  /// The [childAspectRatio] argument must be greater than zero.
  SliverGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0.0,
    this.crossAxisSpacing = 0.0,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0),
       assert(mainAxisExtent == null || mainAxisExtent >= 0);

  /// The maximum extent of tiles in the cross axis.
  ///
  /// This delegate will select a cross-axis extent for the tiles that is as
  /// large as possible subject to the following conditions:
  ///
  ///  - The extent evenly divides the cross-axis extent of the grid.
  ///  - The extent is at most [maxCrossAxisExtent].
  ///
  /// For example, if the grid is vertical, the grid is 500.0 pixels wide, and
  /// [maxCrossAxisExtent] is 150.0, this delegate will create a grid with 4
  /// columns that are 125.0 pixels wide.
  final double maxCrossAxisExtent;

  /// The number of logical pixels between each child along the main axis.
  final double mainAxisSpacing;

  /// The number of logical pixels between each child along the cross axis.
  final double crossAxisSpacing;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// The extent of each tile in the main axis. If provided it would define the
  /// logical pixels taken by each tile in the main-axis.
  ///
  /// If null, [childAspectRatio] is used instead.
  final double? mainAxisExtent;

  bool _debugAssertIsValid(double crossAxisExtent) {
    assert(crossAxisExtent > 0.0);
    assert(maxCrossAxisExtent > 0.0);
    assert(mainAxisSpacing >= 0.0);
    assert(crossAxisSpacing >= 0.0);
    assert(childAspectRatio > 0.0);
    return true;
  }

  SliverGridLayout? layoutCache;
  double? crossAxisExtentCache;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    assert(_debugAssertIsValid(constraints.crossAxisExtent));
    if (layoutCache != null &&
        constraints.crossAxisExtent == crossAxisExtentCache) {
      return layoutCache!;
    }
    crossAxisExtentCache = constraints.crossAxisExtent;
    int crossAxisCount =
        (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing))
            .ceil();
    // Ensure a minimum count of 1, can be zero and result in an infinite extent
    // below when the window size is 0.
    crossAxisCount = max(1, crossAxisCount);
    final double usableCrossAxisExtent = max(
      0.0,
      constraints.crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1),
    );
    final double childCrossAxisExtent = usableCrossAxisExtent / crossAxisCount;
    final double childMainAxisExtent =
        mainAxisExtent ?? childCrossAxisExtent / childAspectRatio;
    return layoutCache = SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: childMainAxisExtent + mainAxisSpacing,
      crossAxisStride: childCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: childMainAxisExtent,
      childCrossAxisExtent: childCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithMaxCrossAxisExtent oldDelegate) {
    final flag =
        oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio ||
        oldDelegate.mainAxisExtent != mainAxisExtent;
    if (flag) layoutCache = null;
    return flag;
  }
}
