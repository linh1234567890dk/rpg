import 'package:flame/components.dart';
import 'package:flutter/material.dart';

enum LocationType { village, city, forest, desert, mountain }

class WorldLocation {
  final String name;
  final LocationType type;
  final Vector2 center;
  final double radius; // Bán kính vùng an toàn (không spawn quái)
  final Color mapColor; // Màu trên minimap
  final String description;

  const WorldLocation({
    required this.name,
    required this.type,
    required this.center,
    required this.radius,
    required this.mapColor,
    this.description = '',
  });

  /// Kiểm tra một vị trí có nằm trong vùng an toàn của location này không
  bool contains(Vector2 pos) {
    return pos.distanceTo(center) <= radius;
  }
}