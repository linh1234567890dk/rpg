import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:rpg/components/enemy.dart';
import 'bullet.dart';
import 'melee_slash.dart';
import 'dash_after_image.dart';

import '../rpg_game.dart';
import '../utils/world_config.dart';
import '../world/world_map.dart';

class Player extends PositionComponent
    with HasGameReference<RPGGame>, CollisionCallbacks {
  final JoystickComponent joystick;
  final double speed = 200.0;

  double hp = 100.0;
  final double maxHp = 100.0;
  int level = 1;
  double xp = 0;

  // Knockback & Stun
  double stunTimer = 0;
  Vector2 knockbackVelocity = Vector2.zero();

  // Dash Skill
  bool isDashing = false;
  double dashTimer = 0;
  final double dashDuration = 0.2;
  final double dashSpeed = 800.0;
  Vector2 dashDirection = Vector2.zero();
  double _afterImageTimer = 0;

  late final RectangleComponent body;

  Player({required this.joystick})
    : super(size: Vector2.all(50), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Thêm va chạm cho người chơi
    add(RectangleHitbox());
    // Sử dụng một hình vuông màu trắng đại diện cho nhân vật
    body = RectangleComponent(size: size, paint: BasicPalette.white.paint());
    add(body);

    // Đặt vị trí ban đầu gần Làng Ánh Dương (2000, 2000)
    position = Vector2(2000, 2000);
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Xử lý Lướt (Dash)
    if (isDashing) {
      dashTimer -= dt;
      _afterImageTimer -= dt;
      
      if (_afterImageTimer <= 0) {
        _afterImageTimer = 0.05; // Cứ 0.05s tạo 1 bóng
        game.world.add(DashAfterImage(
          position: position.clone(),
          size: size.clone(),
        ));
      }

      position.add(dashDirection * dashSpeed * dt);
      
      if (dashTimer <= 0) {
        isDashing = false;
        body.paint.color = Colors.white;
      }
      return; // Không nhận input di chuyển khác khi đang lướt
    }

    // Xử lý Stun & Knockback
    if (stunTimer > 0) {
      stunTimer -= dt;
      position.add(knockbackVelocity * dt);
      knockbackVelocity *= 0.9;
      return; // Bị khựng, không thể di chuyển hay tấn công
    }

    // Nếu joystick đang được điều khiển
    if (!joystick.delta.isZero()) {
      position.add(joystick.relativeDelta * speed * dt);

      // Không xoay nhân vật nữa, thay vào đó là lật trái/phải
      if (joystick.relativeDelta.x < 0 && scale.x > 0) {
        flipHorizontallyAroundCenter();
      } else if (joystick.relativeDelta.x > 0 && scale.x < 0) {
        flipHorizontallyAroundCenter();
      }
    }

    // Wrap position (seamless world)
    position = WorldConfig.wrapPosition(position);

    // Hồi máu khi ở trong safe zone
    if (WorldMap.isInSafeZone(position)) {
      hp = (hp + 20 * dt).clamp(0, maxHp);
    }

    // Cập nhật priority để tạo hiệu ứng 2.5D (Y-sorting)
    priority = position.y.toInt();

    // KHÔNG giữ nhân vật trong viewport nữa vì camera đã follow player
    // keepInBounds(); // ❌ Sai: game.size là viewport size, không phải world size

    _updateTargetLock();
  }

  void _updateTargetLock() {
    Enemy? nearestEnemy;
    double minDistance = double.infinity;
    
    final enemies = game.world.children.whereType<Enemy>();
    for (final enemy in enemies) {
      if (!enemy.isMounted) continue;
      final dist = WorldConfig.wrappedDistance(position, enemy.position);
      if (dist < minDistance) {
        minDistance = dist;
        nearestEnemy = enemy;
      }
    }
    
    if (nearestEnemy != null && minDistance < 400) {
      game.targetLockIndicator.position = nearestEnemy.position;
      game.targetLockIndicator.isVisible = true;
    } else {
      game.targetLockIndicator.isVisible = false;
    }
  }

  void attack(Vector2? direction, {bool isMelee = false}) {
    Vector2 shootDir;
    
    if (direction != null) {
      // Nếu người chơi kéo để định hướng (Manual Aim)
      shootDir = direction;
    } else {
      // Tự định hướng (Auto Aim): Tìm kẻ địch gần nhất trong world
      Enemy? nearestEnemy;
      double minDistance = double.infinity;
      
      final enemies = game.world.children.whereType<Enemy>();
      for (final enemy in enemies) {
        if (!enemy.isMounted) continue;
        final dist = WorldConfig.wrappedDistance(position, enemy.position);
        if (dist < minDistance) {
          minDistance = dist;
          nearestEnemy = enemy;
        }
      }
      
      if (nearestEnemy != null && minDistance < 400) { // Tầm đánh tự động là 400px
        shootDir = WorldConfig.wrappedDirection(position, nearestEnemy.position);
      } else {
        // Nếu không có quái gần đó, bắn theo hướng nhân vật đang nhìn
        shootDir = Vector2(scale.x > 0 ? 1 : -1, 0);
      }
    }
    
    if (isMelee) {
      game.world.add(MeleeSlash(position: position.clone(), direction: shootDir));
      // Rung nhẹ khi chém
      game.shake(intensity: 1);
    } else {
      game.world.add(Bullet(position: position.clone(), direction: shootDir));
    }
  }

  void dash(Vector2 direction) {
    if (isDashing) return;
    isDashing = true;
    dashTimer = dashDuration;
    dashDirection = direction.normalized();
    // Hiệu ứng màu xanh nhạt khi lướt
    body.paint.color = Colors.cyan.withAlpha(200);
    game.shake(intensity: 2);
  }

  void takeDamage(double damage, {Vector2? knockbackDirection}) {
    if (isDashing) return; // Bất tử khi đang lướt (I-frames)
    
    hp -= damage;
    game.showHitEffect(position.clone(), Colors.red);

    // Nếu không trong trạng thái choáng thì mới bị đẩy lùi
    if (stunTimer <= 0 && knockbackDirection != null) {
      knockbackVelocity =
          knockbackDirection * 150; // Lực đẩy người chơi nhẹ hơn quái
    }

    // Luôn bị khựng lại
    stunTimer = 0.25;

    // Hiệu ứng nháy đỏ khi trúng đòn
    body.paint.color = Colors.red;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isMounted) return;
      body.paint.color = Colors.white;
    });

    if (hp <= 0) {
      hp = 0;
      game.gameOver();
    }
  }

  @override
  void renderTree(Canvas canvas) {
    // Render chính (bao gồm các child component)
    super.renderTree(canvas);

    // Ghost copies khi gần mép world
    final threshold = 600.0;
    if (position.x < threshold) {
      canvas.save();
      canvas.translate(WorldConfig.worldWidth, 0);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.x > WorldConfig.worldWidth - threshold) {
      canvas.save();
      canvas.translate(-WorldConfig.worldWidth, 0);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.y < threshold) {
      canvas.save();
      canvas.translate(0, WorldConfig.worldHeight);
      super.renderTree(canvas);
      canvas.restore();
    }
    if (position.y > WorldConfig.worldHeight - threshold) {
      canvas.save();
      canvas.translate(0, -WorldConfig.worldHeight);
      super.renderTree(canvas);
      canvas.restore();
    }
  }
}
