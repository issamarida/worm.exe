# Testing and release checks

## Play from source

Install Godot 4.4 or later. Open `project.godot` in the editor and press **F5**, or run `./tools/run.sh`. The helper imports source assets first, so it also works on a fresh clone. Use `GODOT_BIN=godot4 ./tools/run.sh` if your executable has that name. On Windows, import `project.godot` in the Godot project manager and press F5.

## Automated checks

```bash
python3 tools/validate.py
python3 tools/validate.py --godot /path/to/Godot
```

The validator imports assets, parses all 21 runtime scripts, runs 95 simulation checks and 20 interface checks, and smoke-tests the main scene for 90 frames. It detects failures from both exit codes and logs because script errors can leave Godot's exit code at zero. Tests use temporary XDG data/config directories, leaving a player's real save alone.

Simulation checks cover deterministic generation, distant and negative coordinates, bounded chunks, persisted edits after eviction, soil softening, continuous body interpolation, connected tails, surface restrictions, movement charging, survival pressure, rescue, every skill rank, save integrity and backup recovery, and an actual route to the ending. UI checks cover skill cards, purchase signals, wheel zoom, settings, modal transitions, real keyboard movement, pulse input, save/continue, and new-game cancellation.

CI runs the pipeline with the official Godot 4.4.1 and 4.5.1 editors. Local validation also uses Godot 4.7.2. Verify other platforms and engine versions before claiming support.

## Visual QA

Headless checks cannot exercise the actual OpenGL screen shader. Capture the game with a real display:

```bash
XDG_DATA_HOME=/tmp/worm-visual-data \
XDG_CONFIG_HOME=/tmp/worm-visual-config \
godot --path . --audio-driver Dummy --resolution 1440x900 \
  --script tests/capture_game.gd -- --output=/tmp/worm-visuals
```

The script writes `title.png`, `play.png`, `evolution.png`, `atlas.png`, `guide.png`, and `ending.png`. Inspect the font, soft light, item contrast, film output and button layout at full resolution and the intended window size. Exported binaries and routine screenshots remain ignored; a curated gameplay image is stored in `docs/images/` for the README.

## Manual pass

1. Start a new journey with Enter and the title button.
2. Test WASD, arrows, held-key corners, reversing, and crossing the body.
3. Collect `%`, `~`, and `*`; check meters, currency, field notes and sound.
4. Use Space; check radius, duration and cooldown.
5. Buy skills with E; check ranks, prices, prerequisite locks, soil changes and derived attributes.
6. Open M, inspect paths and landmarks, and wheel-zoom. Explore beyond the final biome and check the map follows distant coordinates.
7. Use R from depth. Confirm the channel returns the body with inventory intact. Rest at home and verify both meters refill.
8. Deplete a meter. Check rescue preserves progression and loses the rounded-up 30% of unspent spores.
9. Find three echoes, collect Ω, and return home. Check the ending and continued exploration.
10. Quit and continue. Verify seed, body, edits, discovery, ranks, objective state and journal persist.
11. Test Esc, F1, F10, F11, film and reduced motion. Alt-tab away and confirm gameplay pauses.
12. Resize and fullscreen. Check the 16:10 letterboxed layout and readable text on every release platform.

## Export

Install templates matching your exact Godot version through **Editor → Manage Export Templates**, then use **Project → Export**. Equivalent commands:

```bash
mkdir -p builds/linux builds/windows builds/web
godot --headless --path . --export-release Linux builds/linux/worm.exe.x86_64
godot --headless --path . --export-release Windows builds/windows/worm.exe
godot --headless --path . --export-release Web builds/web/index.html
```

Desktop presets embed the PCK. Web uses Compatibility rendering and a single-threaded runtime. Serve Web exports from HTTP. Browser sound may require interaction, and browser saving, fullscreen and keys need a separate manual pass. Binary exports are not included in the repository.

A source pack does not require export templates:

```bash
mkdir -p builds
godot --headless --path . --export-pack Linux builds/worm.pck
godot --main-pack builds/worm.pck
```

## Save files

The real save is `user://burrow-v1.json`, with `.bak` recovery and a separate `settings.cfg`. Typical Linux installs use `~/.local/share/godot/app_userdata/worm.exe — Beneath the Quiet/`. Use **Project → Open User Data Folder** in the editor for the exact location. Back up the folder before deliberate corruption/migration tests.

Regenerate sound with `python3 tools/generate_audio.py`. Retain a matching engine version when comparing procedural worlds across releases.
