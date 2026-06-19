import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class DashAfterImage extends RectangleComponent {
  DashAfterImage({
    required Vector2 position,
    required Vector2 size,
  }) : super(
          position: position,
          size: size,
          anchor: Anchor.center,
          paint: Paint()..color = Colors.cyan.withAlpha(100),
        );

  @override
  Future<void> onLoad() async {
    // Hiệu ứng mờ dần và biến mất
    add(OpacityEffect.fadeOut(
      EffectController(duration: 0.3),
      onComplete: () => removeFromParent(),
    ));
    
    // Thu nhỏ dần một chút để tạo cảm giác tan biến
    add(ScaleEffect.to(
      Vector2.all(0.8),
      EffectController(duration: 0.3),
    ));
  }
}
