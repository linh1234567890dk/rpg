import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flame/effects.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';
import 'components/player.dart';
import 'components/enemy.dart';
import 'components/skill_button.dart';
import 'components/aim_indicator.dart';
import 'components/target_lock_indicator.dart';
import 'components/boss.dart';
import 'components/ranged_enemy.dart';
import 'components/location_name_popup.dart';
import 'components/minimap.dart';
import 'world/world_map.dart';
import 'world/terrain_background.dart';

class RPGGame extends FlameGame with HasCollisionDetection {
  late final Player player;
  late final JoystickComponent joystick;
  late final AimIndicator aimIndicator;
  late final TargetLockIndicator targetLockIndicator;
  
  // Giữ tham chiếu tới các nút skill để cập nhật vị trí khi resize
  SkillButton? attackButton;
  SkillButton? skillButton;
  SkillButton? dashButton;
  
  int score = 0;
  bool bossSpawned = false;
  bool _buttonsInitialized = false;

  @override
  Future<void> onLoad() async {
    // Đảm bảo viewport size khớp với game size ngay từ đầu
    camera.viewport.size = size;

    // 1. Setup Joystick (Bên trái)
    final knobPaint = BasicPalette.blue.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.blue.withAlpha(100).paint();
    
    joystick = JoystickComponent(
      knob: CircleComponent(radius: 30, paint: knobPaint),
      background: CircleComponent(radius: 80, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );

    // 2. Setup Player
    player = Player(joystick: joystick);
    
    // 3. Setup Aim Indicator
    aimIndicator = AimIndicator();
    
    // Setup Target Lock Indicator
    targetLockIndicator = TargetLockIndicator();
    targetLockIndicator.priority = -1; // Nằm dưới quái
    
    // 4. Setup Skill Buttons (Bên phải)
    attackButton = SkillButton(
      type: SkillType.normal,
      position: Vector2.zero(),
      cooldown: 0.5,
      onAction: () => _handleSkill(SkillType.normal, null),
      onAimAction: (dir) => _handleSkill(SkillType.normal, dir),
    );

    skillButton = SkillButton(
      type: SkillType.special,
      position: Vector2.zero(),
      cooldown: 3.0,
      onAction: () => _handleSkill(SkillType.special, null),
      onAimAction: (dir) => _handleSkill(SkillType.special, dir),
    );

    dashButton = SkillButton(
      type: SkillType.dash,
      position: Vector2.zero(),
      cooldown: 1.5,
      onAction: () {
        final dir = Vector2(player.scale.x > 0 ? 1 : -1, 0);
        _handleSkill(SkillType.dash, dir);
      },
      onAimAction: (dir) => _handleSkill(SkillType.dash, dir),
    );

    // Thêm vào viewport (HUD)
    camera.viewport.add(joystick);
    camera.viewport.add(attackButton!);
    camera.viewport.add(skillButton!);
    camera.viewport.add(dashButton!);

    // Add terrain background (priority thấp nhất để nằm dưới tất cả)
    final terrain = TerrainBackground();
    terrain.priority = -1000;
    world.add(terrain);

    // Add location name popup (HUD - trong viewport)
    final locationPopup = LocationNamePopup();
    locationPopup.priority = 1000;
    camera.viewport.add(locationPopup);

    // Add minimap (HUD - trong viewport, góc phải trên)
    final minimap = Minimap();
    minimap.priority = 999;
    camera.viewport.add(minimap);

    // Add components to World
    world.add(player);
    world.add(aimIndicator);
    world.add(targetLockIndicator);

    // Cấu hình Camera để luôn theo dõi Player
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(player);

    // Thêm thanh máu của người chơi lên HUD
    _setupPlayerHPBar();

    // Spawn quái vật tại các bãi cố định
    _spawnInitialEnemies();
    
    // Layout nút skill lần đầu
    _buttonsInitialized = true;
    _layoutButtons();
  }

  /// Căn chỉnh lại vị trí các nút skill dựa trên kích thước viewport hiện tại
  void _layoutButtons() {
    // onGameResize() có thể được gọi TRƯỚC onLoad(), nên cần kiểm tra flag
    if (!_buttonsInitialized) return;
    final atk = attackButton;
    final sk = skillButton;
    final dsh = dashButton;
    if (atk == null || sk == null || dsh == null) return;

    final vpSize = camera.viewport.size;
    if (vpSize.x <= 0 || vpSize.y <= 0) return;

    // Tính toán kích thước nút dựa trên màn hình (tối thiểu 60, tối đa 80)
    final buttonSize = (vpSize.x / 8).clamp(60.0, 80.0);
    final padding = buttonSize * 0.3; // Khoảng cách giữa các nút

    // Đặt nút ATK ở góc dưới-phải
    atk.size = Vector2.all(buttonSize);
    atk.position = Vector2(vpSize.x - buttonSize / 2 - 20, vpSize.y - buttonSize / 2 - 20);

    // Đặt nút SKILL ở bên trái ATK
    sk.size = Vector2.all(buttonSize);
    sk.position = Vector2(
      vpSize.x - buttonSize * 1.5 - padding - 20,
      vpSize.y - buttonSize / 2 - 20,
    );

    // Đặt nút DASH ở phía trên ATK
    dsh.size = Vector2.all(buttonSize);
    dsh.position = Vector2(
      vpSize.x - buttonSize / 2 - 20,
      vpSize.y - buttonSize * 1.5 - padding - 20,
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    camera.viewport.size = size;
    // Cập nhật lại vị trí các nút khi màn hình thay đổi kích thước
    _layoutButtons();
  }

  void _setupPlayerHPBar() {
    final hpBg = RectangleComponent(
      size: Vector2(200, 20),
      position: Vector2(20, 20),
      paint: Paint()..color = Colors.black.withAlpha(100),
    );
    
    final hpFill = RectangleComponent(
      size: Vector2(200, 20),
      position: Vector2(0, 0),
      paint: Paint()..color = Colors.green,
    );
    
    final ghostHpFill = RectangleComponent(
      size: Vector2(200, 20),
      position: Vector2(0, 0),
      paint: Paint()..color = Colors.white.withAlpha(150),
    );
    
    hpBg.add(ghostHpFill); // Thanh trắng nằm dưới
    hpBg.add(hpFill);      // Thanh xanh nằm trên
    camera.viewport.add(hpBg);

    // Cập nhật thanh máu liên tục
    hpFill.add(TimerComponent(
      period: 0.05, // Cập nhật nhanh hơn để mượt
      repeat: true,
      onTick: () {
        final dt = 0.05;
        // Tụt ngay lập tức
        hpFill.width = (player.hp / player.maxHp) * 200;
        
        // Ghost HP co lại từ từ
        if (ghostHpFill.width > hpFill.width) {
          ghostHpFill.width -= 100 * dt; 
          if (ghostHpFill.width < hpFill.width) {
            ghostHpFill.width = hpFill.width;
          }
        } else {
          ghostHpFill.width = hpFill.width;
        }

        if (player.hp < player.maxHp * 0.3) {
          hpFill.paint.color = Colors.red;
        } else {
          hpFill.paint.color = Colors.green;
        }
      },
    ));
  }

  void _spawnInitialEnemies() {
    final rnd = math.Random();
    for (final zone in WorldMap.zones) {
      int count = (zone.radius * zone.spawnDensity / 70).clamp(3, 8).toInt();
      for (int i = 0; i < count; i++) {
        Vector2 spawnPos = Vector2.zero();
        bool foundValidPos = false;
        
        for (int attempt = 0; attempt < 10; attempt++) {
          final angle = rnd.nextDouble() * 2 * math.pi;
          final r = rnd.nextDouble() * zone.radius;
          spawnPos = Vector2(
            zone.centerX + r * math.cos(angle),
            zone.centerY + r * math.sin(angle),
          );
          if (!WorldMap.isInSafeZone(spawnPos)) {
            foundValidPos = true;
            break;
          }
        }
        
        if (!foundValidPos) continue;

        final level = rnd.nextInt(zone.maxLevel - zone.minLevel + 1) + zone.minLevel;
        final isRanged = zone.enemyTypes.contains('ranged') && rnd.nextDouble() < 0.4;
        
        if (isRanged) {
          world.add(RangedEnemy(position: spawnPos, level: level)..spawnPosition = spawnPos.clone());
        } else {
          world.add(Enemy(position: spawnPos, level: level)..spawnPosition = spawnPos.clone());
        }
      }
    }

    // Spawn Boss tại Núi Lửa Tử Thần (4000, 1500)
    world.add(Boss(position: Vector2(4000, 1500))..spawnPosition = Vector2(4000, 1500));
  }

  void scheduleEnemyRespawn(Vector2 spawnPos, int level, bool isRanged) {
    world.add(TimerComponent(
      period: 10,
      repeat: false,
      onTick: () {
        if (isRanged) {
          world.add(RangedEnemy(position: spawnPos.clone(), level: level)..spawnPosition = spawnPos.clone());
        } else {
          world.add(Enemy(position: spawnPos.clone(), level: level)..spawnPosition = spawnPos.clone());
        }
      },
    ));
  }

  void shake({double intensity = 5, double duration = 0.2}) {
    final rnd = math.Random();
    for (int i = 0; i < 10; i++) {
      camera.viewfinder.add(
        MoveEffect.by(
          Vector2(
            (rnd.nextDouble() - 0.5) * intensity,
            (rnd.nextDouble() - 0.5) * intensity,
          ),
          EffectController(duration: duration / 10),
        ),
      );
    }
  }

  void addScore(int points) {
    score += points;
    if (score % 5 == 0) {
      // Mỗi 5 điểm tăng độ khó hoặc hiệu ứng gì đó
    }
  }

  void showHitEffect(Vector2 position, Color color) {
    world.add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 8,
          lifespan: 0.3,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2.zero(),
            speed: Vector2(
              (math.Random().nextDouble() - 0.5) * 400,
              (math.Random().nextDouble() - 0.5) * 400,
            ),
            position: position.clone(),
            child: CircleParticle(
              radius: 2,
              paint: Paint()..color = color,
            ),
          ),
        ),
      ),
    );
  }

  void showAimIndicator(Vector2 direction) {
    aimIndicator.position = player.position.clone();
    aimIndicator.direction = direction;
    aimIndicator.isVisible = true;
  }

  void hideAimIndicator() {
    aimIndicator.isVisible = false;
  }

  void _handleSkill(SkillType type, Vector2? direction) {
    if (type == SkillType.dash) {
      if (direction != null) {
        player.dash(direction);
      }
    } else {
      final isMelee = type == SkillType.normal;
      player.attack(direction, isMelee: isMelee);
    }
  }

  void gameOver() {
    if (overlays.isActive('gameOver')) return;
    overlays.add('gameOver');
  }

  void restart() {
    overlays.remove('gameOver');
    world.removeAll(world.children);
    camera.viewport.removeAll(camera.viewport.children);
    score = 0;
    bossSpawned = false;
    _buttonsInitialized = false;

    // Re-add terrain background
    final terrain = TerrainBackground();
    terrain.priority = -1000;
    world.add(terrain);

    // Re-setup player
    player = Player(joystick: joystick);
    world.add(player);
    world.add(aimIndicator);
    world.add(targetLockIndicator);
    camera.follow(player);

    // Re-add location name popup
    final locationPopup = LocationNamePopup();
    locationPopup.priority = 1000;
    camera.viewport.add(locationPopup);

    // Re-add minimap
    final minimap = Minimap();
    minimap.priority = 999;
    camera.viewport.add(minimap);

    // Re-add HUD controls
    camera.viewport.add(joystick);
    camera.viewport.add(attackButton!);
    camera.viewport.add(skillButton!);
    camera.viewport.add(dashButton!);

    // Re-add HP bar
    _setupPlayerHPBar();
    
    // Layout nút skill
    _layoutButtons();
  }

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);
}
