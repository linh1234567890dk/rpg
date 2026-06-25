import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../rpg_game.dart';
import '../world/world_map.dart';

/// Hiển thị tên địa danh khi player bước vào vùng an toàn
class LocationNamePopup extends Component with HasGameReference<RPGGame> {
  String _currentName = '';
  String _displayName = '';
  double _alpha = 0; // 0 = ẩn, 1 = hiện đầy đủ
  double _timer = 0;

  @override
  void update(double dt) {
    super.update(dt);

    final playerPos = game.player.position;
    final inSafeZone = WorldMap.isInSafeZone(playerPos);

    if (inSafeZone) {
      final loc = WorldMap.nearestLocation(playerPos);
      final name = loc?.name ?? '';

      if (name != _currentName) {
        _currentName = name;
        _displayName = name;
        _alpha = 1;
        _timer = 3; // Hiển thị trong 3 giây
      } else if (_timer > 0) {
        _timer -= dt;
        if (_timer <= 0) {
          _alpha -= dt * 2; // Fade out sau 3s
          if (_alpha < 0) _alpha = 0;
        }
      }
    } else {
      // Ngoài safe zone: fade out
      _currentName = '';
      _alpha -= dt * 3;
      if (_alpha < 0) _alpha = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_alpha <= 0 || _displayName.isEmpty) return;

    final centerX = game.size.x / 2;
    final centerY = game.size.y * 0.15; // Phía trên màn hình

    // Vẽ background
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4 * _alpha)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(centerX, centerY), width: 300, height: 50),
        const Radius.circular(16),
      ),
      bgPaint,
    );

    // Vẽ text
    final textPainter = TextPainter(
      text: TextSpan(
        text: _displayName,
        style: TextStyle(
          color: Colors.white.withValues(alpha: _alpha),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: 280);
    textPainter.paint(canvas, Offset(centerX - textPainter.width / 2, centerY - textPainter.height / 2));
  }
}