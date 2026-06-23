# Kế hoạch mở rộng: RPG thành Open-World với Seamless World

## 1. Mục tiêu tổng quan

- **Biến game thành thế giới mở (open-world)** với 3 ngôi làng + 1 thành phố
- **Cơ chế seamless wraparound**: đi đến mép trái xuất hiện bên phải (và tương tự trên/dưới)
- **Vùng đánh quái** giữa các khu định cư, độ khó tăng dần

---

## 2. Seamless Wraparound World

### 2.1 Định nghĩa kích thước thế giới

```dart
class WorldConfig {
  static const double worldWidth = 16000;
  static const double worldHeight = 10000;
}
```

### 2.2 Xử lý wrapping cho tất cả entity

**Player (player.dart):**
- Trong `update()`, sau khi di chuyển: kiểm tra và wrap position
- Dash cũng wrap
- `_updateTargetLock()`: tính khoảng cách có tính wrapping (chọn đường ngắn nhất)

**Enemy & Boss (enemy.dart, boss.dart):**
- Trong `update()`, wrap position
- AI đuổi theo player: tính hướng di chuyển qua đường ngắn nhất có wrapping
- `performAttack()`: target direction có wrapping

**Bullet, MeleeSlash, EnemyAttackEffect:**
- Wrap position mỗi frame
- Nếu wrap > 2 lần (lạc quá xa) thì remove

**DashAfterImage:**
- Wrap position

**EnemySpawn (rpg_game.dart):**
- Spawn quái ở vị trí có wrapping (tính từ camera position)

### 2.3 Camera

- Camera vẫn follow player — tự nhiên wrap theo
- Cần xử lý: nếu player ở gần mép, camera nhìn xuyên biên giới? Có thể không cần, vì wrap là tức thời

### 2.4 Utility: `Vector2 wrapPosition(Vector2 pos)`

```dart
Vector2 wrapPosition(Vector2 pos) {
  double x = pos.x % WorldConfig.worldWidth;
  if (x < 0) x += WorldConfig.worldWidth;
  double y = pos.y % WorldConfig.worldHeight;
  if (y < 0) y += WorldConfig.worldHeight;
  return Vector2(x, y);
}
```

### 2.5 Utility: Khoảng cách ngắn nhất có wrapping

```dart
double wrappedDistance(Vector2 a, Vector2 b) {
  double dx = (b.x - a.x).abs();
  dx = min(dx, WorldConfig.worldWidth - dx);
  double dy = (b.y - a.y).abs();
  dy = min(dy, WorldConfig.worldHeight - dy);
  return sqrt(dx * dx + dy * dy);
}

Vector2 wrappedDirection(Vector2 from, Vector2 to) {
  double dx = to.x - from.x;
  double dy = to.y - from.y;
  if (dx.abs() > WorldConfig.worldWidth / 2) {
    dx = -dx.sign * (WorldConfig.worldWidth - dx.abs());
  }
  if (dy.abs() > WorldConfig.worldHeight / 2) {
    dy = -dy.sign * (WorldConfig.worldHeight - dy.abs());
  }
  return Vector2(dx, dy).normalized();
}
```

---

## 3. Open-World Map & Locations

### 3.1 Cấu trúc dữ liệu thế giới

**File mới: `lib/world/world_map.dart`**

```dart
enum LocationType { village, city, monsterZone, forest, desert, mountain }

class WorldLocation {
  final String name;
  final LocationType type;
  final Vector2 center;
  final double radius;      // Bán kính vùng an toàn (không spawn quái)
  final Color mapColor;     // Màu trên minimap
  final String description;
}

class WorldMap {
  static const List<WorldLocation> locations = [
    // 3 ngôi làng
    WorldLocation(name: 'Làng Ánh Dương', type: LocationType.village, 
                  center: Vector2(2000, 2000), radius: 400, mapColor: Colors.green),
    WorldLocation(name: 'Làng Nguyệt Quế', type: LocationType.village,
                  center: Vector2(8000, 6000), radius: 400, mapColor: Colors.green),
    WorldLocation(name: 'Làng Sao Băng', type: LocationType.village,
                  center: Vector2(14000, 3000), radius: 400, mapColor: Colors.green),
    // 1 thành phố
    WorldLocation(name: 'Thành Phố Hoàng Kim', type: LocationType.city,
                  center: Vector2(8000, 8000), radius: 600, mapColor: Colors.yellow),
  ];
  
  // Vùng quái theo khu vực
  static final Map<String, ZoneConfig> zones = { ... };
}
```

### 3.2 Zone-based Enemy Spawning

- Mỗi khu vực có loại quái, độ khó, mật độ riêng
- Ở gần làng/thành phố: quái yếu, thưa
- Càng xa: quái mạnh, dày đặc
- File cấu hình: `lib/world/zone_config.dart`

### 3.3 Vùng an toàn (Safe Zones)

- Trong bán kính `radius` của village/city: **không spawn quái**
- Player có thể hồi máu khi đứng trong vùng an toàn
- Hiển thị tên địa danh khi player bước vào

---

## 4. HUD & Minimap

### 4.1 Minimap

- Hiển thị ở góc màn hình
- Chấm trắng = vị trí player
- Chấm màu = làng (xanh), thành phố (vàng)
- Ô vuông nhỏ = viewport hiện tại

### 4.2 Location Name Popup

- Khi player đi vào vùng địa danh, hiển thị tên ở giữa màn hình (fade in/out)
- Kiểu như "Welcome to..." trong game nhập vai

---

## 5. Địa hình & Visual

### 5.1 Terrain Background

- Sử dụng các hình chữ nhật màu lớn làm nền:
  - Đồng cỏ xanh (vùng làng)
  - Rừng rậm (vùng quái trung bình)
  - Sa mạc (vùng quái khó)
  - Núi đá (vùng boss)
- Hoặc vẽ grid pattern với màu sắc khác nhau

### 5.2 World Border Visual

- Khi player ở gần mép, có thể thấy "bầu trời" hoặc "sương mù" để tạo illusion thế giới liền mạch? Không cần vì wrap là tức thời.

---

## 6. Implementation Steps (Thứ tự ưu tiên)

### Phase 1: World Map & Terrain ⭐
- [ ] Tạo `lib/world/location.dart` (WorldLocation model)
- [ ] Tạo `lib/world/world_map.dart` (danh sách 3 làng + 1 thành phố)
- [ ] Tạo terrain background component (màu nền theo khu vực)
- [ ] Vẽ 3 làng + 1 thành phố trên world

### Phase 2: Safe Zones & Location Detection ⭐
- [ ] Kiểm tra player ở trong location nào mỗi frame
- [ ] Không spawn quái trong safe zone
- [ ] Hồi máu khi ở safe zone
- [ ] Hiển thị tên địa danh khi vào/ra

### Phase 3: Zone-based Difficulty ⭐
- [ ] Định nghĩa các monster zone (quái yếu gần làng, mạnh xa làng)
- [ ] Spawn quái khác nhau theo zone (level, type, density)
- [ ] Cân bằng độ khó

### Phase 4: Minimap
- [ ] Tạo `lib/components/minimap.dart`
- [ ] Vẽ world map thu nhỏ
- [ ] Hiển thị player position, locations, viewport

### Phase 5: Seamless Wraparound World (làm cuối)
- [ ] Tạo `lib/utils/world_config.dart` (kích thước world, wrap utilities)
- [ ] Thêm wrapping vào `Player.update()`
- [ ] Thêm wrapping vào `Enemy.update()` + boss
- [ ] Thêm wrapping vào `Bullet`, `MeleeSlash`, `EnemyAttackEffect`, `DashAfterImage`
- [ ] Sửa `_spawnEnemy()` để spawn ở vị trí đúng

### Phase 6: Polish
- [ ] Visual effects cho terrain
- [ ] Sound/music theo zone (nếu có)
- [ ] Fast travel giữa các địa danh đã khám phá? (tùy chọn)

---

## 7. File structure mới

```
lib/
├── main.dart
├── rpg_game.dart
├── utils/
│   └── world_config.dart       # Kích thước world, wrap utilities
├── world/
│   ├── location.dart            # WorldLocation model
│   ├── world_map.dart           # Danh sách locations + zones
│   └── terrain_background.dart  # Component vẽ nền terrain
├── components/
│   ├── player.dart              # (sửa: thêm wrapping)
│   ├── enemy.dart               # (sửa: thêm wrapping + AI wrapped)
│   ├── boss.dart                # (sửa: thêm wrapping)
│   ├── bullet.dart              # (sửa: thêm wrapping)
│   ├── melee_slash.dart         # (sửa: thêm wrapping)
│   ├── enemy_attack_effect.dart # (sửa: thêm wrapping)
│   ├── dash_after_image.dart    # (sửa: thêm wrapping)
│   ├── minimap.dart             # (MỚI) Minimap góc màn hình
│   ├── location_name_overlay.dart # (MỚI) Popup tên địa danh
│   ├── ... (giữ nguyên)
```

---

## 8. Cân nhắc kỹ thuật

### Vấn đề với wrapping:
- **Collision detection**: Flame's `HasCollisionDetection` dùng AABB trong không gian Euclid. Khi wrap, entity ở mép trái và mép phải không thể va chạm tự nhiên. Giải pháp: tạm thời dùng distance check thủ công.
- **AI pathfinding**: Enemy đuổi theo player cần tính hướng qua wrapped direction. Đơn giản là dùng `wrappedDirection()`.
- **Camera**: Khi player ở sát mép và wrap, camera sẽ giật. Có thể thêm smooth transition bằng cách cho player wrap sau khi đi qua mép thêm 1 khoảng "buffer".

### Lưu ý performance:
- Minimap cập nhật mỗi 0.5s thay vì mỗi frame
- Terrain background vẽ một lần, không update
- Spawn timer vẫn 3s, nhưng chỉ spawn khi player ở trong vùng quái

---

## 9. Ghi chú

- Đây là bản kế hoạch có thể điều chỉnh
- Phase 1-3 là quan trọng nhất để có thể chơi được (world, safe zone, zone difficulty)
- Seamless Wraparound (Phase 5) làm cuối vì nó là tính năng "nâng cao" — game vẫn chơi được mà không cần nó
- Nên làm theo thứ tự để dễ test từng bước
