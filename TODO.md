# TODO

- Add more prototype-owned scenes under `project/prototypes/` when needed.
- Add the game-component simulation harness before adding simulation CI.
- Add a prototype catalog and selector only when a second prototype needs it.
- Keep the Web deployment wrapper fixed to `_template` / Web / wasm32 / unknown / release
  until deployment requirements change.

## PR queue

1. Open the existing `godot-project-template` branch with its `__pycache__/` ignore and
   bridge shutdown fix.
2. Open gitignore-only PRs for `godot-plugin-std`, `godot-plugin-template`,
   `godot-plugin-baproto`, and `godot-prototype-template`.
3. Open the `godot-prototypes` pruning PR, including its gitignore and bridge fixes.
4. Review the pre-existing `addons/gut` and `addons/std` changes in `godot-prototypes`;
   open dependency PRs only if those revisions are intentional.

`godot` and `godot-infra` already ignore `__pycache__/` and need no PR for it.
