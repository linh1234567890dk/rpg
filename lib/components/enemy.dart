import 'dart:math' as math;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'enemy_attack_effect.dart';
import 'bullet.dart';
import '../rpg_game.dart';
import '../utils/world_config.dart';
import '../utils/enemy_config.dart';
import '../utils/attack_style.dart';

enum EnemyState {
  idle,
  chasing,
  returning,
}

/// Enemy duy nhất — mọi hành vi (cận chiến, bắn đạn, tự sát, boss) đều đọc
/// từ `EnemyData` trong `EnemyDatabase`. Không cần class riêng cho từng loại.
class Enemy extends PositionComponent
    with HasGameReference<RPGGame>, CollisionCallbacks {
  final String id;
  late final EnemyData data;

  int level = 1;
  double hp = 50.0;
  double maxHp = 50.0;
  double speed = 50.0;
  double preferredRange = 0;

  // Knockback & Stun
  double stunTimer = 0;
  Vector2 knockbackVelocity = Vector2.zero();
  double knockbackResist = 0;

  // Cooldown tấn công hiện tại
  double remainingAttackCooldown = 0;

  // Pattern luân phiên nhiều attackStyle (dùng cho boss)
  late final List<AttackStyle> _attackStyles;
  int _currentStyleIndex = 0;
  double _phaseTimer = 0;

  // Tự sát (SuicideAttack)
  bool _exploded = false;
  bool _isSuicide = false;
  double _explosionDamage = 0;
  double _explodeRange = 0;
  double _blastRadius = 0;

  late final RectangleComponent body;
  late final RectangleComponent hpBar;
  late final RectangleComponent ghostHpBar;

  // Điểm spawn gốc và hành vi RPG
  Vector2? spawnPosition;
  double detectionRange = 180.0;
  double tetherRange = 400.0;
  EnemyState state = EnemyState.idle;

  /// EXP thưởng khi tiêu diệt enemy
  double get xpReward => data.xpBase + level * 10.0;

  /// Màu sắc gốc — lấy từ data-driven config
  Color get baseColor => data.color;
  /// Màu khi trúng đòn — lấy từ data-driven config
  Color get hitColor => data.hitColor;

  /// AttackStyle đang dùng (style hiện tại trong pattern)
  AttackStyle get currentStyle => _attackStyles[_currentStyleIndex];

  /// Tầm đánh của style hiện tại (suicide dùng distance riêng)
  double get currentAttackRange {
    final s = currentStyle;
    if (s is MeleeAttack) return s.range;
    if (s is RangedAttack) return s.range;
    return 0;
  }

  Enemy({
    required Vector2 position,
    required this.id,
    this.level = 1,
  }) : super(position: position, anchor: Anchor.center) {
    data = EnemyDatabase.get(id);
    size = Vector2.all(data.size);
    spawnPosition = position.clone();
    _attackStyles = data.attackStyles.isEmpty ? [MeleeAttack()] : data.attackStyles;
    _applyEnemyData();
    _applyLevelScaling();
  }

  /// Áp stats chung từ EnemyData
  void _applyEnemyData() {
    hp = data.baseHp;
    maxHp = hp;
    speed = data.baseSpeed;
    detectionRange = data.detectionRange;
    tetherRange = data.tetherRange;
    preferredRange = data.preferredRange;
    knockbackResist = data.knockbackResist;

    // Kiểm tra có phải quái suicide không
    for (final s in _attackStyles) {
      if (s is SuicideAttack) {
        _isSuicide = true;
        _explosionDamage = s.explosionDamage;
        _explodeRange = s.explodeRange;
        _blastRadius = s.blastRadius;
        break;
      }
    }
  }

  /// Scale stats theo level
  void _applyLevelScaling() {
    final scale = 1.0 + (level - 1) * 0.3;
    hp = hp * scale;
    maxHp = hp;
    speed = speed * (1.0 + (level - 1) * 0.1);
  }

  @override
  Future<void> onLoad() async {
    body = RectangleComponent(
      size: size,
      paint: Paint()..color = baseColor.withAlpha(40),
    );
    add(body);

    if (data.path.contains('.') || data.path.contains('/')) {
      final sprite = await game.loadSprite(data.path);
      body.add(SpriteComponent(
        sprite: sprite,
        size: size,
        anchor: Anchor.center,
        position: size / 2,
      ));
    } else {
      body.add(TextComponent(
        text: data.path,
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
      _finishUpdate(dt);
      return; // Không làm gì khác khi bị choáng
    }

    // Nếu là quái tự sát (suicide), lao thẳng vào player rồi nổ
    if (_isSuicide && !_exploded) {
      _updateSuicide(dt, distToPlayer);
      return;
    }

    // Cập nhật pattern (đổi attackStyle định kỳ nếu có phaseInterval)
    _updatePattern(dt);

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
        final range = currentAttackRange;
        if (distToPlayer > range) {
          // Nếu ở xa, đuổi theo người chơi (có tính wrapping)
          final direction = WorldConfig.wrappedDirection(position, player.position);
          position.add(direction * speed * dt);
        } else {
          // Nếu đủ gần trong phạm vi tấn công, dừng lại và đánh
          if (remainingAttackCooldown <= 0) {
            performAttack();
          }
          // Khi đang trong cooldown, enemy đứng yên để người chơi có cơ hội né
          // Với ranged: lùi lại để giữ khoảng cách
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

    _finishUpdate(dt);
  }

  /// Luân phiên attackStyle định kỳ (chỉ hiệu lực khi phaseInterval > 0)
  void _updatePattern(double dt) {
    if (_attackStyles.length <= 1 || data.phaseInterval <= 0) return;
    _phaseTimer += dt;
    if (_phaseTimer >= data.phaseInterval) {
      _phaseTimer = 0;
      _currentStyleIndex = (_currentStyleIndex + 1) % _attackStyles.length;
    }
  }

  /// Cập nhật chung: y-sort, thanh máu, xử lý chết
  void _finishUpdate(double dt) {
    // Y-sorting
    priority = position.y.toInt();

    // Cập nhật thanh máu chính (tụt ngay lập tức)
    hpBar.width = (hp / maxHp) * size.x;

    // Cập nhật thanh Ghost HP (co lại từ từ sau khi thanh chính tụt)
    if (ghostHpBar.width > hpBar.width) {
      // Giảm dần chiều rộng thanh trắng (tốc độ co lại)
      ghostHpBar.width -= 50 * 0.016;
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
      // Nếu là suicide, nổ khi chết
      if (_isSuicide && !_exploded) {
        explode();
      }
      // Respawn theo cấu hình data-driven (boss/imp không respawn)
      if (data.canRespawn) {
        game.scheduleEnemyRespawn(spawnPosition ?? position, level, id);
      }
      removeFromParent();
    }
  }

  /// Logic quái tự sát: lao vào player rồi nổ
  void _updateSuicide(double dt, double distToPlayer) {
    final player = game.player;
    if (state == EnemyState.chasing) {
      final dir = WorldConfig.wrappedDirection(position, player.position);
      position.add(dir * speed * 1.5 * dt);
      position = WorldConfig.wrapPosition(position);
      if (distToPlayer <= _explodeRange) {
        explode();
        return;
      }
    }
    _finishUpdate(dt);
  }

  void performAttack() {
    final style = currentStyle;

    if (style is RangedAttack) {
      remainingAttackCooldown = style.cooldown;
      _performRanged(style);
    } else if (style is MeleeAttack) {
      remainingAttackCooldown = style.cooldown;
      _performMelee(style);
    } else if (style is SuicideAttack) {
      // Quái tự sát không tấn công phạm vi — tự xử lý trong update
      return;
    }
  }

  /// Đòn cận chiến: vệt chém sát thương
  void _performMelee(MeleeAttack style) {
    final dir = WorldConfig.wrappedDirection(position, game.player.position);
    if (dir.x < 0 && scale.x > 0) {
      flipHorizontallyAroundCenter();
    } else if (dir.x > 0 && scale.x < 0) {
      flipHorizontallyAroundCenter();
    }

    // Sát thương scale theo level
    final dmg = style.damage * (1.0 + (level - 1) * 0.3);

    // Hiệu ứng "gồng" đòn (nháy màu trắng trước khi đánh)
    body.paint.color = Colors.white;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isMounted) return;
      body.paint.color = baseColor;
      game.world.add(EnemyAttackEffect(position: position.clone(), direction: dir, damage: dmg));
      game.shake(intensity: 1);
    });
  }

  /// Đòn bắn đạn dùng chung — nhận cấu hình từ `RangedAttack` model.
  void _performRanged(RangedAttack style) {
    body.paint.color = Colors.white;
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!isMounted) return;
      body.paint.color = baseColor;

      // Sát thương scale theo level
      final dmg = style.damage * (1.0 + (level - 1) * 0.3);

      for (int i = 0; i < style.count; i++) {
        Vector2 dir;
        if (style.spread) {
          // Tỏa đều vòng tròn
          final angle = (i * (360 / style.count)) * 0.0174533;
          dir = Vector2(math.cos(angle), math.sin(angle));
        } else {
          final player = game.player;
          // Nhắm về phía player
          if (style.count == 1) {
            final diff = player.position - position;
            if (diff.length < 10) return;
            dir = diff.normalized();
          } else {
            // Nhiều đạn nhắm player, chệch nhẹ mỗi phát
            final baseAngle = (player.position - position).angleTo(Vector2(1, 0));
            final angle = baseAngle + (i - (style.count - 1) / 2) * 0.2;
            dir = Vector2(math.cos(angle), math.sin(angle));
          }
        }

        game.world.add(Bullet(
          position: position.clone() + dir * (size.x / 2 + 5),
          direction: dir,
          color: style.color,
          damage: dmg,
        )..speed = style.speed);
      }
      game.shake(intensity: 1);
    });
  }

  /// Kích nổ quái tự sát — gây sát thương diện rộng quanh vị trí
  void explode() {
    if (_exploded) return;
    _exploded = true;

    final player = game.player;
    final dist = WorldConfig.wrappedDistance(position, player.position);
    if (dist <= _blastRadius) {
      final dir = WorldConfig.wrappedDirection(position, player.position);
      player.takeDamage(_explosionDamage, knockbackDirection: dir);
    }

    game.shake(intensity: 6, duration: 0.3);
    game.showHitEffect(position.clone(), Colors.orange);
    removeFromParent();
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

  /// Hook xử lý khi đang trong phạm vi tấn công (giữa các đòn)
  void handleInRange(double dt, double distance) {
    // Với ranged: lùi lại giữ khoảng cách nếu player quá gần
    if (currentStyle is RangedAttack && preferredRange > 0) {
      if (distance < preferredRange - 30) {
        final dir = WorldConfig.wrappedDirection(game.player.position, position);
        position.add(dir * speed * 1.5 * dt);
      }
    }
  }

  void takeDamage(double damage, {Vector2? knockbackDirection}) {
    if (state == EnemyState.returning) return; // Không thể tấn công khi quái đang chạy về
    
    hp -= damage;
    game.shake(intensity: 2); // Rung nhẹ khi quái trúng đòn
    game.showHitEffect(position.clone(), Colors.orange); // Hiệu ứng tia lửa

    // Nếu không trong trạng thái choáng thì mới bị đẩy lùi (có kháng knockback)
    if (stunTimer <= 0 && knockbackDirection != null) {
      knockbackVelocity = knockbackDirection * (200 * (1 - knockbackResist)); // Độ mạnh của lực đẩy
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