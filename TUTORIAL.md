# Tutorial & narrative notes

Project root for active Godot work: `C:\Users\Admin\Documents\lost-in-translation-godot`

A mirrored copy may also exist under `D:\Eramus Game\Lost in translation\godot`. Prefer this Documents folder when iterating UI / tutorial.

## Active project path (GitHub)

`D:\Eramus Game\Lost In Translation Project Res\LostInTranslation`

## Folder map

| Path | Role |
| --- | --- |
| `project.godot` | Godot 4.7 project; press **F5** here |
| `scenes/main.tscn` | Play scene |
| `scenes/level_editor.tscn` | In-engine level editor |
| `scripts/main.gd` | HUD icons, seed frame, recall FX, win/loss, translation flow |
| `scripts/puzzle_engine.gd` | Deterministic rules (parity with web `engine.js`) |
| `scripts/board_view.gd` | Board draw, idle bob, red tile flash |
| `scripts/star_field.gd` | Soft animated star background |
| `scripts/translation_book.gd` | Book UI; left glyphs→English; right illustration |
| `scripts/tutorial_art.gd` | Code-drawn tutorial / loss illustrations |
| `scripts/lost_clock.gd` | Legacy clock glyph (kept; loss popup now uses tutorial art) |
| `assets/glyphs/hieroglyph_ref.png` | Stone hieroglyph sheet for left-page glyphs |
| `levels/*.json` | Shipped levels; optional `translation` block |
| `art/game_art.tres` | Texture slots for tiles / witches / objects |
| `tests/` | Headless parity checks vs web fixtures |

## Ingame presentation notes

- Witches idle-bob gently while standing still.
- Goal books idle-bob with a soft golden halo + spark particles.
- River tiles show scrolling water lines; ice tiles get diagonal mirror glints.
- Replay / Pause are icon-only buttons; seed count sits in a gold-framed HUD.
- Out of seeds: **no toast** — the seed frame + `0` flash red twice.
- Recalling a seed: seed flies from the plant cell to the HUD, then the frame pops with spark particles.
- Translation glyphs use `hieroglyph_ref.png` with sandstone keyed out at runtime so only carved ink sits on the parchment.

## Loader note (important)

`scripts/level_loader.gd` rebuilds each level dict on import. It must copy the optional `translation` object (`title`, `body`, `illustration`). If that copy is missing, the game falls back to generic book text and tutorial pages will look “unchanged”.

## How post-level books work

After both witches stand on their books:

1. Book-blur transition runs.
2. Translation screen opens (`THE TRANSLATION`).
3. **Left page:** starts as ancient glyphs; each glyph morphs in place into English (title + body), reading order top→bottom / left→right, with sparkle particles at the translation frontier.
4. **Right page:** tutorial illustration (`translation.illustration`) fades in **only after** the English page is fully translated.
5. Continue with **Space**, **→**, or the **Next page** button.

Level JSON shape:

```json
"translation": {
  "title": "...",
  "body": "...",
  "illustration": "river"
}
```

`illustration` values currently supported: `"river"`, `"seed"`, or `""` / omitted for glyphs only.

Book reveal pacing is **10% slower** than the original tween timings in `main.gd` → `_show_translation()`.

## Tutorial content by level

Maps themselves are unchanged; the book after a win teaches the **next** idea.

### Level 1 (`levels/01-level.json`)

- **seedLimit:** `0` — planting locked; seed HUD hidden.
- **Teaches for later maps:** river water kills witches (drown).
- **Illustration:** `river`
- **Title:** The river takes witches

### Level 2 (`levels/02-level.json`)

- **seedLimit:** `0` — planting still locked; seed HUD hidden.
- **Teaches next unlock:** press **SPACE** to plant (main planting tutorial card).
- **Illustration:** `plant_space` — clear SPACE key + past seed → present tree.
- **Title:** Seeds across time

### Level 3 (`levels/03-level.json`)

- **seedLimit:** `1` — planting unlocked; seed HUD visible.
- **Illustration:** `seed`

### Later levels

Add a `translation` block when a new mechanic/obstacle needs a post-win lesson. Document each new entry in this file.

## Feedback rules (ingame)

### Toasts (keep)

- `Cannot plant while both witches share the same tile.`
- `Out of seeds. Pick one up to plant.`

### Red border flash ×2 (right map tile)

Door, void/hole, no-ground (clamped edge), future book, lily-with-witch.

### Removed toasts

Path blocked, death lines, Undone, Translation complete, level-ready.

### Loss popup

- River death → art `drowned` + **"Your witch drowned"**
- Void/hole death → art `void` + **"Your witch fell into the void"**
- Hint: **Restart with R** (Undo **Z** still works)

## How to verify

1. Open this folder in Godot 4.7 → **F5**.
2. Clear level 1 → confirm river illustration + drown copy.
3. Clear level 2 → confirm seed illustration + planting copy.
4. Walk into river / hole → confirm matching loss title + art.
5. Plant-fail cases → toast or red flash as above.

## Sync note

When shipping tutorial edits back to the Erasmus workspace copy, sync at least:

- `scripts/main.gd`
- `scripts/translation_book.gd`
- `scripts/tutorial_art.gd`
- `scripts/board_view.gd`
- `levels/01-level.json`
- `levels/02-level.json`
- `TUTORIAL.md`
