import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';
import '../utils/world_config.dart';

class MeleeSlash extends PositionComponent
    with HasGameReference, CollisionCallbacks {
  final Vector2 direction;
  final double damage;
  double lifeTime = 0.2; // Hiệu ứng biến mất rất nhanh
  double timer = 0;

  MeleeSlash({required Vector2 position, required this.direction, this.damage = 30.0})
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
    position = WorldConfig.wrapPosition(position);
    timer += dt;
    if (timer >= lifeTime) {
      removeFromParent();
    }
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);
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

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Enemy) {
      other.takeDamage(damage, knockbackDirection: direction);
    }
  }
}
