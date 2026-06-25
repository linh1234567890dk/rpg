import 'package:flame/components.dart';
import 'dart:ui' show Canvas;
import '../utils/world_config.dart';

/// Mixin cho phép PositionComponent tự động vẽ ghost copy khi ở gần mép world
/// Đảm bảo seamless wrapping: entity ở mép trái xuất hiện thêm bản copy ở mép phải
mixin WrappedRender on PositionComponent {
  /// Ngưỡng gần mép để bắt đầu vẽ ghost (tính bằng pixel)
  double get edgeThreshold => 600.0;

  @override
  void render(Canvas canvas) {
    // Vẽ entity chính
    _renderWithOffset(canvas, Vector2.zero());

    // Vẽ ghost copies nếu entity gần mép world
    if (position.x < edgeThreshold) {
      // Gần mép trái → vẽ ghost ở mép phải
      canvas.save();
      canvas.translate(WorldConfig.worldWidth, 0);
      _renderWithOffset(canvas, Vector2(WorldConfig.worldWidth, 0));
      canvas.restore();
    }
    if (position.x > WorldConfig.worldWidth - edgeThreshold) {
      // Gần mép phải → vẽ ghost ở mép trái
      canvas.save();
      canvas.translate(-WorldConfig.worldWidth, 0);
      _renderWithOffset(canvas, Vector2(-WorldConfig.worldWidth, 0));
      canvas.restore();
    }
    if (position.y < edgeThreshold) {
      // Gần mép trên → vẽ ghost ở mép dưới
      canvas.save();
      canvas.translate(0, WorldConfig.worldHeight);
      _renderWithOffset(canvas, Vector2(0, WorldConfig.worldHeight));
      canvas.restore();
    }
    if (position.y > WorldConfig.worldHeight - edgeThreshold) {
      // Gần mép dưới → vẽ ghost ở mép trên
      canvas.save();
      canvas.translate(0, -WorldConfig.worldHeight);
      _renderWithOffset(canvas, Vector2(0, -WorldConfig.worldHeight));
      canvas.restore();
    }
  }

  /// Vẽ entity tại vị trí với offset cho trước
  /// Subclass có thể override để custom render
  void _renderWithOffset(Canvas canvas, Vector2 offset) {
    // Mặc định: gọi super.render() từ PositionComponent
    // Vì không thể gọi super.render() trực tiếp trong mixin,
    // ta override ở mỗi entity
  }

  /// Gọi từ entity để thực hiện render chính + ghost
  void renderWrapped(Canvas canvas, void Function(Canvas) doRender) {
    doRender(canvas);

    // Ghost copies
    if (position.x < edgeThreshold) {
      canvas.save();
      canvas.translate(WorldConfig.worldWidth, 0);
      doRender(canvas);
      canvas.restore();
    }
    if (position.x > WorldConfig.worldWidth - edgeThreshold) {
      canvas.save();
      canvas.translate(-WorldConfig.worldWidth, 0);
      doRender(canvas);
      canvas.restore();
    }
    if (position.y < edgeThreshold) {
      canvas.save();
      canvas.translate(0, WorldConfig.worldHeight);
      doRender(canvas);
      canvas.restore();
    }
    if (position.y > WorldConfig.worldHeight - edgeThreshold) {
      canvas.save();
      canvas.translate(0, -WorldConfig.worldHeight);
      doRender(canvas);
      canvas.restore();
    }
  }
}