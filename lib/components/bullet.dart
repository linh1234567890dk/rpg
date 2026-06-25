import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import 'package:rpg/components/player.dart';
import 'enemy.dart';
import '../utils/world_config.dart';

class Bullet extends PositionComponent
    with HasGameReference, CollisionCallbacks {
  final Vector2 direction;
  double speed = 400.0;
  double damage;
  Color color = Colors.yellow;
  double lifetime = 3.0; // Đạn tự hủy sau 3 giây

  Bullet({required Vector2 position, required this.direction, Color? color, this.damage = 20.0})
    : super(position: position, size: Vector2.all(10), anchor: Anchor.center) {
    if (color != null) this.color = color;
  }

  @override
  Future<void> onLoad() async {
    add(CircleComponent(radius: size.x / 2, paint: Paint()..color = color));
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(direction * speed * dt);

    // Wrap position
    position = WorldConfig.wrapPosition(position);

    // Tự hủy sau 3 giây
    lifetime -= dt;
    if (lifetime <= 0) {
      removeFromParent();
    }
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);

    // Ghost copies khi gần mép
    final threshold = 600.0;
    if (position.x < threshold) {
      canvas.save();
      canvas.translate(WorldConfig.worldWidth, 0);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.x > WorldConfig.worldWidth - threshold) {
      canvas.save();
      canvas.translate(-WorldConfig.worldWidth, 0);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.y < threshold) {
      canvas.save();
      canvas.translate(0, WorldConfig.worldHeight);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.y > WorldConfig.worldHeight - threshold) {
      canvas.save();
      canvas.translate(0, -WorldConfig.worldHeight);
      super.renderTree(canvas);
      canvas.restore();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // Nếu đạn của người chơi (màu vàng) chạm quái
    if (color == Colors.yellow && other is Enemy) {
      other.takeDamage(damage, knockbackDirection: direction);
      removeFromParent();
    }

    // Nếu đạn của quái (màu đỏ hoặc cam) chạm người chơi
    if (color != Colors.yellow && other is Player) {
      other.takeDamage(damage / 2, knockbackDirection: direction);
      removeFromParent();
    }
  }
}
