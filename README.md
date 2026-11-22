# DRIP

A cozy 2D mobile physics puzzle game for Android built with **Godot 4.3**. Guide a shape-shifting water droplet through single-screen sunlit Greenhouse & Kitchen puzzles to water a thirsty little seedling!

## Core Mechanic — State Switching
Tap anywhere on the playfield to cycle the droplet between three physical states:
- **Water**: Soft, refractive droplet that flows down slopes, slips through grates, gets soaked up by sponges, and waters the seedling.
- **Ice**: Heavy beveled crystal cube that slides fast, bridges grates, bounces over sponges, and shatters thin glass panes.
- **Steam**: Fluffy buoyant cloud that floats upward, glides along sloped roofs, rides fan currents, and condenses back into water on cold pipes.

Tap interactive objects (**Fans** and **Sponges**) directly to toggle or squeeze them without switching the droplet's state.

## Worlds & Levels (20 Levels • 60 Stars)

### World 1: Greenhouse (Levels 1–10)
1. **Morning Dew** · 2. **Rising Mist** · 3. **Through the Grate** · 4. **Warm Glow** · 5. **Frost Pocket** · 6. **Gentle Breeze** · 7. **Cold Pipe** · 8. **Crosswinds** · 9. **Thermal Cycle** · 10. **Glasshouse Finale**

### World 2: Kitchen (Levels 11–20)
Introduces **Sponges**, **Hot Plates**, and **Moving Platforms**:
11. **Soak It Up** · 12. **Sizzle Stop** · 13. **Sponge & Ice** · 14. **Steam Kettle** · 15. **Sliding Tray** · 16. **Pantry Timing** · 17. **Drafty Stove** · 18. **Double Sponge** · 19. **Chef's Contraption** · 20. **Grand Kitchen Finale**

## Installing on Android
Every push to `main` triggers `.github/workflows/build-android.yml`, which validates all level JSON files, exports a signed `drip-debug.apk`, and attaches it to the latest **GitHub Release**.

1. Open the repository's **Releases** page on your Android phone.
2. Download `drip-debug.apk` from the latest release.
3. Open the downloaded file to install (enable *Install unknown apps* if prompted).

## Local Validation & Physics Tests
```bash
python3 tools/validate_levels.py
godot4 --headless res://tests/VerifyLevels.tscn
```
