import 'package:flutter/material.dart';

/// Kiểu tấn công của enemy — model độc lập, mở rộng được.
/// Mỗi style mang luôn thông số đòn đánh của riêng nó (range, cooldown, damage).
sealed class AttackStyle {
  const AttackStyle();
}

/// Tấn công cận chiến (vệt chém sát thương).
class MeleeAttack extends AttackStyle {
  final double range;
  final double cooldown;
  final double damage;

  const MeleeAttack({
    this.range = 60,
    this.cooldown = 1.5,
    this.damage = 10,
  });
}

/// Bắn đạn. count = số đạn, spread = true nghĩa là tỏa đều vòng tròn,
/// false nghĩa là bắn về hướng người chơi (nhiều đạn thì chệch nhẹ mỗi phát).
class RangedAttack extends AttackStyle {
  final double range;
  final double cooldown;
  final double damage;
  final int count;
  final bool spread;
  final double speed;
  final Color color;

  const RangedAttack({
    this.range = 250,
    this.cooldown = 2.0,
    this.damage = 10,
    this.count = 1,
    this.spread = false,
    this.speed = 250,
    this.color = Colors.orange,
  });
}

/// Tự sát — lao vào người chơi rồi nổ, gây sát thương diện rộng.
class SuicideAttack extends AttackStyle {
  final double explosionDamage;
  final double blastRadius;
  final double explodeRange;

  const SuicideAttack({
    this.explosionDamage = 35,
    this.blastRadius = 80,
    this.explodeRange = 30,
  });
}