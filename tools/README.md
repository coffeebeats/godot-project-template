# Tools

Development tooling for this template.

| Path | Purpose |
| --- | --- |
| `tools/aseprite.sh` | Bakes `.aseprite` to a PNG sheet plus a tag manifest. |

The bridge that drives a running game and the translation catalogue tooling ship in agent
plugins instead, as `godot-bridge` in kit's and `godot-locale` in `godot-infra`'s. Both are
on Claude Code's `PATH` while `.claude/settings.json` enables those plugins. Codex puts
neither there, so each is reached through the plugin skill of the same name.

## Python tooling

Repository tooling uses the dependencies in `pyproject.toml`, locked in `uv.lock`. Run the
same checks as CI with:

```sh
uv lock --check
uv run ruff check .
```

Ruff checks any Python tooling; `custom.py` is excluded because it is a SCons build-options
file rather than a Python program.

## `tools/aseprite.sh`

Bakes `.aseprite` sources to a horizontal PNG sheet plus a tag manifest, both read by
Godot's stock importer. Verified against **Aseprite 1.3.18.3**.

```sh
tools/aseprite.sh assets/src/hero.aseprite       # beside the source
tools/aseprite.sh --out assets/baked assets/src  # a whole directory
```

The export command:

```sh
aseprite -b src.aseprite --sheet out.png --sheet-type horizontal \
         --data out.json --format json-array --list-tags
```

`--list-tags` is what emits `meta.frameTags[]`; without it the data file describes no
animations at all. There is no `--trim`, because uniform full-canvas frames are what
`hframes` and `SpriteFrames` expect.

### The manifest

Aseprite's own JSON carries `meta.image` as an absolute path and `meta.version` as the
installed binary, so committing it verbatim churns the file on every machine and every
upgrade. What is kept is what a consumer reads:

```json
{ "source": "sprite.aseprite", "size": [64, 16], "frame_size": [16, 16],
  "frames": [{"duration": 100}, {"duration": 200}],
  "tags": [{"name": "idle", "from": 0, "to": 1, "direction": "forward"}] }
```

Durations are milliseconds and `direction` is `forward`, `reverse` or `pingpong`; a tag's
`repeat` is carried through when 1.3 emits it.

Both halves go through the stock importer with nothing else installed: the PNG imports as
a `CompressedTexture2D` with a `.import` sidecar, and `load()` on the manifest returns a
`JSON` whose `.data` is the dictionary above. Read numbers out of it with `int(...)`,
since JSON has one number type and `from` and `to` arrive as floats.

No `SpriteFrames` generator ships with this. The manifest carries what one needs: the
frame size, each frame's duration, and every tag's range and direction.

### The fixture

`tools/testdata/sprite.aseprite` is four 16x16 frames with distinct colours, two tags and
a different duration per frame, so a manifest that loses tags, reorders frames or drops
timing is visibly wrong. It is generated rather than hand-drawn, and regenerating it is:

```sh
aseprite -b --script tools/testdata/make_sprite_fixture.lua
```

`tools/.gdignore` keeps all of this out of the import pipeline.

### What fails silently

**Never filter `*.aseprite` in an export preset.** A filter matching a source also drops
the `.res`/`.sample` baked beside it, and nothing says so until an exported build looks
for the asset at runtime. The presets here filter only `LICENSE.*`, `*.md` and tests.

**Outputs are named after the source's basename.** Two sources called `hero.aseprite`
in different directories and one `--out` would overwrite each other, so the script
refuses the second rather than baking it; give them distinct names or separate `--out`
directories.

**The binary's path is per-machine.** It is found through `ASEPRITE`, then `PATH`, then
the usual install locations.
