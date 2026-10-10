# Progressive generation and integration workflow

This repository is the complete implementation. Use this workflow to extend or rebuild it in small reviewable steps while preserving the contracts in [BLUEPRINT.md](BLUEPRINT.md).

## Working agreement

Create a feature branch from `main`. Keep each commit focused on an independently explainable system or change. The development branch for the initial game is `feat/beneath-the-quiet`; its history is split into at least 25 substantive commits. Open a pull request, wait for validation, review the rendered game, and merge after review. Do not rewrite shared history or force-push.

Use tabs in GDScript, `class_name` for reusable types, typed arguments and return values, and explicit `as` casts at scene/resource boundaries. Runtime collections use typed `Array` and `Dictionary` where their contents are known. `Variant`, untyped arrays and plain dictionaries belong at JSON, input and serialized data boundaries; validate them before passing them to the simulation. Godot 4.4 is the minimum because the code uses typed dictionaries.

Resource definitions describe content; nodes own behavior. A renderer or menu must never charge survival, create currency, grant objectives, or alter generated soil directly. Signals describe completed facts. UI actions go through the session or progression system. Keep visual time separate from simulation time. Do not add autoloads for convenience when an explicit dependency would do.

## Implementation order

| Stage | Files to generate or change | Completion gate |
| --- | --- | --- |
| 1. Project and assets | `project.godot`, icon, fonts/license, `.editorconfig` | Correct engine version; bundled font imports |
| 2. Resource contracts | `scripts/data/*`, `data/balance.tres`, five biome resources, twelve skill resources | Typed exports; valid IDs and prerequisite graph |
| 3. Terrain | `SoilCell`, `WorldGenerator` | Same seed/coordinates produce same cells; negative chunk boundaries and cache eviction pass |
| 4. Worm | `worm_controller.gd`, `worm.tscn` | One-cell movement; connected historical tail; interpolated render positions |
| 5. Survival | `survival_system.gd` | Pressure/density/friction change costs; restoration and depletion are signaled |
| 6. Progression | `upgrade_system.gd` | Atomic purchases; costs/rank caps/prerequisites; fresh derived attributes |
| 7. Persistence and composition | `save_store.gd`, `game_session.gd`, `session.tscn`, input bindings | Round-trip/backup recovery and a complete objective route pass |
| 8. Presentation | ASCII field, film shader, terminal style/buttons/HUD/cards/atlas/overlay | Visible FOV, clear legend, no clipping; all menu controls work |
| 9. Audio and root scene | Audio generator/assets/runtime, `game_root.gd`, `main.tscn` | Title → gameplay → evolution → atlas → ending → continued exploration |
| 10. Release support | Tests, validation, export presets, CI, documentation | `python3 tools/validate.py` passes; six screenshots inspected |

Interfaces may be generated before their implementations, but do not commit placeholder gameplay or silently stub a dependency to make a build pass. Implement the contracted behavior and test its externally visible consequences. Keep every `.tres` and `.tscn` resource reference explicit and valid. Godot-generated `.gd.uid` and source `.import` files belong in version control; `.godot/` and export artifacts do not.

## A bounded implementation prompt

Use a request like this for each change:

> Implement the named system in the listed files. Read the current resource and node contracts first. Keep those APIs stable. Use statically typed GDScript, explicit dependency injection, and typed signals. Define the change's player-visible behavior. Implement it completely; add or adjust only meaningful tests for that behavior. Run the project validation and inspect any affected screen. Report files changed, behavior changed, and checks run.

If a human explicitly authorizes multiple agents, give each agent a disjoint write set. Resource schema/API changes must finish before parallel consumers start. Workers should not edit the same scene, composition root or catalog. The integrator owns resource registration, scene references, final input routing, tests and visual QA. Parallelize independent system slices only after their contracts are concrete.

## Repeatable local checks

```bash
# One command imports everything, parses every runtime script, runs both suites,
# and starts the main scene with isolated temporary test saves.
python3 tools/validate.py

# A different engine binary, useful for checking the minimum supported version.
python3 tools/validate.py --godot /path/to/Godot

# Regenerate the original audio, then import and validate the changed assets.
python3 tools/generate_audio.py
python3 tools/validate.py
```

For visual changes, follow [TESTING.md](TESTING.md). `--headless` is appropriate for simulation and UI integration; it cannot validate actual screen shader output. Screenshot generation requires a real display or a virtual display on CI.

## Common extensions

**A new biome:** create a `BiomeDefinition` `.tres`, add its path to `WorldGenerator.BIOME_PATHS` in depth order, and check density, dryness and visual contrast in that stratum. No UI rewrite is required.

**A new skill:** define its ID, branch, rank limits, costs, prerequisite and effects in a `.tres`; register it in `UpgradeSystem.SKILL_PATHS`. Existing effects need no simulation edits. A genuinely new effect needs a typed attribute, an `apply_effect` case, an entry in `EFFECT_KEYS`, a consumer, and behavior tests. The shipped tree layout supports four tiers per branch; additional tiers need a scrollable layout.

**A new pickup:** extend the `SoilCell.Item` enum and its glyph/color mapping, seed placement, session rewards, survival behavior if needed, legend and tests. Use `pickup_collected` for audio and visuals. Keep item collection idempotent after chunk eviction and save/load.

**Region-file persistence:** replace the three sparse in-memory world stores behind the existing generator API. Keep coordinate-deterministic generation and immutable base cells. Add migration for save version 1 before changing the format.

**Alternate presentation:** retain `GameSession` and use a different renderer that reads its state and subscribes to its signals. Preserve the separation between logical grid cells and interpolated body positions.
