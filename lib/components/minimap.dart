import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../rpg_game.dart';
import '../world/world_map.dart';

/// Minimap hiển thị ở góc màn hình
class Minimap extends Component with HasGameReference<RPGGame> {
  /// Kích thước minimap hiển thị
  final double mapScreenSize = 180;
  /// Tỉ lệ thu nhỏ: world → minimap
  late final double scale;

  Minimap() {
    // Tỉ lệ = kích thước minimap / kích thước world
    scale = mapScreenSize / math.max(WorldMap.worldWidth, WorldMap.worldHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final x = game.size.x - mapScreenSize - 10.0; // Góc phải trên
    final y = 10.0;

    // Vẽ nền minimap
    final bgPaint = Paint()
      ..color = Colors.black.withAlpha(180)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 5.0, y - 5.0, mapScreenSize + 10.0, mapScreenSize + 10.0),
        const Radius.circular(8),
      ),
      bgPaint,
    );

    // Vẽ nền world map
    final mapPaint = Paint()
      ..color = const Color(0xFF2D5A27).withAlpha(150)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Offset(x, y) & Size(mapScreenSize, mapScreenSize),
      mapPaint,
    );

    // Vẽ các zone
    for (final zone in WorldMap.zones) {
      final cx = x + zone.centerX * scale;
      final cy = y + zone.centerY * scale;
      final r = zone.radius * scale;

      final paint = Paint()
        ..color = _zoneMapColor(zone.name).withAlpha(120)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Vẽ locations
    for (final loc in WorldMap.locations) {
      final lx = x + loc.center.x * scale;
      final ly = y + loc.center.y * scale;
      final r = loc.radius * scale;

      // Vòng tròn vùng an toàn
      final paint = Paint()
        ..color = loc.mapColor.withAlpha(80)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lx, ly), r, paint);

      // Chấm tròn đại diện
      final dotPaint = Paint()
        ..color = loc.mapColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lx, ly), 4.0, dotPaint);
    }

    // Vẽ viewport rectangle
    final vpW = game.size.x * scale;
    final vpH = game.size.y * scale;
    final vpX = x + (game.camera.viewfinder.position.x - game.size.x / 2) * scale;
    final vpY = y + (game.camera.viewfinder.position.y - game.size.y / 2) * scale;

    final vpPaint = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(
      Rect.fromLTWH((vpX.clamp(x, x + mapScreenSize - vpW)).toDouble(), 
                    (vpY.clamp(y, y + mapScreenSize - vpH)).toDouble(), 
                    vpW.clamp(0.0, mapScreenSize), 
                    vpH.clamp(0.0, mapScreenSize)),
      vpPaint,
    );

    // Vẽ player dot
    final px = x + game.player.position.x * scale;
    final py = y + game.player.position.y * scale;

    final playerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(px, py), 3.0, playerPaint);
  }

  Color _zoneMapColor(String zoneName) {
    if (zoneName.contains('Đồng cỏ') || zoneName.contains('Cánh Đồng')) {
      return const Color(0xFF3D7A37);
    }
    if (zoneName.contains('Rừng')) {
      return const Color(0xFF1A4A1A);
    }
    if (zoneName.contains('Sa Mạc')) {
      return const Color(0xFFC4A44A);
    }
    if (zoneName.contains('Núi Lửa')) {
      return const Color(0xFF8B0000);
    }
    return const Color(0xFF2D5A27);
  }
}