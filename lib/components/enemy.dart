import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy_attack_effect.dart';
import '../rpg_game.dart';
import '../utils/world_config.dart';
import 'boss.dart';
import 'ranged_enemy.dart';

enum EnemyState {
  idle,
  chasing,
  returning,
}

class Enemy extends PositionComponent
    with HasGameReference<RPGGame>, CollisionCallbacks {
  int level = 1;
  double hp = 50.0;
  late final double maxHp;
  double speed = 50.0;

  // Thông số tấn công
  double attackRange = 60.0;
  double attackCooldown = 1.5;
  double remainingAttackCooldown = 0;
  double attackDamage = 10.0;

  // Knockback & Stun
  double stunTimer = 0;
  Vector2 knockbackVelocity = Vector2.zero();

  late final RectangleComponent body;
  late final RectangleComponent hpBar;
  late final RectangleComponent ghostHpBar;

  // Điểm spawn gốc và hành vi RPG
  Vector2? spawnPosition;
  double detectionRange = 180.0;
  double tetherRange = 400.0;
  EnemyState state = EnemyState.idle;

  /// EXP thưởng khi tiêu diệt enemy
  double get xpReward => 20.0 + level * 10.0;

  /// Màu sắc gốc — subclass có thể override
  Color get baseColor => Colors.red;
  /// Màu khi trúng đòn — subclass có thể override
  Color get hitColor => Colors.orange;

  Enemy({required Vector2 position, Vector2? size, this.level = 1})
    : super(position: position, size: size ?? Vector2.all(40), anchor: Anchor.center) {
    spawnPosition = position.clone();
    _applyLevelScaling();
  }

  /// Scale stats theo level
  void _applyLevelScaling() {
    final scale = 1.0 + (level - 1) * 0.3;
    hp = hp * scale;
    maxHp = hp;
    speed = speed * (1.0 + (level - 1) * 0.1);
    attackDamage = attackDamage * scale;
  }

  @override
  Future<void> onLoad() async {
    body = RectangleComponent(size: size, paint: Paint()..color = baseColor);
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
    final currentSpawnPos = spawnPosition ?? position;
    final distToPlayer = WorldConfig.wrappedDistance(position, player.position);
    final distToSpawn = WorldConfig.wrappedDistance(position, currentSpawnPos);

    // Xử lý Stun & Knockback
    if (stunTimer > 0 && state != EnemyState.returning) {
      stunTimer -= dt;
      // Di chuyển theo lực đẩy lùi (giảm dần theo thời gian)
      position.add(knockbackVelocity * dt);
      knockbackVelocity *= 0.9; // Ma sát làm chậm lực đẩy
      position = WorldConfig.wrapPosition(position);
      return; // Không làm gì khác khi bị choáng
    }

    if (remainingAttackCooldown > 0) {
      remainingAttackCooldown -= dt;
    }

    // AI Logic theo State
    if (state == EnemyState.idle) {
      if (distToPlayer <= detectionRange) {
        state = EnemyState.chasing;
      } else if (distToSpawn > 10) {
        // Quay lại điểm spawn nếu bị trôi đi chỗ khác
        final direction = WorldConfig.wrappedDirection(position, currentSpawnPos);
        position.add(direction * speed * dt);
      }
    } else if (state == EnemyState.chasing) {
      if (distToSpawn > tetherRange) {
        state = EnemyState.returning;
      } else {
        if (distToPlayer > attackRange) {
          // Nếu ở xa, đuổi theo người chơi (có tính wrapping)
          final direction = WorldConfig.wrappedDirection(position, player.position);
          position.add(direction * speed * dt);
        } else {
          // Nếu đủ gần trong phạm vi tấn công, dừng lại và đánh
          if (remainingAttackCooldown <= 0) {
            performAttack();
          }
          // Khi đang trong cooldown, enemy đứng yên để người chơi có cơ hội né
          // Với RangedEnemy: lùi lại để giữ khoảng cách
          handleInRange(dt, distToPlayer);
        }
      }
    } else if (state == EnemyState.returning) {
      // Hồi máu dần khi đang chạy về
      hp = (hp + maxHp * 0.2 * dt).clamp(0.0, maxHp);
      
      if (distToSpawn > 10) {
        final direction = WorldConfig.wrappedDirection(position, currentSpawnPos);
        position.add(direction * speed * 1.5 * dt); // Di chuyển nhanh hơn khi về nhà
      } else {
        position.setFrom(currentSpawnPos);
        hp = maxHp;
        state = EnemyState.idle;
      }
    }

    // Wrap position
    position = WorldConfig.wrapPosition(position);

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
      game.player.addXP(xpReward);
      if (this is! Boss) {
        game.scheduleEnemyRespawn(currentSpawnPos, level, this is RangedEnemy);
      }
      removeFromParent();
    }
  }

  void performAttack() {
    remainingAttackCooldown = attackCooldown;

    // Hướng tấn công tới người chơi (có tính wrapping)
    final dir = WorldConfig.wrappedDirection(position, game.player.position);
    
    // Quay mặt về phía người chơi khi đánh
    if (dir.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (dir.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    // Hiệu ứng "gồng" đòn (nháy màu trắng trước khi đánh)
    body.paint.color = Colors.white;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isMounted) return;
      body.paint.color = baseColor;

      // Tạo hiệu ứng vệt chém thực sự — đây là đòn đánh có hitbox riêng
      game.world.add(EnemyAttackEffect(position: position.clone(), direction: dir, damage: attackDamage));

      // Rung nhẹ khi quái tung đòn
      game.shake(intensity: 1);
    });
  }

  @override
  void renderTree(Canvas canvas) {
    super.renderTree(canvas);

    // Ghost copies khi gần mép
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

  /// Hook cho subclass xử lý khi enemy đang trong phạm vi tấn công (giữa các đòn)
  void handleInRange(double dt, double distance) {
    // Mặc định không làm gì — enemy thường đứng yên
  }

  void takeDamage(double damage, {Vector2? knockbackDirection}) {
    if (state == EnemyState.returning) return; // Không thể tấn công khi quái đang chạy về
    
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
    body.paint.color = hitColor;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!isMounted) return;
      body.paint.color = baseColor;
    });
  }
}
