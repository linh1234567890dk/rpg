import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

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
  void render(Canvas canvas) {
    if (!isVisible) return;
    super.render(canvas);
  }
}
