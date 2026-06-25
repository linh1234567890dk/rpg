import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:rpg/utils/world_config.dart';

class TargetLockIndicator extends SpriteAnimationComponent with HasGameReference {
  TargetLockIndicator() : super(size: Vector2.all(50), anchor: Anchor.center);

  bool isVisible = false;

  @override
  Future<void> onLoad() async {
    // Tạm thời dùng RectangleComponent xoay tròn để làm indicator nếu chưa có sprite
    add(RectangleComponent(
      size: Vector2.all(45),
      anchor: Anchor.center,
      position: size / 2,
      paint: Paint()
        ..color = Colors.red.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    )..add(RotateEffect.by(
        6.28, // 360 độ
        EffectController(duration: 2, infinite: true),
      )));
    
    // Hiệu ứng đập nhẹ (Pulse)
    add(ScaleEffect.to(
      Vector2.all(1.2),
      EffectController(duration: 0.5, reverseDuration: 0.5, infinite: true),
    ));
  }

  @override
  void renderTree(Canvas canvas) {
    if (!isVisible) return;
    super.renderTree(canvas);

    // Ghost copies khi gần mép world
    final threshold = 600.0;
    if (position.x < threshold) {
      canvas.save(); canvas.translate(WorldConfig.worldWidth, 0); super.renderTree(canvas); canvas.restore();
    }
    if (position.x > WorldConfig.worldWidth - threshold) {
      canvas.save(); canvas.translate(-WorldConfig.worldWidth, 0); super.renderTree(canvas); canvas.restore();
    }
    if (position.y < threshold) {
      canvas.save(); canvas.translate(0, WorldConfig.worldHeight); super.renderTree(canvas); canvas.restore();
    }
    if (position.y > WorldConfig.worldHeight - threshold) {
      canvas.save(); canvas.translate(0, -WorldConfig.worldHeight); super.renderTree(canvas); canvas.restore();
    }
  }
}
