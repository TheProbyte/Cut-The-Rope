# DRIP

A cozy 2D mobile physics puzzle game for Android, built with **Godot 4.3**. Guide a shape-shifting water droplet through single-screen Greenhouse and Kitchen puzzles to water a thirsty little seedling.

## Core mechanic: state switching
Tap anywhere on the playfield to cycle the droplet **Water → Ice → Steam**:
- **Water**: a soft, wobbly drop. It rolls down slopes, slips through grates, soaks into sponges, and is the only state that waters the seedling.
- **Ice**: a heavy crystal cube. It slides fast, bridges grates, bounces over sponges and smashes glass.
- **Steam**: a fluffy cloud. It floats upward, rides fan currents, and condenses back to water on cold pipes.

Tap **Fans** to switch them on or off, and tap soaked **Sponges** to squeeze them. Neither tap changes the droplet's state.

## Worlds (20 levels, 60 suns)
- **Greenhouse (1–10):** grates, glass, heat lamps, freezer zones, fans, cold pipes, drains.
- **Kitchen (11–20):** adds sponges, hot plates and sliding trays. It unlocks once the Greenhouse finale is watered.

Each level hides 3 suns on the riskier or cleverer routes. Reaching the seedling with 0 suns still completes the level.

## What's in v0.3 (the overhaul)
- **Art:** one shared drawing kit (`scripts/core/Art.gd`) gives every piece rounded shapes, gradients and soft shadows. Platforms, grates, glass, fans, pipes, lamps, freezers, sponges, hot plates, trays and the spout are all redrawn. The background is a layered world (`WorldBackground`) that fills tall phones edge to edge.
- **Characters:**
  - The droplet (`DropletArt`) morphs between states, squashes and stretches in the direction it moves, and changes expression.
  - Its trails stay where they were spawned, and it gets fail animations (drain swirl, sizzle, evaporate).
  - It soaks into the soil when it waters the seedling. The seedling droops, perks up, shivers, and blooms with spring-loaded petals and confetti.
- **Transitions:**
  - A liquid iris closes on whatever you tapped.
  - Level pieces cascade in and the droplet drips from its spout.
  - Restart is a quick wipe, and winning brings slow motion and a camera push-in on the seedling.
- **UI:**
  - Vector icon buttons and a vine-path world map you can swipe between worlds.
  - The HUD shows mini droplets in the state dock and has a dismissible hint with a button to bring it back.
  - Win and fail cards have ribbon banners, suns that slam in, confetti, and "new best" / "world unlocked" tags.
  - The main menu has a Continue button and a live character showcase.
- **Mobile:**
  - Fills 18:9 and 20:9 phones (no letterboxing) and respects notches and safe areas.
  - The Android back button pauses a level instead of leaving it, and the game auto-pauses when backgrounded.
  - Haptics (with a toggle), atomic save writes, and new launcher icons (adaptive and legacy).
- **Audio:** seamless music loops for the menu, Greenhouse and Kitchen that crossfade between screens. All sound effects are softened, there are new ones for transitions, wins, fails and unlocks, and the music ducks under the win jingle.
- **Progress:** level numbering and next-level / world unlocking are now generic (driven by `worlds.json`), so new worlds need no code changes.

## Installing on Android
Every push to `main` runs `.github/workflows/build-android.yml`. It validates the level JSON, solves every level and smoke-tests the game flow, then exports a signed debug APK and attaches it to a new **GitHub Release**.

1. Open the repository's **Releases** page on your phone.
2. Download the latest `drip-v*.apk`.
3. Open it to install (allow *Install unknown apps* if asked).

## Development
```bash
python3 tools/validate_levels.py                                     # level JSON sanity
godot4 --headless --fixed-fps 60 res://tests/VerifyLevels.tscn       # solves all 20 levels (3/3 suns each)
godot4 --headless --fixed-fps 60 res://tests/FlowTest.tscn           # menu → play → win → next → pause → fail → back
python3 tools/generate_assets.py                                     # regenerate SFX + music
godot4 --rendering-driver opengl3 -s res://tools/render_icon.gd      # re-render launcher icons (needs a display)
godot4 res://tests/Screenshot.tscn -- level greenhouse 0 /tmp/l1.png # screenshot a screen
```

**Adding a level:** drop a JSON file in `data/levels/<world>/` and list it in `data/levels/worlds.json`. **Adding a world:** add an entry to `worlds.json`. Numbering, unlocking and "next level" adapt on their own. A new visual theme name can be added in `WorldBackground`.
