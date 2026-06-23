import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'location.dart';

/// Định nghĩa các vùng quái theo khu vực
class ZoneConfig {
  final String name;
  final double centerX;
  final double centerY;
  final double radius;
  final int minLevel; // Cấp độ quái tối thiểu
  final int maxLevel; // Cấp độ quái tối đa
  final double spawnDensity; // 0.0 - 1.0, mật độ spawn
  final List<String> enemyTypes; // Loại quái sẽ spawn

  const ZoneConfig({
    required this.name,
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.minLevel,
    required this.maxLevel,
    required this.spawnDensity,
    required this.enemyTypes,
  });

  bool contains(Vector2 pos) {
    return pos.distanceTo(Vector2(centerX, centerY)) <= radius;
  }
}

class WorldMap {
  /// Kích thước thế giới (tạm thời, sau này Phase 5 sẽ dùng wrapping)
  static const double worldWidth = 16000;
  static const double worldHeight = 10000;

  /// 3 ngôi làng + 1 thành phố
  static final List<WorldLocation> locations = [
    // Làng Ánh Dương - phía Tây Bắc
    WorldLocation(
      name: 'Làng Ánh Dương',
      type: LocationType.village,
      center: Vector2(2000, 2000),
      radius: 400,
      mapColor: Colors.green,
      description: 'Một ngôi làng nhỏ yên bình dưới ánh mặt trời.',
    ),
    // Làng Nguyệt Quế - trung tâm
    WorldLocation(
      name: 'Làng Nguyệt Quế',
      type: LocationType.village,
      center: Vector2(8000, 6000),
      radius: 400,
      mapColor: Colors.green,
      description: 'Ngôi làng cổ kính với những hàng cây nguyệt quế.',
    ),
    // Làng Sao Băng - phía Đông Bắc
    WorldLocation(
      name: 'Làng Sao Băng',
      type: LocationType.village,
      center: Vector2(14000, 2000),
      radius: 400,
      mapColor: Colors.green,
      description: 'Nơi những vì sao rơi xuống từ bầu trời đêm.',
    ),
    // Thành Phố Hoàng Kim - phía Nam
    WorldLocation(
      name: 'Thành Phố Hoàng Kim',
      type: LocationType.city,
      center: Vector2(8000, 8000),
      radius: 600,
      mapColor: Colors.yellow,
      description: 'Thủ phủ tráng lệ với kiến trúc vàng óng ánh.',
    ),
  ];

  /// Các vùng quái theo khu vực
  static final List<ZoneConfig> zones = [
    // Vùng quái gần làng (dễ) - xung quanh Làng Ánh Dương
    ZoneConfig(
      name: 'Đồng cỏ Ánh Dương',
      centerX: 2000,
      centerY: 2800,
      radius: 800,
      minLevel: 1,
      maxLevel: 3,
      spawnDensity: 0.3,
      enemyTypes: ['melee'],
    ),
    // Vùng quái gần làng (dễ) - xung quanh Làng Nguyệt Quế
    ZoneConfig(
      name: 'Rừng Nguyệt Quế',
      centerX: 8000,
      centerY: 6800,
      radius: 800,
      minLevel: 1,
      maxLevel: 3,
      spawnDensity: 0.3,
      enemyTypes: ['melee'],
    ),
    // Vùng quái gần làng (dễ) - xung quanh Làng Sao Băng
    ZoneConfig(
      name: 'Cánh Đồng Sao',
      centerX: 14000,
      centerY: 2800,
      radius: 800,
      minLevel: 1,
      maxLevel: 3,
      spawnDensity: 0.3,
      enemyTypes: ['melee'],
    ),
    // Vùng rừng rậm (trung bình) - giữa các làng
    ZoneConfig(
      name: 'Rừng Rậm Trung Tâm',
      centerX: 5000,
      centerY: 4000,
      radius: 1200,
      minLevel: 3,
      maxLevel: 6,
      spawnDensity: 0.5,
      enemyTypes: ['melee', 'ranged'],
    ),
    ZoneConfig(
      name: 'Rừng Tối Đông Bắc',
      centerX: 11000,
      centerY: 4000,
      radius: 1200,
      minLevel: 3,
      maxLevel: 6,
      spawnDensity: 0.5,
      enemyTypes: ['melee', 'ranged'],
    ),
    // Vùng sa mạc (khó) - phía Nam & xa
    ZoneConfig(
      name: 'Sa Mạc Hoàng Kim',
      centerX: 8000,
      centerY: 9000,
      radius: 1500,
      minLevel: 5,
      maxLevel: 8,
      spawnDensity: 0.7,
      enemyTypes: ['melee', 'ranged'],
    ),
    // Vùng núi lửa (rất khó) - xa nhất
    ZoneConfig(
      name: 'Núi Lửa Tử Thần',
      centerX: 4000,
      centerY: 1500,
      radius: 1000,
      minLevel: 7,
      maxLevel: 10,
      spawnDensity: 0.9,
      enemyTypes: ['melee', 'ranged'],
    ),
  ];

  /// Tìm location gần nhất với vị trí cho trước
  static WorldLocation? nearestLocation(Vector2 pos) {
    WorldLocation? nearest;
    double minDist = double.infinity;
    for (final loc in locations) {
      final dist = pos.distanceTo(loc.center);
      if (dist < minDist) {
        minDist = dist;
        nearest = loc;
      }
    }
    return nearest;
  }

  /// Tìm zone chứa vị trí cho trước
  static ZoneConfig? zoneAt(Vector2 pos) {
    for (final zone in zones) {
      if (zone.contains(pos)) return zone;
    }
    return null;
  }

  /// Kiểm tra vị trí có đang trong vùng an toàn của location nào không
  static bool isInSafeZone(Vector2 pos) {
    for (final loc in locations) {
      if (loc.contains(pos)) return true;
    }
    return false;
  }
}