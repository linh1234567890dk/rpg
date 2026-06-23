import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'components/game_over_overlay.dart';
import 'rpg_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khóa màn hình ngang để chơi game RPG tốt hơn
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Ẩn thanh trạng thái
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    GameWidget(
      game: RPGGame(),
      overlayBuilderMap: {
        'gameOver': (BuildContext context, RPGGame game) {
          return GameOverOverlay(game: game);
        },
      },
    ),
  );
}

