# Design system: menus and UI

Built for a 480x270 pixel viewport, integer-scaled. Source of truth is code: `scripts/ui/ui_theme.gd` (palette, font, label styles) and `scripts/ui/title_screen.gd` (components). Update this file when those change.

## Principles
- The UI is part of the world: it sits on the game's art and never on boxes or cards.
- Weight over decoration: slow, deliberate, readable. One signature motion per screen.
- Keyboard-first, mouse-friendly: the movement keys (WASD by default, rebindable; the arrow keys do nothing until the player binds them), Enter/Space, Esc; or hover to select, click to activate, click a pip to set volume, wheel over a slider to adjust, right click to go back.
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

**Instructions follow the keys.** Every line that tells the player what to press is written with `{action}` tokens (`StoryData.format`) or reads `KeyBindings.key_name`, and is filled when it is shown: the scrolls (every one that teaches a move names its key: movement, jump, wall jump, climb, stick, dash, rest, ground pound, double jump, heal), the inventory's ability, stick and gate-key descriptions, the upgrade banner, the interact prompts, the scroll's own close hint and the menu hint lines. `dev/test_keys.gd` remaps every key and checks all of it; `dev/capture_keys.gd` shows the inventory and a scroll with remapped keys.
Select a row (Enter or click), the value blinks "PRESS A KEY", press the new key. Esc or any click cancels. Esc is the only reserved key: the arrow keys can be bound like any other. Defaults: A / D move, W climbs, S pounds (and climbs down), Space jumps, the left arrow swings the bamboo stick, the right arrow dashes, F heals, E interacts, I inventory, Tab quick map, M full map, Esc pause; the up and down arrows do nothing until bound. Binding a key another action already uses swaps the two. Menus, the map and the inventory follow the movement keys (left, right, up, and the pound key for down). Saved to `user://bindings.cfg` (`scripts/ui/key_bindings.gd`); "Reset to defaults" restores those.

## Profile screen (Start Game)
Four profiles (`scripts/ui/profile_row.gd`, saves in `scripts/ui/save_slots.gd`, `user://save_N.cfg`). The shaft backdrop stays as it is and dims to 72% with the platform layer hidden; heading "SELECT PROFILE" with an ornate divider. The list is stable (rows never move or resize; Operate mode), 360 px wide, 38 px rows on a 44 px pitch starting at y 56.
- **Each row is two lines and a rail.** Line 1: the region the profile is in (16 px) and its completion % at the far right. Line 2: health pips and shards on the left, play time at the far right. Along the bottom runs the **descent rail**: five segments, one per region; the regions already passed are lit, the region the profile is in is the taller notch, the regions still below are dark. An empty slot reads NEW GAME over "THE DESCENT HAS NOT BEGUN" and a rail that is all dark, with a blank dotted frame where the emblem goes.
- **Selection** is carried by the cursor drop (left margin) and by the row lighting up: a cream top line and a matching tick at the bottom right, the emblem inside cream corner brackets, bright type (the unselected rows sit back in dim type), the numeral lit, and a warm glow that fades in from the left (0.14 s) and has no edge of its own. CLEAR SAVE shows on the selected filled row, left aligned at x 224 of the row (clear of the region name and the %); the second press shows CONFIRM ERASE.
- **The hint line says what Enter does for the slot under the cursor**: ENTER CONTINUE and DELETE CLEAR SAVE on a filled slot, ENTER NEW GAME on an empty one.
- The portrait is a region emblem drawn in `ProfileRow._draw_portrait`, chosen by the profile's location (see Region emblems). Muted region hues are allowed only inside the emblem; the rest of the row is Cream, Cream dim, Rust and Rust dark.
- Enter or click on an empty slot creates a profile; on a filled slot it loads it. Delete / Backspace (or clicking CLEAR SAVE) arms an erase, the same action again within 3 s confirms.
- Preview with `SHOT_SCREEN=3 SHOT_INDEX=<row> SHOT_FAKE=2 dev/capture.gd` (the fake profiles fill only empty slots and include the extremes: the longest region name, 11 pips, 100%, three-digit hours).

## In-game HUD (bottom-left)
`scripts/ui/hud.gd`, fed by a `VitalsState` (`scripts/ui/vitals_state.gd`).
- Row 1: health crystals (Prism blue on the lit half, violet on the dark half, white sparkle). 9x11 px each, 11 px pitch, up to 11. Empty crystals are rust-dark outlines. A hit shatters the crystal into six pieces that fly apart and fall (0.42s); healing regrows it from the bottom up with a white flash (0.5s). At 1 or 2 crystals the survivors pulse slowly (steady when Reduce Flashing is on).
- Row 2: food pips (round, cream filled, dark ring empty). At zero food the empty rings pulse rust.
- Row 3: currency diamond and count.
- Drawn by `scripts/ui/glyphs.gd`, shared with the profile rows and the inventory.

## Inventory (I)
`scripts/ui/inventory_screen.gd`. Hollow Knight layout: dark backdrop, curling corner flourishes, ornate heading.
- Left: a **shard circle** (two halves, left light blue and right violet like a crystal's facets; one half fills per shard collected toward the next crystal, both stay filled at the 11-crystal cap), crystal count and shard progress, crystal row, food pips, currency, the four ability badges (lit = unlocked; dim = not yet). Section rules (rust, 1 px) separate health, energy and abilities on the left, and sit under the description title and above the completion line on the right, so both columns share one rhythm. The item grid is centred on the column rules; the badges are spread across the width of the left rule. Middle: 4x4 item grid, **empty on purpose** until the items are defined. Right: description of the selected ability, completion %.
- Keyboard: the movement keys move the cursor between ability badges (nearest slot in that direction), I or Esc closes. Mouse: hover selects, right click closes.
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

## Story: wings, scrolls, keys, guardians
The world grew by 15 **wing rooms** built onto the sides of main rooms (a doorway cut through the host's wall, floor level with the host's floor): in every region a **ruin hall** (a scroll, a resting lantern; the Ash Deep has a second quiet shrine), a **key chamber** (a climb to the region's key; none in the Ash Deep) and a **guardian temple** (one screen wide, so the whole fight is in view). Authored by `dev/make_wings.py` from `data/world_before_wings/`, drawn with `dev/shrine_art.py` (pagodas, ruins and door arches take a palette per region); baked after the main pieces (ids 101 to 115, `wing: true`) so earlier ids did not move.

**Lantern shrines** (`dev/make_shrines.py`, 15 more wing rooms, 3 in every region, ids 116 to 130 so no earlier piece moved): quiet rooms with no enemies, no scroll and one resting lantern, after a photograph of a red torii at the foot of a long stone stair between cedars. Built onto the sides of main rooms like the other wings, but on top of the world as it is (the script does not start from `data/world_before_wings/`; hosts are backed up in `data/world_before_shrines/`; never re-run `make_wings.py`). The three of a region are three layouts: **THE LANTERN GATE** (a great torii with the stair rising behind it, a second small gate at its top, stone lanterns), **THE QUIET HALL** (a torii, a small hall with a lit doorway, stone lanterns) and **THE STAIR OF LAMPS** (a torii and a stair lit by lamps climbing off to the side). Floors stay flat (the stairs are painted into the background). Drawn by `dev/shrine_art.py` in layers, back to front: a dusk backdrop dithered from dark to misty, slanting shafts of light, great trunks in three depths (haze thickest on the far ones), stairs that narrow and lower as they climb into the mist with cheek walls and post lamps, the canopy of hanging needles, the red gate (tapering pillars on white stone feet with flaking paint and moss, tie beam, strut, dark top beam lifting at its ends over a red layer), stone lanterns with lit windows and a halo, the hall, a halo of light round the resting lantern, fireflies and ground mist. Each region paints them in its own colours (`SPAL`): vermilion gates in cedar green (Overgrowth), orange in rust-brown (Rustworks), jade in drowned teal, dried-blood red on pale bone trees (Bone Stacks), blood lacquer in charred black (Ash Deep). Preview: `dev/capture_brain.gd` with `SHOT_SCENE=rest SHOT_PIECE=<116..130>`.
- **Scrolls** (`Pedestal`, 23 of them, texts in `data/scrolls.json`, tokens like `{jump}` filled with the player's own bindings each time a page is shown, so they follow any remapping, the arrow keys included): a pedestal beside the path, E opens a **parchment** (`ScrollReader`, `assets/ui/scroll_panel.png` from `dev/make_scroll.py`): 384 x 216, 80% of the screen, unrolling from the middle, title, rust rule, words, footer hint; left and right turn pages.
- **Keys** (`KeyAltar`): walk into the key; one per region 1 to 4, shown in the inventory grid with their gate. **Gates** (`GateDoor`) seal the shaft under the last room of each region (E above it with the key); the **seal** above the Prismatic Lake opens when all five guardians have fallen. Opened gates stay open.
- **Guardians** (`Guardian`): asleep until the hero is close; a crystal wave along the floor (jump it) or shards from the ceiling (a light shows where they land), then it tires and its heart is bare: land on it from above (a ground pound lands twice). 3 to 7 hits by region. Stomping a shut heart only bounces. Leaving the temple or dying resets the fight. Each defeat gives a crystal shard.
- **Bamboo stick** (`BambooStick`, the left arrow by default, rebindable as BAMBOO STICK): slung across the hero's back, drawn in pixels from the hand. A strike is a **slash, like Hollow Knight's nail**: it lands on the first frame (no wind-up), the cane snaps through in 0.06 s and leaves a crescent in the air (thickest in its middle, white along its outer edge, fading from its tail) that is gone by 0.2 s; the next slash can follow 0.3 s after the last. Sideways slashes alternate (over the top and down, then from below and up, when they follow each other within 0.6 s); holding up slashes over the head. Its reach is 30 px in front (an up-slash: 28 x 30 over the head). A sideways slash that hits something pushes the hero back a little (recoil). It does no damage: a guardian it strikes is stunned for 1.5 s (wobbles, crossed eyes, stars, a ring counting down, heart bare so it can be stomped), then cannot be stunned again for 2 s. A clean stun freezes the world for 0.07 s and shakes the camera; a glancing blow (asleep, already open, still immune) only sparks. Anything in the group `stunnable` with `stick_hit(box, from_x)` can be stunned. Shown in the inventory grid. Close-up strip: `dev/capture_slash.gd`.
- **Being hurt**: one crystal, knock back, 1.3 s safe; the invincible dash ignores hits.
- **Death** (`DeathScreen`, `scripts/ui/death_screen.gd`): when the last crystal breaks the screen sinks into ink (82%) and the last crystal hangs in the middle, the HUD crystal grown large (80 px: blue on its lit side, violet on its dark side, a white glint, an ink outline). Cracks run through it from the top right and it shivers; at 1.0 s it bursts: a ring, a white flash (none with Reduce Flashing), a camera shake, shards that tumble away under their own weight and prism dust that drifts down. Where it hung: **NOT HERE** (40 px, the title style: the hero wants an end, but not this one), then THE LAKE IS STILL BELOW (12 px, spaced), then at the foot YOU WAKE BY THE LAST LANTERN. At 3.1 s the ink closes, the hero is moved to the last lantern with every crystal back, and at 3.9 s the ink lifts (control at 4.6 s). As the ink lifts the bottom right corner reads NOW ENTERING / LANTERN ROOM (in the region's colour); it shows the same way each time the hero walks into one of the lantern shrines. Once the words are up, jump, the stick or interact hurries it on. One authored moment, exponential ease-outs. Sheet of six moments: `dev/capture_death.gd`.
- UI: `Toast` (top centre), `BossBar` (name and a crystal per hit left), inventory shows keys and `GUARDIANS n / 5`. The full map scrolls sideways when the world is wider than its view.
- Check: `dev/world_verify.py` also walks each wing from its doorway to its goal and back; `dev/test_story.gd` plays the whole chain.

## Resting places
Leaving the world (Esc, quit to menu) saves the profile, and coming back puts the hero at the last lantern they rested at, not where they stood: healed, with the corner reading NOW ENTERING / LANTERN ROOM (a profile that has never rested resumes at the start). Checked by `dev/test_resume.gd`. The old debug keys (H hurt, K, G shard, T energy, C currency, R unlock the next ability) are gone from the game; they live only in the separate `ui_preview` scene.
A lantern heals the hero fully (interact), sets the place they wake after a fall, and makes every creature lose them for 6 seconds. There is one in each region's ruin hall and three more in the lantern shrines (the shrine wings are lanterns and nothing else), one in the Prismatic Lake's temple and, from `dev/make_rests.py`, three more in every region's main rooms (the third, the sixth, the eighth and the last room), so no region has more than two or three rooms between lanterns. Creatures keep 7 tiles clear of them.

## Creatures
Twenty creatures, four per region, weakest first (`CreatureTypes.ORDER`): Overgrowth sprout lizard, moss lizard, bloom lizard, bark lizard;
Rustworks spark lizard, carrion kite, furnace hound, slag lizard; Drowned Works drip lizard, lure angler, mire lizard, tide leviathan;
Bone Stacks pale lizard, crypt lizard, bone vulture, marrow worm; Ash Deep ash wyrm, cinder lizard, ember vulture, soot wraith.
No crawlers or centipedes (only the marrow worm and the ash wyrm are long-bodied); eleven of the twenty are lizards, Rain World's way.
No cute ones: dark, gaunt, armoured, toothed; the reference for the level of detail was a dark serpent with blue fronds and an old
machine for a head (the marrow worm), used for style only.
- **The lizards** (`lizard.gd`, numbers and tricks in `CreatureTypes`), each with its own head feature and trick:
  - **Sprout** (green, pink leaf frill, small): two hits, a stomp hurts it; bites and backs off.
  - **Moss** (moss green): the plain one, heavy and slow.
  - **Bloom** (pink, crest of petals): climbs any wall, however tall (its route map allows any climb).
  - **Bark** (brown, branching horns): waits in **ambush**, faded nearly invisible and still, noticing the hero only when it sees them (not
    when they come in); then shows itself and shoots a **sticky tongue** (110 px; a head-shake tell first) that yanks the hero to it, and bites.
  - **Spark** (yellow, glowing feelers): when it notices the hero its **cry** (rings of light) wakes every creature in the room at once.
  - **Slag** (orange), **mire** (blue, leaps up to the hero's ledge), **cinder** (red, leaps, lunges twice): as before.
  - **Drip** (cyan, gill fronds): climbs any wall and **drops** on the hero from a ledge above.
  - **Pale** (bone white, mask with red sockets): ambush and tongue like the bark lizard, longer (150 px) and faster; leaps.
  - **Crypt** (black, eyeless, whiskers and glowing jaw pits): **blind**. It does not notice the hero coming in or standing in view; it
    hunts by sound (three times the ears of its region: footsteps, landings, pounds, swings) and feels them at arm's length. Fast; leaps.
- **Sprite sheets** like the hero's, made by `dev/creature_art/` (`build_all.py` builds all of them into `assets/creatures/<kind>.png`
  + `.json` atlas): a small pixel-art engine shades every part from its surface against one light into a four-tone ramp, adds scales,
  ridges, plates, a rim of light along the top and an ink outline, then feathers, rods, teeth and glowing lights on top.
  Whole-body creatures (hound, kite, vultures, angler, wraith body) have animation rows: idle, a walk
  or run (played by distance travelled so the feet never slide), an attack and a stun. Long-bodied creatures (lizards,
  leviathan, worm, wyrm) have a head (shut and open) and body segments pre-drawn in 16 directions, chained along a body that
  trails, sags and keeps its spacing, so they bend smoothly and stay crisp. Lizard legs plant and step; worm fronds and wraith arms are
  drawn live.
- **The hunting brain** (`CreatureBrain`, in `Creature`): a creature does nothing special while the hero is elsewhere. The moment the hero ENTERS its room it notices: it freezes for its reaction time, turning to face them with a red "!" over its head (pixel glyph, ink outline, pops up; it stays on into the first second of the chase and comes back whenever a hunter that had lost the hero spots them again), then HUNTS for as long as they stay in the room, and the hunt ends the moment they leave. While hunting it knows where the hero is whenever it has a clear line to them (across the whole room), goes to the spot it last saw them when it cannot see them (ledges, pillars and walls block its sight) and searches around it (pacing up and down, a yellow "?" over its head), and after `memory` seconds without finding them goes back to its rounds (where its sight range can start the hunt again). It hears landings, ground pounds, stick swings and running footsteps (`hear`) and turns to the noise. From the Rustworks on, a hunter that sees the hero tells the others in the room where they are (`share`); from the Drowned Works on, lizards sometimes hop back out of reach of a swing of the stick (`dodge`: 25%, 35%, 45%). A lantern is a breather: resting makes every creature lose the hero and take no notice for 6 seconds.
  - **By region** (reaction / sight when patrolling / memory / hearing / speed / attack rate / extras): Overgrowth 1.1 s / 150 / 10 s / 0.5 / x1.00 / x1.00; Rustworks 0.85 / 190 / 15 / 0.8 / 1.08 / 1.15; Drowned Works 0.60 / 230 / 22 / 1.1 / 1.16 / 1.30; Bone Stacks 0.40 / 280 / 35 / 1.4 / 1.25 / 1.50 and **packs flank** (hunters of one kind spread out to come at the hero from different sides); Ash Deep 0.20 / 400 / never forgets (they smell the hero) / 2.0 / 1.35 / 1.75, flanking.
  - **Routing** (`RoomNav`): a walking map of each room built from its baked rectangles (every standable tile, and which are linked by walking, climbing a wall up to 7 tiles, or dropping up to 12). Hunting walkers follow it over ledges and round pits; if the hero is somewhere they cannot walk to, they go to the nearest spot they can. It never routes through the exit holes. Fliers fly straight at the hero (flanking aside). Creatures tied to a spot (worm, wraith's range, leviathan, angler) hunt from where they are. The bloom and drip lizards route up any wall.
  - Checks: `dev/test_brain.gd`; `dev/check_stuck.gd` lets every room's walkers hunt the hero for 15 s and lists any that never got near when the map says they could.
- **Turning:** a creature turns round at most once every 0.3 s (`TURN_LOCK`), and a hunting walker stops rather than spins when the hero is just above or just past it, so the hero hopping over one does not make it flicker. `face_s` eases from one side to the other over 0.2 s; lizard heads and feet follow it, so a turn is a swing of the head and a re-plant of the feet, not a flip.
- **Climbing:** walkers climb walls up to 60 px (straight up, then over the top; sprites turn onto the wall) and walk off drops up to 56 px, so a pit or crevice never traps them; taller walls and deeper holes (the shafts) turn them round. One that gets nowhere for 2 s turns round; one that falls out of its room is put back. `dev/check_stuck.gd` lets every room's walkers roam and lists any that barely moved.
- **Rules:** touching one costs a crystal; the stick stuns any of them for 1.5 s, then 1 s immune; stomp rule "always" (small ones),
  "stunned" (stun first) or "never" (leviathan, worm, wraith: cannot be killed, only dodged and stunned). Big attacks are telegraphed:
  the tongue lizards stop and shake their heads, the hound crouches, vultures flash their eye, the kite flares its wings, dust shows where the worm will rise.
- **Placement** (`dev/make_creatures.py`): each room's enemy spots are filled by scanning the room for every place a creature truly
  fits (a stretch of flat floor long enough to patrol with headroom for its height, open air, a clear drop under the ceiling, the flooded
  main floor, a long floor to tunnel under), harder kinds further into a region, kinds the world has seen less of preferred, spaced
  apart, away from the entrance, rests and scrolls. Lizards need 7 tiles of floor to start on (they climb and drop from there). 166 in all
  (17, 29, 29, 43, 48 by region); total threat climbs region by region (52, 79, 104, 191, 231).
- Check: `dev/test_creatures.gd`; sheet of all twenty: `dev/capture_bestiary.gd`.

## Beams
Tile kind `4` is a **beam**: a very thin bar (4 px thick, collision and art agree via `BEAM_H`) that sprouts from a wall or cliff face, 3-5 tiles long, with moss threads hanging from its underside. `dev/world_beams.py` placed about 45, in the emptiest parts of each room (never in the opening room, never near the entry and exit holes, ropes or cracks). They are extras: every room passed the movement check with each beam counted as a full solid tile, and the real beam is thinner. Baked as `beams` ([x, y, width] in tiles) in `data/world_runtime.json`; `world.gd` gives them a 4 px collision strip. Backup of the rooms before: `data/world_before_beams/`.

## Ropes and vines

Every room has 2 or 3 climbable ropes (vines in the Overgrowth), hung from a ceiling or platform. Up (W) grabs and climbs; Down (the pound key, S) climbs down; Jump leaps off; the floor or the end of the rope lets go. They are shortcuts and optional routes: every room is completable without them (the simulator in `dev/world_physics.py` does not model climbing). Platforms were thinned by about 45% in a one-time pass (`dev/world_thin.py`; the earlier version is kept in `data/world_before_thinning/`). A second pass (`dev/world_even.py`) made platforms read as natural ledges rather than bricks: most two-tile slabs are now one tile thick and the rest keep a short, off-centre underside, and in rooms whose ledges all sat on one side a few low and higher ledges were added to the empty side and as many taken out of the crowded side. Every change was kept only if the room still passed the movement check (backup in `data/world_before_even/`). A third pass (`dev/world_clear.py`) cleared platforms for easier movement: each half-screen cell (30 x 34 tiles) was thinned toward at most 2 platforms, taking them out of the most crowded cells first, so heavy-sided rooms came out balanced; platforms carrying a rope, a mark or a prop stayed, and every removal was kept only if the room still passed the movement check. 939 platforms became 669 (backup in `data/world_before_clear/`). Last Descent was restored because its junction with Glass Hall would not pass without them.

## Flat floors
Every main room has a flat floor (`dev/world_flat.py`, one-time pass; backup in `data/world_before_flat/`): the floor is row `th - 8`, the same row the wing doorways and the creatures' homes use. Steps, pillars and humps were cut down to it, pits filled up to it, and metal ledges lying right on it removed. Kept as they were: the wall columns, the hole in the floor where a room lets out (and the notches round it), the shafts, the wings (already flat) and the Prismatic Lake (its cliff stair and bridge are the point of it). Lanterns, props, doorway arches and food that stood on a step moved to the new floor; ropes were lengthened or shortened to end the same height above what is under them. Every room still passes the movement check: where a step had been what a high ledge was reached from, it came back as a thin ledge at its old height (the floor under it flat). Creatures were placed again afterwards (169). The cracked floor patches and the empty pockets under them (124 tiles in 31 rooms) were filled solid in a second pass (`dev/world_fill.py`, backup in `data/world_before_fill/`), so the only hole in a room's floor is where it lets out.

## Region emblems (profile screen)

Each profile row shows a 26x26 emblem of the region the profile is in (the five region names are final): vines for THE OVERGROWTH (moss green), meshing gears for THE RUSTWORKS (rust orange), a dripping pipe over water for THE DROWNED WORKS (teal), a spine with rib arches for THE BONE STACKS (bone), a glowing cinder over ash dunes for THE ASH DEEP (violet and ember). Unknown locations fall back to the placeholder creature head. Preview all of them with `dev/capture_emblems.gd`.

## The hero

A small white creature with big dark eyes, long soft ears, a long tail and a rust-red scarf (the scarf keeps it readable on pale backgrounds such as THE BONE STACKS, and makes it our own). Pixel art generated by `dev/make_hero.py` from posed shapes: 24x24 frames, outlined, lit from the upper left. Animations: idle (8 frames, breathing, tail sway, a blink), run (8), jump (2), apex (1), fall (2), land (2), wall slide (2), climb (4, paused when not moving), dash (2). The drawing faces right and flips; the feet sit on the 10x14 collision box's bottom centre. Preview all frames: `dev/hero_preview.png`; in-game strip: `dev/capture_hero.gd`.

## Region gifts (abilities)

The first time the hero stands in a region's first room they are given that region's ability: THE RUSTWORKS GROUND POUND, THE DROWNED WORKS DOUBLE JUMP, THE BONE STACKS INVINCIBLE DASH, THE ASH DEEP FAST HEAL. The game waits for a real landing, then: control stops, the HUD hides, a soft prismatic beam with rising motes and a spreading ring (no ring with Reduce Flashing) surrounds the hero, who floats up to 30 px (never into a ceiling) in the eyes-closed ascend pose; the banner fades in (badge at 2x in a turning prismatic ring, NEW ABILITY, the name, what it does, which key uses it), holds about 2.6 s (Jump or Interact speeds it up), then the hero settles back down and play resumes. The banner moves to the lower half when the hero is high on the screen. Abilities and smashed floors are saved with the profile.

- Ground pound (pound key in the air): straight down at 460 px/s; landing sends out a shockwave, with a small screen shake (it used to smash cracked floors; every room's cracked patches and pockets under the floor were filled in with `dev/world_fill.py`, backup in `data/world_before_fill/`) and strikes a guardian's heart twice as hard (off with Screen Shake off).
- Double jump: one more jump in the air (277 px/s, about 47 px of extra height; 45% more than the first version), reset on ground, wall and rope.
- Invincible dash: the hero cannot be hurt mid-dash; prismatic afterimages and a cool tint show it.
- Fast heal: holding Eat turns one food pip into one crystal in 0.3 s instead of 1 s.

Every junction between rooms can be climbed back up (notches in the holes; `dev/world_junctions.py` checks all 49 both ways).

## Area name

When the hero crosses into another region (and when a profile loads) the region's name appears in the bottom right corner: a dim "NOW ENTERING", the name in the region's colour, and a line that draws out under it. It fades in over 0.5 s, holds 3.2 s and fades out (`scripts/game/area_title.gd`). It sits opposite the HUD (bottom left) and does not block the screen.

## Shafts

The shafts between rooms have no ledges. Each has one climbable rope (vine in the Overgrowth) down the middle that runs through the floor hole above and the ceiling hole below, so the way up and down is a straight climb (the earlier ledged versions are in `data/world_before_clearing_shafts/`). The junction checker (`dev/world_junctions.py`) models rope climbing and proves all 49 junctions work in both directions.

## Ability effects

Drawn in code in `scripts/game/ability_fx.gd` (no textures), all in the pale cream-lavender of the hero plus the prism hue:
- **Ground pound:** on landing, two crescents race out along the floor and shrink, a flash line runs under them, short spark lines shoot up and dust kicks out both ways (0.45 s), with the small screen shake.
- **Double jump:** Monarch-style wings sprout from the hero's back: solid feathered shapes with a scalloped trailing edge and an ink outline, raised then beaten down once (0.36 s), shedding a few drifting feathers. The far wing is smaller and shaded.
- **Invincible dash:** a prismatic streamer ribbon (wide soft glow, two coloured edges, a white core) trails the hero and fades within 0.32 s, with a few sparks; the hero is tinted cool while untouchable.
Preview all three: `dev/capture_fx.gd`.

## HUD (Rain World style) and energy

Food is gone. Bottom left, laid out like Rain World's HUD: the **energy circle** (radius 13) on the left fills from the bottom with prismatic light over 30 seconds; when full its crystal glyph lights and it breathes, and holding Heal (F, rebindable) restores one crystal and empties it (1 s, 0.3 s with FAST HEAL; a bright arc runs round the circle while healing). Beside it the **health pips**: a pale ring around a soft inner disc (full) or a dim hollow ring (empty); they burst outward when hurt and swell back when healed. A vertical divider marks where the crystals earned from shards begin (after the base six). Above the pips, small **cooldown dots** appear once the abilities are learned: four for GROUND POUND (4 s cooldown) and three for the INVINCIBLE DASH (invincible at most once every 3 s; dashes in between are ordinary), rust while recharging and cream when ready. Currency sits under the pips. The inventory and the profile rows use the same round pips; the inventory shows the energy circle where food used to be.

## THE PRISMATIC LAKE (region 6)

One massive calm room (3x2 screens) under the LAKE GATE, authored by hand in `dev/make_lake.py`. The rope from the shaft continues down to the top of a stair cut into the cliff (4-row steps); at its foot a vermilion torii gate, then a long wooden bridge with a railing over the rainbow lake, and on a stepped plinth a three-tier pagoda (white walls, vermilion pillars, slate roofs with gold-edged upturned eaves, a glowing doorway, a spire with a prism jewel) flanked by stone lanterns. Glowing crystal columns stand in the cavern behind. The rest point is at the temple door. No enemies, no gift, nothing hard: the checker passes it even with the hero at 65% strength, both ways.
