import 'dart:math' as math;
import 'dart:ui' show Rect, Offset;
import 'package:flame/components.dart';

/// Cấu hình kích thước thế giới và utilities wrapping
class WorldConfig {
  static const double worldWidth = 16000;
  static const double worldHeight = 10000;

  /// Wrap position vào trong [0, worldWidth] × [0, worldHeight]
  static Vector2 wrapPosition(Vector2 pos) {
    double x = pos.x % worldWidth;
    if (x < 0) x += worldWidth;
    double y = pos.y % worldHeight;
    if (y < 0) y += worldHeight;
    return Vector2(x, y);
  }

  /// Khoảng cách ngắn nhất có tính wrapping
  static double wrappedDistance(Vector2 a, Vector2 b) {
    double dx = (b.x - a.x).abs();
    dx = math.min(dx, worldWidth - dx);
    double dy = (b.y - a.y).abs();
    dy = math.min(dy, worldHeight - dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Hướng ngắn nhất từ `from` đến `to` có tính wrapping
  static Vector2 wrappedDirection(Vector2 from, Vector2 to) {
    double dx = to.x - from.x;
    double dy = to.y - from.y;
    if (dx.abs() > worldWidth / 2) {
      dx = -dx.sign * (worldWidth - dx.abs());
    }
    if (dy.abs() > worldHeight / 2) {
      dy = -dy.sign * (worldHeight - dy.abs());
    }
    return Vector2(dx, dy).normalized();
  }

  /// Kiểm tra xem viewport có cần render ghost copy ở phía đối diện không
  /// Trả về danh sách các offset cần render thêm
  static List<Vector2> getWrappedOffsets(Rect viewport) {
    final offsets = <Vector2>[];
    
    // Nếu viewport tràn qua mép trái
    if (viewport.left < 0) {
      offsets.add(Vector2(worldWidth, 0));
    }
    // Nếu viewport tràn qua mép phải
    if (viewport.right > worldWidth) {
      offsets.add(Vector2(-worldWidth, 0));
    }
    // Nếu viewport tràn qua mép trên
    if (viewport.top < 0) {
      offsets.add(Vector2(0, worldHeight));
    }
    // Nếu viewport tràn qua mép dưới
    if (viewport.bottom > worldHeight) {
      offsets.add(Vector2(0, -worldHeight));
    }
    // Góc (cả 2 chiều)
    if (viewport.left < 0 && viewport.top < 0) {
      offsets.add(Vector2(worldWidth, worldHeight));
    }
    if (viewport.right > worldWidth && viewport.top < 0) {
      offsets.add(Vector2(-worldWidth, worldHeight));
    }
    if (viewport.left < 0 && viewport.bottom > worldHeight) {
      offsets.add(Vector2(worldWidth, -worldHeight));
    }
    if (viewport.right > worldWidth && viewport.bottom > worldHeight) {
      offsets.add(Vector2(-worldWidth, -worldHeight));
    }
    
    return offsets;
  }

  /// Lấy viewport mở rộng (bao gồm cả phần wrap) để render
  static List<Rect> getWrappedViewports(Rect viewport) {
    final viewports = <Rect>[viewport];
    final offsets = getWrappedOffsets(viewport);
    for (final offset in offsets) {
      viewports.add(viewport.shift(Offset(offset.x, offset.y)));
    }
    return viewports;
  }
}