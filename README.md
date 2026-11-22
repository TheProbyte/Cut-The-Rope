# DRIP

A cozy 2D mobile physics puzzle game for Android built with **Godot 4.3**. Guide a shape-shifting water droplet through single-screen sunlit greenhouse puzzles to water a thirsty little seedling!

## Core Mechanic — State Switching
Tap anywhere on the playfield to cycle the droplet between three physical states:
- **Water**: Soft, wobbly droplet that flows down slopes, slips through grates, and waters the seedling.
- **Ice**: Heavy beveled cube that slides fast, bridges across grates, and shatters thin glass panes.
- **Steam**: Fluffy buoyant cloud that floats upward, glides along sloped glass roofs, and rides fan currents.

Tap interactive objects (like **Fans**) directly to toggle them ON or OFF without switching the droplet's state.

## World 1: Greenhouse (10 Levels)
1. **Morning Dew** — Water flow, Ice glass smash, watering the seedling
2. **Rising Mist** — Steam buoyancy, sloped glass roofs & Drain hazards
3. **Through the Grate** — Grates (Ice bridges, Water slips through) + bonus Steam detour
4. **Warm Glow** — Heat Lamps (forced Steam)
5. **Frost Pocket** — Freezer Zones (forced Ice) + Glass & Grate combo
6. **Gentle Breeze** — Tappable Fans
7. **Cold Pipe** — Cold Pipes (condense Steam back into Water)
8. **Crosswinds** — Dual Fans + Grate + Drain navigation
9. **Thermal Cycle** — Heat Lamp → Cold Pipe → Freezer Zone chain
10. **Glasshouse Finale** — All Greenhouse mechanics combined

## Installing on Android
Every push to `main` triggers the GitHub Actions workflow (`.github/workflows/build-android.yml`), which validates all level JSON files, builds `drip-debug.apk`, and attaches it to the latest **GitHub Release**.

1. Open the repository's **Releases** page on your Android phone.
2. Download `drip-debug.apk` from the latest release.
3. Open the downloaded file to install (enable *Install unknown apps* if prompted).

## Adding New Levels
Levels are plain JSON files under `data/levels/<world>/` registered in `data/levels/worlds.json`. All coordinates use the `720×1280` portrait logical playfield.

Validate levels locally with:
```bash
python3 tools/validate_levels.py
```

Run the automated Godot 4.3 headless 10-level physics verification:
```bash
godot4 --headless res://tests/VerifyLevels.tscn
```
