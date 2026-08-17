import 'package:flutter/material.dart';
import 'attack_style.dart';

/// Cấu hình của một loại enemy — data-driven, dùng chung cho mọi loại (kể cả boss).
class EnemyData {
  final String id;              // Khóa định danh (vd: 'slime', 'boss') — không dùng enum, thêm quái mới chỉ cần thêm entry
  final String name;            // Tên hiển thị
  final List<AttackStyle> attackStyles; // Danh sách kiểu tấn công (boss có nhiều style luân phiên)
  final double phaseInterval;   // 0 = không đổi style, > 0 = cứ mỗi N giây chuyển style kế tiếp

  final double size;
  final double baseHp;
  final double baseSpeed;
  final double detectionRange;
  final double tetherRange;
  final double preferredRange; // Khoảng cách lùi lại giữ khi là ranged
  final double knockbackResist; // 0.0 - 1.0, 1.0 = miễn knockback
  final int xpBase;
  final Color color;
  final Color hitColor;
  final bool canRespawn; // false = không respawn (vd: boss, imp tự sát)
  final String path;

  const EnemyData({
    required this.id,
    required this.name,
    required this.attackStyles,
    this.phaseInterval = 0,
    this.size = 40,
    this.baseHp = 50,
    this.baseSpeed = 50,
    this.detectionRange = 180,
    this.tetherRange = 400,
    this.preferredRange = 0,
    this.knockbackResist = 0,
    this.xpBase = 20,
    this.color = Colors.red,
    this.hitColor = Colors.orange,
    this.canRespawn = true,
    this.path = '👾',
  });
}

/// Nguồn dữ liệu enemy — thêm quái mới chỉ cần thêm 1 entry vào map này.
class EnemyDatabase {
  static const Map<String, EnemyData> enemies = {
    'slime': EnemyData(
      id: 'slime',
      name: 'Slime',
      attackStyles: [MeleeAttack()],
      size: 40,
      baseHp: 50,
      baseSpeed: 50,
      color: Colors.red,
      hitColor: Colors.orange,
      path: '🔴',
    ),
    'wolf': EnemyData(
      id: 'wolf',
      name: 'Wolf',
      attackStyles: [MeleeAttack(range: 60, cooldown: 1.0, damage: 8)],
      size: 28,
      baseHp: 30,
      baseSpeed: 130,
      detectionRange: 250,
      color: Colors.blue,
      hitColor: Colors.lightBlue,
      path: '🐺',
    ),
    'golem': EnemyData(
      id: 'golem',
      name: 'Golem',
      attackStyles: [MeleeAttack(range: 80, cooldown: 2.5, damage: 20)],
      size: 55,
      baseHp: 200,
      baseSpeed: 25,
      knockbackResist: 0.8,
      color: Colors.green,
      hitColor: Colors.lightGreen,
      path: '🪨',
    ),
    'wisp': EnemyData(
      id: 'wisp',
      name: 'Wisp',
      attackStyles: [RangedAttack(range: 250, cooldown: 2.0, damage: 10, count: 1, speed: 250)],
      size: 40,
      baseHp: 40,
      baseSpeed: 35,
      detectionRange: 250,
      preferredRange: 200,
      color: Colors.orange,
      hitColor: Colors.deepOrange,
      path: '👻',
    ),
    'imp': EnemyData(
      id: 'imp',
      name: 'Imp',
      attackStyles: [SuicideAttack(explosionDamage: 35, blastRadius: 80, explodeRange: 30)],
      size: 35,
      baseHp: 40,
      baseSpeed: 80,
      color: Colors.deepOrange,
      hitColor: Colors.orange,
      canRespawn: false,
      path: '😈',
    ),
    'molten_king': EnemyData(
      id: 'molten_king',
      name: 'Molten King',
      attackStyles: [
        RangedAttack(range: 250, cooldown: 2.0, damage: 15, count: 8, spread: true, speed: 150, color: Colors.red),
        MeleeAttack(range: 60, cooldown: 2.5, damage: 30),
      ],
      phaseInterval: 4,
      size: 100,
      baseHp: 500,
      baseSpeed: 40,
      detectionRange: 300,
      tetherRange: 600,
      color: Colors.purple,
      hitColor: Colors.deepPurple,
      canRespawn: false,
      path: '👹',
    ),
  };

  static EnemyData get(String id) {
    final data = enemies[id];
    if (data == null) {
      throw ArgumentError('Enemy id "$id" không tồn tại trong EnemyDatabase');
    }
    return data;
  }
}