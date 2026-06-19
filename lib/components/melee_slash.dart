import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';

class MeleeSlash extends PositionComponent
    with HasGameReference, CollisionCallbacks {
  final Vector2 direction;
  double lifeTime = 0.2; // Hiệu ứng biến mất rất nhanh
  double timer = 0;

  MeleeSlash({required Vector2 position, required this.direction})
    : super(
        position: position,
        size: Vector2(60, 80),
        anchor: Anchor.centerLeft,
      ) {
    // Xoay vùng chém theo hướng nhắm
    angle = direction.angleToSigned(Vector2(1, 0)) * -1;
  }

  @override
  Future<void> onLoad() async {
    // Vùng va chạm hình chữ nhật phía trước nhân vật
    add(RectangleHitbox());

    // Hiệu ứng hình ảnh vệt chém (tạm thời dùng màu trắng mờ)
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.white.withAlpha(100),
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    timer += dt;
    if (timer >= lifeTime) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      other.takeDamage(30, knockbackDirection: direction); // Sát thương cận chiến thường cao hơn bắn xa
    }
  }
}
