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

class RPGGame extends FlameGame with HasCollisionDetection {
  late final Player player;
  late final JoystickComponent joystick;
  late final AimIndicator aimIndicator;
  late final TargetLockIndicator targetLockIndicator;
  
  int score = 0;
  bool bossSpawned = false;

  @override
  Future<void> onLoad() async {
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
    final vpSize = camera.viewport.size;
    
    final attackButton = SkillButton(
      type: SkillType.normal,
      position: Vector2(vpSize.x - 80, vpSize.y - 80),
      cooldown: 0.5,
      onAction: () => _handleSkill(SkillType.normal, null),
      onAimAction: (dir) => _handleSkill(SkillType.normal, dir),
    );

    final skillButton = SkillButton(
      type: SkillType.special,
      position: Vector2(vpSize.x - 170, vpSize.y - 70),
      cooldown: 3.0,
      onAction: () => _handleSkill(SkillType.special, null),
      onAimAction: (dir) => _handleSkill(SkillType.special, dir),
    );

    final dashButton = SkillButton(
      type: SkillType.dash,
      position: Vector2(vpSize.x - 90, vpSize.y - 180),
      cooldown: 1.5,
      onAction: () {
        final dir = Vector2(player.scale.x > 0 ? 1 : -1, 0);
        _handleSkill(SkillType.dash, dir);
      },
      onAimAction: (dir) => _handleSkill(SkillType.dash, dir),
    );

    // Add components to World
    world.add(player);
    world.add(aimIndicator);
    world.add(targetLockIndicator);

    // Cấu hình Camera để luôn theo dõi Player
    camera.viewfinder.anchor = Anchor.center;
    camera.follow(player);

    // Add components to Viewport (HUD)
    camera.viewport.add(joystick);
    camera.viewport.add(attackButton);
    camera.viewport.add(skillButton);
    camera.viewport.add(dashButton);

    // Thêm thanh máu của người chơi lên HUD
    _setupPlayerHPBar();
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
    // 5. Spawn quái vật định kỳ (Thêm vào world)
    world.add(TimerComponent(
      period: 3,
      repeat: true,
      onTick: _spawnEnemy,
    ));
  }
  void _spawnEnemy() {
    // Nếu đạt 10 điểm và chưa có boss, spawn boss
    if (score >= 10 && !bossSpawned) {
      bossSpawned = true;
      final boss = Boss(position: Vector2(size.x - 100, size.y / 2));
      world.add(boss);
      return;
    }

    // Spawn quái thường từ mọi hướng quanh Camera (vị trí người chơi)
    final rnd = math.Random();
    final cameraPos = camera.viewfinder.position;
    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    Vector2 spawnPos;
    
    int side = rnd.nextInt(4); // 0: Trên, 1: Phải, 2: Dưới, 3: Trái
    switch (side) {
      case 0: // Trên
        spawnPos = Vector2(cameraPos.x + (rnd.nextDouble() - 0.5) * size.x, cameraPos.y - halfHeight - 50);
        break;
      case 1: // Phải
        spawnPos = Vector2(cameraPos.x + halfWidth + 50, cameraPos.y + (rnd.nextDouble() - 0.5) * size.y);
        break;
      case 2: // Dưới
        spawnPos = Vector2(cameraPos.x + (rnd.nextDouble() - 0.5) * size.x, cameraPos.y + halfHeight + 50);
        break;
      case 3: // Trái
      default:
        spawnPos = Vector2(cameraPos.x - halfWidth - 50, cameraPos.y + (rnd.nextDouble() - 0.5) * size.y);
        break;
    }

    final enemy = Enemy(position: spawnPos);
    world.add(enemy);
  }

  void shake({double intensity = 5, double duration = 0.2}) {
    // Tạo hiệu ứng rung bằng cách di chuyển camera nhanh
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
    // Tạo 8 hạt bắn ra từ vị trí va chạm
    add(
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
      // Nếu là Normal Attack thì là cận chiến, Special là bắn xa
      final isMelee = type == SkillType.normal;
      player.attack(direction, isMelee: isMelee);
    }
  }

  @override
  Color backgroundColor() => const Color(0xFF1A1A1A);
}
