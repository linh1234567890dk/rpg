import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import '../rpg_game.dart';

enum SkillType { normal, special, dash }

class SkillButton extends PositionComponent 
    with TapCallbacks, DragCallbacks, HasGameReference<RPGGame> {
  
  final SkillType type;
  final VoidCallback? onAction;
  final Function(Vector2 direction)? onAimAction;
  final double cooldown; // Thời gian hồi chiêu (giây)

  double _remainingCooldown = 0;
  bool _isDragging = false;
  Vector2 _dragDirection = Vector2.zero();
  
  // Các thành phần giao diện của nút
  late final CircleComponent _bg;
  late final TextComponent _label;
  late final CircleComponent _cooldownOverlay;
  
  SkillButton({
    required this.type,
    required Vector2 position,
    this.cooldown = 0.5, // Mặc định 0.5s cho đòn thường
    this.onAction,
    this.onAimAction,
  }) : super(position: position, size: Vector2.all(80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    _bg = CircleComponent(
      radius: size.x / 2,
      paint: BasicPalette.gray.withAlpha(150).paint(),
    );
    add(_bg);

    // Lớp phủ cooldown (màu đen mờ)
    _cooldownOverlay = CircleComponent(
      radius: size.x / 2,
      paint: Paint()..color = Colors.black.withAlpha(180),
    );
    _cooldownOverlay.scale = Vector2.zero(); // Mặc định ẩn đi
    add(_cooldownOverlay);

    String labelText = 'ATK';
    if (type == SkillType.special) labelText = 'SKILL';
    if (type == SkillType.dash) labelText = 'DASH';

    _label = TextComponent(
      text: labelText,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_label);
  }

  bool get isReady => _remainingCooldown <= 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (_remainingCooldown > 0) {
      _remainingCooldown -= dt;
      
      // Hiển thị hiệu ứng cooldown cho Skill (nếu cooldown > 0.5s)
      if (cooldown > 0.5) {
        _cooldownOverlay.scale = Vector2.all(_remainingCooldown / cooldown);
      }
    } else {
      _cooldownOverlay.scale = Vector2.zero();
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isReady) return;
    _bg.paint.color = Colors.white.withAlpha(200);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!isReady) return;
    _bg.paint.color = Colors.grey.withAlpha(150);
    // Nếu không kéo, thì coi như là Tap để tự định hướng
    if (!_isDragging) {
      onAction?.call();
      _startCooldown();
    }
  }

  void _startCooldown() {
    _remainingCooldown = cooldown;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (!isReady) return;
    super.onDragStart(event);
    _isDragging = true;
    _bg.paint.color = Colors.blue.withAlpha(200);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    // Trong Flame 1.x, localPosition là vị trí ngón tay so với góc trên bên trái của nút
    // Chúng ta tính delta từ tâm của nút (size / 2)
    final center = size / 2;
    final delta = event.localEndPosition - center;
    
    if (delta.length > 5) { // Giảm deadzone để nhạy hơn
      // Hướng kéo chính là delta đã chuẩn hóa
      _dragDirection = delta.normalized();
      // Cập nhật hướng cho indicator
      game.showAimIndicator(_dragDirection);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _bg.paint.color = Colors.grey.withAlpha(150);
    if (_isDragging) {
      // Thực hiện skill theo hướng đã chọn
      onAimAction?.call(_dragDirection);
      game.hideAimIndicator();
      _startCooldown();
    }
    _isDragging = false;
    _dragDirection = Vector2.zero();
  }
}
