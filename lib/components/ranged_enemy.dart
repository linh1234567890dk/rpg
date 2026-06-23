import 'package:flutter/material.dart';
import 'enemy.dart';
import 'bullet.dart';

class RangedEnemy extends Enemy {
  /// Khoảng cách tối ưu để bắn đạn
  final double preferredRange = 200.0;

  RangedEnemy({required super.position, super.size}) {
    speed = 30; // Di chuyển chậm hơn (vì đã có đạn)
    attackRange = 250; // Phạm vi phát hiện và bắn từ xa
    attackCooldown = 2.0; // Hồi lâu hơn enemy thường
  }

  @override
  Color get baseColor => const Color(0xFFFF8800); // Cam
  @override
  Color get hitColor => Colors.deepOrange;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    hp = 30; // Máu ít hơn enemy thường (bù cho tầm bắn xa)
  }

  @override
  void performAttack() {
    remainingAttackCooldown = attackCooldown;

    // Tính hướng bắn về phía người chơi
    final diff = game.player.position - position;
    if (diff.length < 10) return;
    final dir = diff.normalized();

    // Quay mặt về phía người chơi
    if (diff.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (diff.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    // Hiệu ứng "gồng"
    body.paint.color = Colors.white;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isMounted) return;
      body.paint.color = baseColor;

      // Bắn đạn về phía người chơi
      game.world.add(Bullet(
        position: position.clone() + dir * (size.x / 2 + 5),
        direction: dir,
        color: Colors.orange,
      )..speed = 250); // Đạn chậm hơn đạn player (400) nhưng nhanh hơn đạn boss (150)
    });
  }

  @override
  void handleInRange(double dt, double distance) {
    super.handleInRange(dt, distance);
    
    // Lùi lại khi player đến quá gần
    if (distance < preferredRange - 30) {
      final direction = (position - game.player.position).normalized();
      position.add(direction * speed * 1.5 * dt);
    }
  }
}