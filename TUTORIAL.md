# Tutorial & narrative notes

Project root for active Godot work: `C:\Users\Admin\Documents\lost-in-translation-godot`

A mirrored copy may also exist under `D:\Eramus Game\Lost in translation\godot`. Prefer this Documents folder when iterating UI / tutorial.

## Folder map

| Path | Role |
| --- | --- |
| `project.godot` | Godot 4.7 project; press **F5** here |
| `scenes/main.tscn` | Play scene |
| `scripts/main.gd` | HUD, input, win/loss flow, translation screen, music/SFX, debug level select |
| `scripts/dialogue_view.gd` | Story dialogue overlay (portraits + textbox) |
| `story/dialogue.json` | All story text, scene triggers and per-level music |
| `scripts/puzzle_engine.gd` | Deterministic rules (parity with web `engine.js`) |
| `scripts/board_view.gd` | Board draw + red tile flash feedback |
| `scripts/translation_book.gd` | Code-drawn book; left page glyphs **or** tutorial illustration |
| `scripts/tutorial_art.gd` | Code-drawn tutorial / loss illustrations |
| `scripts/lost_clock.gd` | Legacy clock glyph (kept; loss popup now uses tutorial art) |
| `levels/*.json` | Shipped levels; optional `translation` block |
| `art/game_art.tres` | Texture slots for tiles / witches / objects |
| `tests/` | Headless parity checks vs web fixtures |

## Loader note (important)

`scripts/level_loader.gd` rebuilds each level dict on import. It must copy the optional `translation` object (`title`, `body`, `illustration`). If that copy is missing, the game falls back to generic book text and tutorial pages will look “unchanged”.

## How post-level books work

After both witches stand on their books:

1. Book-blur transition runs.
2. Translation screen opens (`THE TRANSLATION`).
3. **Left page:** starts as ancient glyphs; each glyph morphs in place into English (title + body), reading order top→bottom / left→right, with sparkle particles at the translation frontier.
4. **Right page:** tutorial illustration (`translation.illustration`) fades in **only after** the English page is fully translated.
5. Continue with **Space**, **→**, or the button.

Level JSON shape:

```json
"translation": {
  "title": "...",
  "body": "...",
  "illustration": "river"
}
```

`illustration` values currently supported: `"rift"` (alias `"river"`), `"cube"` (alias `"seed"`), or `""` / omitted for glyphs only.

> Rift update: level 1's page is now **Cracks between worlds** (`rift`), level 2's is **Cubes across dimensions** (`cube`). The notes below describe the original river/seed wording.

Book reveal pacing is **10% slower** than the original tween timings in `main.gd` → `_show_translation()`.

## Tutorial content by level

Maps themselves are unchanged; the book after a win teaches the **next** idea.

### Level 1 (`levels/01-level.json`)

- **Teaches for later maps:** river water kills witches (drown).
- **Illustration:** `river` — villagers with spears on the bank; witch struggling in the water (code-drawn + existing witch texture).
- **Title:** The river takes witches
- **Body (EN):** Since ancient times, people have hated witches for powers they could not control. When they caught a witch, they threw her into the river. / Step into a river, and your witch will drown.

### Level 2 (`levels/02-level.json`)

- **Teaches:** seed in the past → tree in the present (time-linked planting).
- **Illustration:** `seed` — PAST seed / PRESENT tree split panel.
- **Title:** Seeds across time
- **Body (EN):** People had reason to fear them: a powerful witch could travel through time, reshaping both past and present. / Plant a seed in the past, and a tree grows in the present.

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
