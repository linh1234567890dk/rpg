import 'package:flutter/material.dart';

/// Loại skill — định nghĩa ở đây để tránh circular dependency
enum SkillType { normal, special, dash }

/// Một thuộc tính của nhân vật dùng để scale sát thương skill
class SkillScaling {
  /// Tên thuộc tính (khớp với getter trong Player)
  final String statName;
  /// Phần trăm của thuộc tính này được cộng vào sát thương (vd: 100 = 100%)
  final double percent;

  const SkillScaling(this.statName, this.percent);
}

/// Định nghĩa cấu hình cho một skill
class SkillData {
  final SkillType type;
  final String label;
  final double baseDamage;
  final List<SkillScaling> scalings;
  final double cooldown;
  final double manaCost;
  final bool isMelee;
  final bool isDamaging; // false cho utility skill như dash
  final Color color;
  final String description;

  const SkillData({
    required this.type,
    required this.label,
    this.baseDamage = 0,
    this.scalings = const [],
    this.cooldown = 0.5,
    this.manaCost = 0,
    this.isMelee = false,
    this.isDamaging = true,
    this.color = Colors.white,
    this.description = '',
  });

  /// Tính sát thương cuối cùng dựa vào stats của player
  double calculateDamage({
    required double attackDamage,
    required double maxHp,
    required double currentHp,
    required double speed,
  }) {
    if (!isDamaging) return 0;

    double total = baseDamage;
    for (final scaling in scalings) {
      double statValue;
      switch (scaling.statName) {
        case 'attackDamage':
          statValue = attackDamage;
          break;
        case 'maxHp':
          statValue = maxHp;
          break;
        case 'currentHp':
          statValue = currentHp;
          break;
        case 'speed':
          statValue = speed;
          break;
        default:
          statValue = 0;
      }
      total += statValue * scaling.percent / 100.0;
    }
    return total;
  }
}

/// Định nghĩa tất cả skill trong game — data-driven
class SkillDatabase {
  static const List<SkillData> skills = [
    // Đánh thường: 0 base + 100% ATK
    SkillData(
      type: SkillType.normal,
      label: 'ATK',
      baseDamage: 0,
      scalings: [SkillScaling('attackDamage', 100)],
      cooldown: 0.5,
      isMelee: true,
      color: Colors.white,
      description: 'Đánh thường: 100% ATK',
    ),

    // Special Skill: bắn đạn, 100 base + 10% maxHp + 50% ATK
    SkillData(
      type: SkillType.special,
      label: 'SKILL',
      baseDamage: 100,
      scalings: [
        SkillScaling('maxHp', 10),
        SkillScaling('attackDamage', 50),
      ],
      cooldown: 3.0,
      isMelee: false, // Bắn đạn
      color: Colors.cyan,
      description: 'Skill: 100 + 10% HP + 50% ATK',
    ),

    // Dash: không gây sát thương, chỉ lướt
    SkillData(
      type: SkillType.dash,
      label: 'DASH',
      baseDamage: 0,
      scalings: [],
      cooldown: 1.5,
      isDamaging: false,
      color: Colors.blue,
      description: 'Lướt nhanh về phía trước',
    ),
  ];

  /// Lấy config skill theo type
  static SkillData getSkill(SkillType type) {
    return skills.firstWhere((s) => s.type == type);
  }
}