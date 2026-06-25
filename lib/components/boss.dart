import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy.dart';
import 'bullet.dart';

class Boss extends Enemy {
  double phaseTimer = 0;
  int currentPhase = 1;

  Boss({required super.position, super.level}) {
    size = Vector2.all(100); // Boss to gấp đôi quái thường
    hp = 500;
    detectionRange = 300.0;
    tetherRange = 600.0;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    body.paint.color = Colors.purple; // Boss màu tím cho uy tín
  }

  @override
  void takeDamage(double damage, {Vector2? knockbackDirection}) {
    // Boss vẫn nhận sát thương nhưng không bị khựng (stun)
    super.takeDamage(damage, knockbackDirection: knockbackDirection);
    
    // Kháng hiệu ứng khựng ngay lập tức
    stunTimer = 0;
    
    // Giảm lực đẩy lùi đối với Boss (chỉ lùi rất nhẹ)
    if (knockbackDirection != null) {
      knockbackVelocity = knockbackDirection * 50; 
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    phaseTimer += dt;

    // Boss pattern: Cứ mỗi 4 giây sẽ đổi kiểu tấn công
    if (phaseTimer > 4) {
      phaseTimer = 0;
      currentPhase = (currentPhase % 2) + 1;
      if (currentPhase == 2) {
        _performSpecialAttack();
      }
    }
  }

  void _performSpecialAttack() {
    // Boss bắn đạn xung quanh 8 hướng
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * 0.0174533; // Chuyển sang radian
      final dir = Vector2(math.cos(angle), math.sin(angle));
      game.add(Bullet(
        position: position.clone(),
        direction: dir,
        color: Colors.red,
      )..speed = 150); // Đạn boss bay chậm hơn nhưng nhiều
    }
    // Rung màn hình khi boss dùng chiêu
    game.shake();
  }

  @override
  void onRemove() {
    super.onRemove();
    // Khi boss chết, rung màn hình cực mạnh
    game.shake(intensity: 10, duration: 0.5);
  }
}
