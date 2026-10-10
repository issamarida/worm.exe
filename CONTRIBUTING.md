# Contributing

Use Godot 4.4+ and Python 3. Start with [the blueprint](docs/BLUEPRINT.md) and [the integration workflow](docs/AI_WORKFLOW.md). Open the project with Godot and press F5 to play, or use `./tools/run.sh`.

Create a focused `feat/`, `fix/`, or `docs/` branch from `main`. Make meaningful Conventional Commits, such as `feat(world): persist softened soil across chunk eviction`. Commit source `.import` and `.gd.uid` metadata, and leave `.godot/`, binaries, test saves and routine captures out of Git.

Run `python3 tools/validate.py` before a pull request. For visual changes, render and inspect the affected screens. Keep arguments/returns, node references and collections typed; validate external data at the boundary. Own gameplay state in systems and route UI actions through their public interfaces. Catalog resources should not be mutated at runtime.

Explain the final player-visible behavior, its purpose and its validation in the PR. Keep API and resource changes together with their consumers. Avoid placeholder gameplay and avoid tests that merely repeat implementation details. To preserve the initial development history of at least 25 focused commits, merge that branch with a merge commit or rebase rather than squashing it into one commit.
