import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'player.dart';

class EnemyAttackEffect extends PositionComponent with HasGameReference, CollisionCallbacks {
  final Vector2 direction;
  double lifeTime = 0.2;
  double timer = 0;
  double damage;

  EnemyAttackEffect({required Vector2 position, required this.direction, this.damage = 10}) 
      : super(position: position, size: Vector2(50, 60), anchor: Anchor.centerLeft) {
    // Xoay vệt chém theo hướng về phía người chơi
    angle = direction.angleToSigned(Vector2(1, 0)) * -1;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    
    // Hiệu ứng vệt chém màu đỏ mờ đại diện cho đòn đánh của quái
    add(RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.red.withAlpha(150),
    ));
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
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Player) {
      other.takeDamage(damage, knockbackDirection: direction);
    }
  }
}
