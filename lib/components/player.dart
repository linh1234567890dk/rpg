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
import '../utils/skill_config.dart';
import '../world/world_map.dart';

class Player extends PositionComponent
    with HasGameReference<RPGGame>, CollisionCallbacks {
  final JoystickComponent joystick;
  final double speed = 200.0;
  final String path;

  double hp = 100.0;
  double maxHp = 100.0;
  int level = 1;
  double xp = 0;
  double get maxXp => level * 100.0; // Mỗi level cần lượng EXP tăng dần
  double baseAttackDamage = 20.0;
  double attackDamage = 20.0;

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

  Player({required this.joystick, this.path = '🧙'})
    : super(size: Vector2.all(50), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Thêm va chạm cho người chơi
    add(RectangleHitbox());
    // Sử dụng một hình vuông màu trắng mờ làm nền đại diện cho nhân vật
    body = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.white.withAlpha(40),
    );
    add(body);

    if (path.contains('.') || path.contains('/')) {
      final sprite = await game.loadSprite(path);
      body.add(SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: Anchor.center,
        position: size / 2,
      ));
    } else {
      body.add(TextComponent(
        text: path,
        textRenderer: TextPaint(
          style: TextStyle(
            fontSize: size.x * 0.7,
            fontFamily: 'Arial',
          ),
        ),
        anchor: Anchor.center,
        position: size / 2,
      ));
    }

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
        body.paint.color = Colors.white.withAlpha(40);
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

  /// Sử dụng skill với kỹ năng được xác định bởi [skillData]
  void useSkill(Vector2? direction, SkillData skillData) {
    // Tính sát thương dựa trên stats hiện tại
    final damage = skillData.calculateDamage(
      attackDamage: attackDamage,
      maxHp: maxHp,
      currentHp: hp,
      speed: speed,
    );

    Vector2 shootDir;
    
    if (direction != null) {
      shootDir = direction;
    } else {
      // Auto Aim: Tìm kẻ địch gần nhất
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
        shootDir = WorldConfig.wrappedDirection(position, nearestEnemy.position);
      } else {
        shootDir = Vector2(scale.x > 0 ? 1 : -1, 0);
      }
    }

    if (!skillData.isDamaging) {
      // Skill không gây sát thương (ví dụ: Dash xử lý riêng trong game._handleSkill)
      return;
    }
    
    if (skillData.isMelee) {
      game.world.add(MeleeSlash(position: position.clone(), direction: shootDir, damage: damage));
      game.shake(intensity: 1);
    } else {
      game.world.add(Bullet(position: position.clone(), direction: shootDir, damage: damage));
    }
  }

  /// Giữ lại attack cũ cho tương thích, nhưng delegate qua useSkill
  void attack(Vector2? direction, {bool isMelee = false}) {
    final skillData = isMelee
        ? SkillDatabase.getSkill(SkillType.normal)
        : SkillDatabase.skills.firstWhere(
            (s) => s.isDamaging && !s.isMelee,
            orElse: () => SkillDatabase.getSkill(SkillType.normal),
          );
    useSkill(direction, skillData);
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

  void addXP(double amount) {
    xp += amount;
    while (xp >= maxXp) {
      xp -= maxXp;
      levelUp();
    }
  }

  void levelUp() {
    level++;
    maxHp += 20;
    hp = maxHp; // Hồi đầy máu khi lên level
    baseAttackDamage += 5;
    attackDamage = baseAttackDamage;
    game.showLevelUpEffect();
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
      body.paint.color = Colors.white.withAlpha(40);
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
