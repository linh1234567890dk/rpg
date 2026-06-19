import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy_attack_effect.dart';
import '../rpg_game.dart';

class Enemy extends PositionComponent
    with HasGameReference<RPGGame>, CollisionCallbacks {
  double hp = 50.0;
  final double maxHp = 50.0;
  final double speed = 50.0;

  // Thông số tấn công
  final double attackRange = 60.0;
  final double attackCooldown = 1.5;
  double _remainingAttackCooldown = 0;

  // Knockback & Stun
  double stunTimer = 0;
  Vector2 knockbackVelocity = Vector2.zero();

  late final RectangleComponent body;
  late final RectangleComponent hpBar;
  late final RectangleComponent ghostHpBar;

  Enemy({required Vector2 position})
    : super(position: position, size: Vector2.all(40), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    body = RectangleComponent(size: size, paint: Paint()..color = Colors.red);
    add(body);

    // Thêm collision area
    add(RectangleHitbox());

    // Thanh Ghost HP (Màu trắng mờ, nằm dưới thanh xanh)
    ghostHpBar = RectangleComponent(
      size: Vector2(size.x, 4),
      position: Vector2(0, -8),
      paint: Paint()..color = Colors.white.withAlpha(150),
    );
    add(ghostHpBar);

    // Thanh máu chính (Màu xanh)
    hpBar = RectangleComponent(
      size: Vector2(size.x, 4),
      position: Vector2(0, -8),
      paint: Paint()..color = Colors.green,
    );
    add(hpBar);
  }

  @override
  void update(double dt) {
    super.update(dt);

    final player = game.player;
    final distance = position.distanceTo(player.position);

    // Xử lý Stun & Knockback
    if (stunTimer > 0) {
      stunTimer -= dt;
      // Di chuyển theo lực đẩy lùi (giảm dần theo thời gian)
      position.add(knockbackVelocity * dt);
      knockbackVelocity *= 0.9; // Ma sát làm chậm lực đẩy
      return; // Không làm gì khác khi bị choáng
    }

    if (_remainingAttackCooldown > 0) {
      _remainingAttackCooldown -= dt;
    }

    if (distance > attackRange) {
      // Nếu ở xa, đuổi theo người chơi
      final direction = (player.position - position).normalized();
      position.add(direction * speed * dt);
    } else {
      // Nếu đủ gần, dừng lại và tấn công
      if (_remainingAttackCooldown <= 0) {
        _performAttack();
      }
    }

    // Y-sorting
    priority = position.y.toInt();

    // Cập nhật thanh máu chính (tụt ngay lập tức)
    hpBar.width = (hp / maxHp) * size.x;

    // Cập nhật thanh Ghost HP (co lại từ từ sau khi thanh chính tụt)
    if (ghostHpBar.width > hpBar.width) {
      // Giảm dần chiều rộng thanh trắng (tốc độ co lại)
      ghostHpBar.width -= 50 * dt;
      if (ghostHpBar.width < hpBar.width) {
        ghostHpBar.width = hpBar.width;
      }
    } else if (ghostHpBar.width < hpBar.width) {
      // Nếu được hồi máu thì thanh trắng cũng nhảy lên theo
      ghostHpBar.width = hpBar.width;
    }

    if (hp <= 0) {
      game.addScore(1);
      removeFromParent();
    }
  }

  void _performAttack() {
    _remainingAttackCooldown = attackCooldown;

    // Hướng tấn công tới người chơi
    final diff = game.player.position - position;
    final dir = diff.normalized();

    // Hiệu ứng "gồng" đòn (nháy màu trắng trước khi đánh)
    body.paint.color = Colors.white;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isMounted) return;
      body.paint.color = Colors.red;

      // Tạo hiệu ứng vệt chém thực sự
      game.add(EnemyAttackEffect(position: position.clone(), direction: dir));

      // Rung nhẹ khi quái tung đòn
      game.shake(intensity: 1);
    });
  }

  void takeDamage(double damage, {Vector2? knockbackDirection}) {
    hp -= damage;
    game.shake(intensity: 2); // Rung nhẹ khi quái trúng đòn
    game.showHitEffect(position.clone(), Colors.orange); // Hiệu ứng tia lửa

    // Nếu không trong trạng thái choáng thì mới bị đẩy lùi
    if (stunTimer <= 0 && knockbackDirection != null) {
      knockbackVelocity = knockbackDirection * 200; // Độ mạnh của lực đẩy
    }

    // Luôn bị khựng lại một chút khi trúng đòn
    stunTimer = 0.25;

    // Hiệu ứng nháy trắng khi trúng đòn
    body.paint.color = Colors.orange;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isMounted) return;
      body.paint.color = Colors.red;
    });
  }
}
