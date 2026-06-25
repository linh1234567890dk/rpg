import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../rpg_game.dart';
import '../utils/world_config.dart';
import 'world_map.dart';
import 'location.dart';

/// Component vẽ nền terrain — CHỈ vẽ phần trong viewport để tối ưu performance
class TerrainBackground extends PositionComponent with HasGameReference<RPGGame> {
  TerrainBackground() : super(size: Vector2(WorldMap.worldWidth, WorldMap.worldHeight));

  @override
  void render(Canvas canvas) {
    final game = this.game;
    final cameraPos = game.camera.viewfinder.position;
    final vpSize = game.size;
    final padding = 200.0;

    // Tính viewport thực (có thể tràn ra ngoài world bounds)
    final viewLeft = cameraPos.x - vpSize.x / 2 - padding;
    final viewRight = cameraPos.x + vpSize.x / 2 + padding;
    final viewTop = cameraPos.y - vpSize.y / 2 - padding;
    final viewBottom = cameraPos.y + vpSize.y / 2 + padding;
    final fullViewport = Rect.fromLTRB(viewLeft, viewTop, viewRight, viewBottom);

    // Vẽ viewport chính (không offset)
    _renderViewport(canvas, fullViewport);

    // Lấy danh sách offset cần render thêm
    final offsets = WorldConfig.getWrappedOffsets(fullViewport);
    for (final offset in offsets) {
      final shiftedVp = fullViewport.shift(Offset(offset.x, offset.y));
      canvas.save();
      canvas.translate(-offset.x, -offset.y);
      _renderViewport(canvas, shiftedVp);
      canvas.restore();
    }
  }

  void _renderViewport(Canvas canvas, Rect vp) {
    // Giới hạn vp trong world bounds
    final clipLeft = vp.left.clamp(0.0, WorldMap.worldWidth);
    final clipTop = vp.top.clamp(0.0, WorldMap.worldHeight);
    final clipRight = vp.right.clamp(0.0, WorldMap.worldWidth);
    final clipBottom = vp.bottom.clamp(0.0, WorldMap.worldHeight);
    final clipRect = Rect.fromLTRB(clipLeft, clipTop, clipRight, clipBottom);
    if (clipRect.isEmpty) return;

    final paint = Paint();

    // Nền tổng thể
    paint.color = const Color(0xFF2D5A27);
    canvas.drawRect(clipRect, paint);

    // Các zone
    for (final zone in WorldMap.zones) {
      final zoneRect = Rect.fromCircle(
        center: Offset(zone.centerX, zone.centerY),
        radius: zone.radius,
      );
      if (!zoneRect.overlaps(clipRect)) continue;

      paint.color = _zoneColor(zone.name);
      canvas.drawCircle(Offset(zone.centerX, zone.centerY), zone.radius, paint);
    }

    // Các location
    for (final loc in WorldMap.locations) {
      final locRect = Rect.fromCircle(
        center: Offset(loc.center.x, loc.center.y),
        radius: loc.radius,
      );
      if (!locRect.overlaps(clipRect)) continue;

      paint.color = const Color(0xFF4A7C3F).withAlpha(100);
      canvas.drawCircle(Offset(loc.center.x, loc.center.y), loc.radius, paint);

      paint.color = Colors.white.withAlpha(80);
      paint.style = PaintingStyle.stroke;
      paint.strokeWidth = 2;
      canvas.drawCircle(Offset(loc.center.x, loc.center.y), loc.radius, paint);
      paint.style = PaintingStyle.fill;

      _drawLocationIcon(canvas, loc);
    }
  }

  Color _zoneColor(String zoneName) {
    if (zoneName.contains('Đồng cỏ') || zoneName.contains('Cánh Đồng')) {
      return const Color(0xFF3D7A37).withAlpha(80); // Xanh đồng cỏ
    }
    if (zoneName.contains('Rừng')) {
      return const Color(0xFF1A4A1A).withAlpha(100); // Xanh rừng rậm
    }
    if (zoneName.contains('Sa Mạc')) {
      return const Color(0xFFC4A44A).withAlpha(80); // Vàng cát
    }
    if (zoneName.contains('Núi Lửa')) {
      return const Color(0xFF8B0000).withAlpha(100); // Đỏ núi lửa
    }
    return const Color(0xFF2D5A27).withAlpha(50);
  }

  void _drawLocationIcon(Canvas canvas, WorldLocation loc) {
    final paint = Paint();
    final center = Offset(loc.center.x, loc.center.y);

    if (loc.type.name == 'village') {
      // Vẽ hình ngôi nhà nhỏ cho làng
      paint.color = Colors.brown;
      // Thân nhà
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 30, height: 20),
        paint,
      );
      // Mái nhà
      paint.color = const Color(0xFF8B4513);
      final roofPath = Path()
        ..moveTo(center.dx - 20, center.dy - 10)
        ..lineTo(center.dx, center.dy - 25)
        ..lineTo(center.dx + 20, center.dy - 10)
        ..close();
      canvas.drawPath(roofPath, paint);
    } else if (loc.type.name == 'city') {
      // Vẽ hình tòa tháp cho thành phố
      paint.color = const Color(0xFFDAA520); // Vàng gold
      // Thân tháp
      canvas.drawRect(
        Rect.fromCenter(center: center, width: 40, height: 30),
        paint,
      );
      // Nóc tháp nhọn
      paint.color = const Color(0xFFFFD700);
      final towerPath = Path()
        ..moveTo(center.dx - 25, center.dy - 15)
        ..lineTo(center.dx, center.dy - 35)
        ..lineTo(center.dx + 25, center.dy - 15)
        ..close();
      canvas.drawPath(towerPath, paint);
    }
  }
}