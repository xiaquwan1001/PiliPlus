import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:collection/collection.dart';
import 'package:flutter/rendering.dart' show Offset, Size;
import 'package:nativeapi/nativeapi.dart' as nativeapi;
import 'package:screen_retriever/screen_retriever.dart';

const _displayManager = nativeapi.DisplayManager.instance;

nativeapi.Rectangle calcWindowBounds() {
  final windowSize = Pref.windowSize;
  final offset = calcWindowPosition(windowSize);
  return nativeapi.Rectangle(
    x: offset.dx,
    y: offset.dy,
    width: offset.width,
    height: offset.height,
  );
}

/// 恢复窗口位置时同步裁剪尺寸到显示器 workArea，避免窗口（尤其是历史遗留
/// 的全屏尺寸）压在 phosh 等面板占用的独占区下面。
({double dx, double dy, double width, double height}) _clampToWorkArea(
  nativeapi.Rectangle workArea,
  Size windowSize,
  Offset position,
) {
  final double width = windowSize.width.clamp(0.0, workArea.width);
  final double height = windowSize.height.clamp(0.0, workArea.height);
  final double dx = position.dx.clamp(
    workArea.x,
    workArea.x + workArea.width - width,
  );
  final double dy = position.dy.clamp(
    workArea.y,
    workArea.y + workArea.height - height,
  );
  return (dx: dx, dy: dy, width: width, height: height);
}

Offset calcWindowPosition(Size windowSize) {
  final displays = _displayManager.getAll();
  final cursorPosition = _displayManager.getCursorPosition().toOffset();

  final currentDisplay =
      displays.firstWhereOrNull(
        (display) => (display.position.toOffset() & display.size.toSize())
            .contains(cursorPosition),
      ) ??
      _displayManager.getPrimary();

  if (currentDisplay == null) return .zero;

  final workArea = currentDisplay.workArea;

  final windowPosition = Pref.windowPosition;
  if (windowPosition != null) {
    try {
      final dx = windowPosition[0];
      final dy = windowPosition[1];
      if (dx >= 0 && dy >= 0) {
        final clamped = _clampToWorkArea(workArea, windowSize, Offset(dx, dy));
        return Offset(clamped.dx, clamped.dy);
      }
    } catch (_) {}
  }

  final center = _clampToWorkArea(
    workArea,
    windowSize,
    Offset(
      workArea.x + (workArea.width - windowSize.width) / 2,
      workArea.y + (workArea.height - windowSize.height) / 2,
    ),
  );
  return Offset(center.dx, center.dy);
}
