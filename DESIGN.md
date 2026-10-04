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

## Pause menu (Esc in the game)
`scripts/ui/pause_menu.gd`, opened by the game scene. Hollow Knight layout: dimmed game behind, a crystal emblem on an ornate curled line above the items, a smaller line below, and the **same selector as the title menu**: the raindrop falls to the highlighted item and the rust line draws itself beneath it (same bounce, same timing), so every menu feels like one system.
- Items: CONTINUE, OPTIONS, QUIT TO MENU. Options page: music and effects pips, screen shake, reduce flashing, fullscreen, back (same settings as the title screen, saved the same way).
- Opening pauses the scene tree (the menu keeps running); closing or leaving resumes it. Esc or right click goes back one level, then resumes. Keyboard and mouse both work.
- Esc priority: inventory closes first, then the pause menu opens. While paused, I does nothing.
- Quit To Menu marks the key handled before changing scene (a scene change leaves `get_viewport()` null).

## App icon
`icon.png` (1024x1024): a pixel-art prismatic crystal (cyan to violet facets, white ridges and sparkles) with a fan of spectral rays leaving its right side, on the dusk-to-depth gradient in a rounded square. Drawn by `dev/make_icon.py` (plain Python, no libraries; run it from the project folder to regenerate). Used as the project icon, the web favicon and the Mac app icon (`application/icon` in the macOS export preset). Replace `icon.png` with hand-made art any time; nothing else needs to change.

## Motion
- Menu fade-in 0.18s on screen change. Background layers sway by whole pixels only (1/2/3px amplitude per layer). Dust motes drift upward.
- The lake glimmer brightens as the selection moves down the main menu. With "Reduce flashing" on, its colour drift and shimmer slow down.

## Do not
- No cards, panels or boxes behind menu text. No smooth gradients or anti-aliased shapes. No bold at 16px. No new saturated colours besides Prism.
- No unicode glyphs as icons (the font lacks them). Draw icons with pixels.

## World map

Drawn from the real world, not a mock-up. `dev/world_bake.py` bakes `assets/world/map.png` (1 px = 2x2 tiles; rooms in the region colour, walls dark, platforms pale) and `data/world_runtime.json`. Only rooms the hero has entered are drawn (explored rooms are saved with the profile).

**Quick map** (Tab, rebindable): a corner panel (top right) centred on the hero at 2x zoom, the region name below, blinking hero marker and rest-point diamonds; hides after 3 seconds or on Tab. **Full map** (M, rebindable): full-screen overlay of the whole explored descent at 2x, scrolled with Up/Down or the wheel (opens centred on the hero), a dotted line and the region name where each region begins, current region lit. M, Tab, Esc or right click closes it. Region names other than THE OVERGROWTH are placeholders.

## The world in the game

Fixed, authored data (never generated at runtime): `data/world/*.json` are the source files (one per room and shaft, editable), `dev/world_bake.py` turns them into the art and `data/world_runtime.json` the game loads. 5 regions, 50 rooms, 49 shafts, stitched into one tall world 3120 x 28032 px. `scripts/game/world.gd` streams only the pieces near the hero (art sprite + merged-rectangle collision). Camera is Rain World style (`game_camera.gd`): rooms are fixed 480x272 screens and the view cuts between them with a quick ease; shafts follow the hero vertically. The hero (`player.gd`) is drawn from `assets/hero/hero_sheet.png`; its numbers match `dev/world_physics.py`, which proves every room can be completed (and climbed back) with the abilities available at that point.

## Ropes and vines

Every room has 2 or 3 climbable ropes (vines in the Overgrowth), hung from a ceiling or platform. Up (W / Up arrow) grabs and climbs; Down (the pound key, S / Down arrow) climbs down; Jump leaps off; the floor or the end of the rope lets go. They are shortcuts and optional routes: every room is completable without them (the simulator in `dev/world_physics.py` does not model climbing). Platforms were thinned by about 45% in a one-time pass (`dev/world_thin.py`; the earlier version is kept in `data/world_before_thinning/`).

## Region emblems (profile screen)

Each profile row shows a 26x26 emblem of the region the profile is in (the five region names are final): vines for THE OVERGROWTH (moss green), meshing gears for THE RUSTWORKS (rust orange), a dripping pipe over water for THE DROWNED WORKS (teal), a spine with rib arches for THE BONE STACKS (bone), a glowing cinder over ash dunes for THE ASH DEEP (violet and ember). Unknown locations fall back to the placeholder creature head. Preview all of them with `dev/capture_emblems.gd`.

## The hero

A small white creature with big dark eyes, long soft ears, a long tail and a rust-red scarf (the scarf keeps it readable on pale backgrounds such as THE BONE STACKS, and makes it our own). Pixel art generated by `dev/make_hero.py` from posed shapes: 24x24 frames, outlined, lit from the upper left. Animations: idle (8 frames, breathing, tail sway, a blink), run (8), jump (2), apex (1), fall (2), land (2), wall slide (2), climb (4, paused when not moving), dash (2). The drawing faces right and flips; the feet sit on the 10x14 collision box's bottom centre. Preview all frames: `dev/hero_preview.png`; in-game strip: `dev/capture_hero.gd`.

## Region gifts (abilities)

The first time the hero stands in a region's first room they are given that region's ability: THE RUSTWORKS GROUND POUND, THE DROWNED WORKS DOUBLE JUMP, THE BONE STACKS INVINCIBLE DASH, THE ASH DEEP FAST HEAL. The game waits for a real landing, then: control stops, the HUD hides, a soft prismatic beam with rising motes and a spreading ring (no ring with Reduce Flashing) surrounds the hero, who floats up to 30 px (never into a ceiling) in the eyes-closed ascend pose; the banner fades in (badge at 2x in a turning prismatic ring, NEW ABILITY, the name, what it does, which key uses it), holds about 2.6 s (Jump or Interact speeds it up), then the hero settles back down and play resumes. The banner moves to the lower half when the hero is high on the screen. Abilities and smashed floors are saved with the profile.

- Ground pound (pound key in the air): straight down at 460 px/s; landing smashes the cracked floor under it (hidden food pocket), with a small screen shake (off with Screen Shake off).
- Double jump: one more jump in the air (230 px/s), reset on ground, wall and rope.
- Invincible dash: the hero cannot be hurt mid-dash; prismatic afterimages and a cool tint show it.
- Fast heal: holding Eat turns one food pip into one crystal in 0.3 s instead of 1 s.

Every junction between rooms can be climbed back up (notches in the holes; `dev/world_junctions.py` checks all 49 both ways).

## Area name

When the hero crosses into another region (and when a profile loads) the region's name appears in the bottom right corner: a dim "NOW ENTERING", the name in the region's colour, and a line that draws out under it. It fades in over 0.5 s, holds 3.2 s and fades out (`scripts/game/area_title.gd`). It sits opposite the HUD (bottom left) and does not block the screen.

## Shafts

The shafts between rooms have no ledges. Each has one climbable rope (vine in the Overgrowth) down the middle that runs through the floor hole above and the ceiling hole below, so the way up and down is a straight climb (the earlier ledged versions are in `data/world_before_clearing_shafts/`). The junction checker (`dev/world_junctions.py`) models rope climbing and proves all 49 junctions work in both directions.
