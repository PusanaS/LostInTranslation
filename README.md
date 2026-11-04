# Lost in Translation — Godot

## Dimensional Rift update (English)

**Story.** You are a Dratalian translator. The East Witch — the last witch who can use Dimension Magic — gives you a rift hourglass to travel back in time and work with her child self. Her magic opens the way; your translations return Nira's stolen grimoire in its own language. Nira's Commander (secretly paid by Dratalia), imperial soldiers, pirates and a storm all try to stop you.

**Mechanics (rules unchanged, only the theme):**

| Old | Now | Art |
| --- | --- | --- |
| Seed (left room = the past) | Small cube the child witch summons | `assets/handmade/objects/cube_small.png` |
| Tree (right room = the present) | The same cube years later, grown large | `cube_large.png` |
| River `W` | Open crack in time — walking in loses | `assets/handmade/tiles/rift_crack.png` |
| Lily pad on river | Sealed crack — walkable | `rift_sealed.png` |

The two rooms are the same place at two times: left = the past (young East Witch), right = the present (you, shown as the chess-piece sprite; the Commander also lives in the present). All handmade art and audio from `LIT_workfile` lives in `assets/handmade/` and is wired through `art/game_art.tres` / `scripts/game_art.gd`. Sprites were cut out of `IngameObject.png` and trimmed of transparent padding.

**Story dialogue** lives in `story/dialogue.json`: speakers (name, portrait, side), scenes (lines, background `bedroom` / `rift` / `rift_guards`, optional `bgm` and `flip`), `triggers` (`before:<level-file>` / `after:<level-file>`) and `level_music`. Edit text there — no code changes needed. In a scene: Space/click/→ advances, Esc skips.

**Debug level select** replaces the level editor: Pause → *Level select (debug)* (debug builds only) jumps to any level or replays any story scene.

**Screenshots:** `godot --path . --script res://tests/capture_shots.gd` saves key screens to `user://shots/`.

Dự án Godot độc lập, chuyển logic từ bản web v1.1.7. Đã kiểm tra trên Godot **4.7.2 Standard**, dùng GDScript, không cần C# hay addon.

## Chạy game

1. Mở Godot → **Import** → chọn `project.godot` trong thư mục này.
2. Chờ Godot nhập các hình SVG lần đầu.
3. Nhấn **F6** khi mở `scenes/main.tscn`, hoặc **F5** để chạy cả project.
4. Level đầu là màn trồng cây tối thiểu: **Space → mũi tên phải**.

Mũi tên điều khiển cả hai nhân vật; Space gieo/nhặt; Z hoàn tác; R chơi lại; Esc mở Pause. Giữ phím không tự lặp. HUD trên cùng luôn hiện seed còn lại; có nút Replay level và Pause với Resume, Level Editor, fullscreen và Quit. Khi cả hai chạm sách, game tự chuyển sang level kế tiếp bằng hiệu ứng blur lan từ cuốn sách. Hai nhân vật phải cùng đứng ở cuốn sách; nhân vật đến trước vẫn có thể di chuyển khỏi đích. Mọi phản hồi trong game xuất hiện dưới dạng toast tiếng Anh ở giữa phía trên màn hình.

## Chơi level JSON từ web editor

1. Thiết kế level trên web editor hiện tại, nhấn **Xuất JSON**.
2. Trong game Godot, nhấn **Mở level JSON…**, chọn file vừa xuất. Hoặc kéo thả file vào cửa sổ game khi chạy riêng.
3. Level hợp lệ được mở ngay và lưu bản sao vào `user://levels/`; lần sau mở game vẫn có trong danh sách. Nút **Mở thư mục level** mở thư mục này trên máy.

File lỗi sẽ hiện thông báo và giữ level đang chơi. Hỗ trợ JSON v1/v2/v3, `rules` riêng cho mỗi phòng, trường `rule` cũ, `seedLimit` hữu hạn hoặc `null`/thiếu để giữ chế độ vô hạn cũ. Không nhập cả thư viện nhiều màn trong một file: mỗi JSON chứa một level đúng như nút Xuất JSON của editor.

## Sửa level

Level editor trong Godot đã được gỡ bỏ (thay bằng *Level select (debug)* trong menu Pause). Thiết kế level bằng web editor.

Để đóng gói level đi cùng game, chép file vào `levels/`, rồi chạy lại. Tên file được sắp xếp alphabet; dùng tiền tố `01-`, `02-` để chọn thứ tự. Có sẵn 7 màn mẫu. Dự án này là game chơi level; việc vẽ level tiếp tục thực hiện ở web editor.

## Thay asset bằng hình tự vẽ

Có **15 slot ảnh độc lập**. Ảnh mẫu 64×64 px; PNG nền trong suốt là lựa chọn thuận tiện cho nhân vật/vật thể. Kích thước ảnh có thể khác, nhưng nên giữ khung vuông để không bị kéo méo. Mỗi ô hiện vẽ ở 48×48; có thể đổi `tile_size` trong `scripts/board_view.gd`.

**Cách khuyên dùng, không sửa code:**

1. Chép PNG/SVG của bạn vào thư mục tương ứng trong `assets/`.
2. Chọn file **`art/game_art.tres`** trong FileSystem của Godot.
3. Trong Inspector, mở nhóm **Tiles / Characters / Objects** và kéo ảnh vào slot tương ứng.
4. Lưu resource, chạy lại game. Không cần đổi JSON level.

| Thư mục | Slot / file mẫu | Vai trò |
| --- | --- | --- |
| `assets/characters/` | `witch_past.svg`, `witch_future.svg` | Nhân vật trái / phải |
| `assets/objects/` | `book.svg` | Đích đến |
| `assets/objects/` | `seed.svg`, `tree.svg`, `lily.svg` | Hạt bên trái, cây và bèo bên phải |
| `assets/tiles/` | `floor.svg`, `wall.svg` | Sàn và tường |
| `assets/tiles/` | `ice.svg`, `hole.svg`, `river.svg` | Băng, hố đen, sông |
| `assets/tiles/` | `door_closed.svg`, `door_open.svg` | Hai trạng thái cửa |
| `assets/tiles/` | `plate_up.svg`, `plate_down.svg` | Hai trạng thái cơ quan |

Cũng có thể thay nội dung SVG mẫu tại đúng đường dẫn. Đổi đuôi SVG thành PNG cần gán lại slot trong `game_art.tres`. Các sprite hiện là hình tĩnh; dự án chưa có bộ animation/sprite sheet. Va chạm phụ thuộc dữ liệu ô, không phụ thuộc kích thước hay hình dạng của tranh. Sàn được vẽ trước; vật thể và nhân vật được vẽ chồng lên. Mã cặp A–Z vẫn được vẽ lên cửa/cơ quan để đọc được mối liên kết.

## Logic giữ nguyên

- Mặc định cả hai đi đúng hướng 1 ô. Giữ 10 rule editor và legacy `rotate` cho JSON tùy chỉnh.
- Hạt trồng từ nhân vật trái; cây ở cùng tọa độ tuyệt đối trên map phải. Trái đi qua hạt, phải bị cây chặn. Space trên hạt nhặt lại và hoàn kho.
- Băng trượt theo hướng vào đến ô thường đầu tiên, vật cản hoặc biên map. Hố đen gây thua ở bất kỳ bước trung gian nào.
- Cửa `D` và cơ quan `P` ghép một–một theo mã, trong cùng phòng. Nhân vật hoặc cây phải đè lên cơ quan mới mở. Rời cơ quan/thu hồi cây thì đóng. Nhân vật đã đứng ở cửa vừa đóng vẫn có thể bước ra. Không trồng cây trên cửa.
- Sông `W` gây thua khi đi vào, giống hố đen cũ. Hạt bên trái tạo bèo ở sông bên phải, cho phép đi qua ô sông đó. Phải rời bèo trước khi thu hồi hạt.
- Gieo hạt làm cây/bèo lớn dần trong khoảng một giây. Phù thủy nhún khi đi, trượt chậm hơn trên băng và bật lại khi cả hai bị chặn; các chuyển động này làm bằng code, không cần sprite sheet.
- Undo/reset phục hồi vị trí, kho hạt, cây/bèo, nhịp rule và trạng thái sống/chết; trạng thái cửa được tính lại từ đó.
- Start/goal có thể trên cơ quan hoặc băng, không thể trên cửa/sông/hố. Không mọc cây trên goal phải.

## Trang dịch sách sau level

Khi cả hai phù thủy chạm sách, game chuyển vào một trang sách mở: glyph cổ hiện dần ở trang trái và nội dung dịch được gõ dần ở trang phải. Người chơi phải bấm **Turn the page** mới sang level tiếp theo. Artwork sách được vẽ bằng `scripts/translation_book.gd`, do đó không cần asset ngoài và có thể thay node này bằng tranh PNG tự vẽ sau này.

Mỗi JSON level có thể thêm nội dung riêng (không bắt buộc):

```json
"translation": {
  "title": "The future can be held",
  "body": "A living tree may become a boundary, a bridge, or the hand that keeps an old mechanism awake."
}
```

Nếu không có trường `translation`, game dùng các đoạn narrative/hướng dẫn mặc định theo thứ tự level.

## Cấu trúc để mở rộng

```text
project.godot          Cấu hình; mở file này để import project
scenes/main.tscn       Scene chính; chọn resource art tại đây
scripts/main.gd       Điều khiển, giao diện, import JSON, undo/reset
scripts/puzzle_engine.gd  Logic độc lập giao diện
scripts/level_loader.gd   Đọc và kiểm tra JSON
scripts/board_view.gd     Vẽ hai phòng và asset
scripts/game_art.gd       Các slot Texture2D hiển thị trong Inspector
art/game_art.tres      Bộ ảnh đang dùng
assets/               Hình ảnh tự thay thế
levels/               Level đóng gói theo game
tests/                Kiểm thử với dữ liệu tham chiếu bản web
export_presets.cfg    Cấu hình xuất Windows; bao gồm JSON level
```

## Kiểm thử và export

Đã qua 10.025 trường hợp đối chiếu engine web, kiểm tra dữ liệu lỗi/JSON cũ, UI thắng/undo/reset và khởi động game bằng Godot 4.7.2 ở chế độ headless. Chưa có lượt kiểm tra hình ảnh thủ công trong cửa sổ game.

Chạy kiểm thử nếu có Godot trong PATH:

```text
godot --headless --editor --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

Để export: Godot → Project → Export → Windows Desktop. Cài export templates đúng phiên bản Godot nếu được yêu cầu; chọn nơi xuất EXE. Preset có `levels/*.json` trong bộ lọc để các màn được đóng gói. Import JSON bằng file picker hướng tới bản desktop. Việc build bản web từ Godot và chọn file trong trình duyệt cần luồng riêng, chưa nằm trong project này.

Asset mẫu được tạo riêng cho project; bạn có thể sửa/thay chúng tự do.
