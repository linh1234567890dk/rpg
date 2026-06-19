import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class AimIndicator extends PositionComponent {
  Vector2 direction = Vector2.zero();
  bool isVisible = false;

  @override
  void render(Canvas canvas) {
    if (!isVisible || direction.isZero()) return;

    final paint = Paint()
      ..color = Colors.red.withAlpha(150)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Vẽ một mũi tên hoặc đường thẳng từ vị trí Player
    // Vì AimIndicator sẽ được thêm vào Player hoặc di chuyển theo Player
    final endPoint = (direction * 100).toOffset();
    canvas.drawLine(Offset.zero, endPoint, paint);
    
    // Vẽ đầu mũi tên
    // (Có thể làm chi tiết hơn sau)
  }
}
