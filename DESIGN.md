# Design system: menus and UI

Built for a 480x270 pixel viewport, integer-scaled. Source of truth is code: `scripts/ui/ui_theme.gd` (palette, font, label styles) and `scripts/ui/title_screen.gd` (components). Update this file when those change.

## Principles
- The UI is part of the world: it sits on the game's art and never on boxes or cards.
- Weight over decoration: slow, deliberate, readable. One signature motion per screen.
- Keyboard-first, mouse-friendly: arrows/WASD, Enter/Space, Esc; or hover to select, click to activate, click a pip to set volume, wheel over a slider to adjust, right click to go back.
- Pixel-clean: nearest filtering, pixel-snapped, integer positions and sizes only.

## Palette
| Role | Hex | Use |
|---|---|---|
| Cream | `#f2e2bc` | Selected text, titles, filled pips |
| Cream dim | `#b9a888` | Unselected text, hints |
| Rust | `#a8512d` | Dividers, platform tops, wall rims |
| Rust dark | `#5a2a22` | Empty pips |
| Ink | `#120d14` | Text outline, shadows, UI backing |
| Prism | hue 0.52 (cycling) | The lake glimmer and the selector tint; the only saturated colour on screen |

The shaft backdrop (`scripts/ui/shaft_art.gd`) is the final look for all menu screens. Sky range (zone 1, top to bottom): `#c4875a #a8583f #7a3a3c #4a2a40 #2e2238 #1b1d2e #11202a #0a1519`. Each later zone gets its own range; keep Prism as the single saturated accent.

## Type
- Font: **Rodondo** (Olly Wood, art-deco sans, single weight), `assets/fonts/Rodondo.otf`, from DaFont (listed public domain / GPL / OFL; see `assets/fonts/README.txt`). Pixelify Sans stays in the folder as a pixel-grid alternative; swap `UITheme.FONT_FILE` to try it.
- No antialiasing, no hinting, no subpixel positioning; word space widened to 3px.
- Title: 40px, glyph spacing 3, 2px outline. Sub-title: 12px, spacing 4, 1px outline. Screen headings: 20px, spacing 3.
- Menu and rows: 16px. Selected = Cream, unselected = Cream dim. One weight only, so state is shown by colour, the drop and the underline.
- Hints: 12px, spacing 1. Body outline stays at 1px so counters of small letters stay open.
- Rodondo's glyphs sit high in the label box: the drop is placed at row y + 2 and the underline at row y + 12.

## Components
- **Hover / selection underline:** a 1px rust line (with ink shadow) draws itself under the highlighted row's name in 0.18s. Hover and keyboard selection share it.
- **Selector (drop):** 5x7 pixel drop left of the selected row, tinted by Prism hue. Falls down with a bounce settle (0.32s), rises with a quick cubic ease (0.16s).
- **Divider:** 1px rust line with a 5px diamond at its centre, ink shadow row beneath.
- **Pip bar:** ten discrete 4x7 pips, 7px pitch, Cream when active, Cream dim when not, Rust dark when empty. Used for volume.
- **Toggle:** the words ON / OFF in the value column.
- **Rows:** main menu is centred; settings and controls use two columns (names at x=146, values at x=240 or 292) so values never reach the wall platforms.

## Controls screen (rebinding)
Select a row (Enter or click), the value blinks "PRESS A KEY", press the new key. Esc or any click cancels. Arrow keys and Esc are reserved. Binding a key another action already uses swaps the two. Arrow keys always also move left/right. Saved to `user://bindings.cfg` (`scripts/ui/key_bindings.gd`); "Reset to defaults" restores A / D / Space / Shift / E / Esc.

## Profile screen (Start Game)
Hollow Knight-style slot list, four profiles (`scripts/ui/profile_row.gd`, saves in `scripts/ui/save_slots.gd`, `user://save_N.cfg`).
- Background dims to 72% and the platform layer hides so the rows read cleanly. Heading "SELECT PROFILE" with an ornate divider (extra diamonds).
- Each row: ornate top line with a corner tick and diamonds (cream when selected, rust otherwise), numeral, portrait, health pips (cream filled, rust-dark empty), currency, location, completion % and play time. Empty slots read NEW GAME.
- The portrait is a region emblem drawn in `ProfileRow._draw_portrait`, chosen by the profile's location: The Overgrowth = moss-green vines, Rusted Depths = rust gear, The Prismatic Lake = prism diamond. Unknown regions fall back to a placeholder creature head. Add a new `match` arm per new region. Muted moss green is allowed only inside the Overgrowth emblem.
- Enter or click on an empty slot creates a profile; on a filled slot it will load it (game not built yet). Delete / Backspace (or clicking CLEAR SAVE) arms an erase, the same action again within 3s confirms.

## In-game HUD (bottom-left)
`scripts/ui/hud.gd`, fed by a `VitalsState` (`scripts/ui/vitals_state.gd`).
- Row 1: health crystals (Prism blue on the lit half, violet on the dark half, white sparkle). 9x11 px each, 11 px pitch, up to 11. Empty crystals are rust-dark outlines. A hit shatters the crystal into six pieces that fly apart and fall (0.42s); healing regrows it from the bottom up with a white flash (0.5s). At 1 or 2 crystals the survivors pulse slowly (steady when Reduce Flashing is on).
- Row 2: food pips (round, cream filled, dark ring empty). At zero food the empty rings pulse rust.
- Row 3: currency diamond and count.
- Drawn by `scripts/ui/glyphs.gd`, shared with the profile rows and the inventory.

## Inventory (I)
`scripts/ui/inventory_screen.gd`. Hollow Knight layout: dark backdrop, curling corner flourishes, ornate heading.
- Left: a **shard circle** (two halves, left light blue and right violet like a crystal's facets; one half fills per shard collected toward the next crystal, both stay filled at the 11-crystal cap), crystal count and shard progress, crystal row, food pips, currency, the four ability badges (lit = unlocked; dim = not yet), current region. Middle: 4x4 item grid, **empty on purpose** until the items are defined. Right: description of the selected ability, completion %.
- Keyboard: arrows/WASD move the cursor between ability badges (nearest slot in that direction), I or Esc closes. Mouse: hover selects, right click closes.
- Locked abilities read "???". Item icons and item descriptions were removed; add them when the items are defined.
- Preview: `scenes/ui/ui_preview.tscn` shows HUD and inventory with demo keys (H hurt, K hurt 2, J heal, G shard, T food, M scrap, R next ability). Choosing a profile opens it.

## Motion
- Menu fade-in 0.18s on screen change. Background layers sway by whole pixels only (1/2/3px amplitude per layer). Dust motes drift upward.
- The lake glimmer brightens as the selection moves down the main menu. With "Reduce flashing" on, its colour drift and shimmer slow down.

## Do not
- No cards, panels or boxes behind menu text. No smooth gradients or anti-aliased shapes. No bold at 16px. No new saturated colours besides Prism.
- No unicode glyphs as icons (the font lacks them). Draw icons with pixels.
