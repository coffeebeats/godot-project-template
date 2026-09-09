---
name: add-hud-element
description: Add a new kind of HUD element — a status icon strip, a cast bar, a stack counter — alongside the stock HudBar, HudNumbers and HudIndicator. Use when no stock element fits; to place existing elements on an entity, use add-entity-hud instead.
user-invocable: true
argument-hint: "<element_name> [what it shows]"
---

A HUD element is a plain `Control` with its own typed API, its tunables in a style `Resource`, and its colors from a theme type variation. There is **no shared base class**, because nothing is common enough to justify one — so a new kind needs no change to `HudLayer`, `HudGroup` or any other element, and cannot be blocked by one.

Before starting, check that a stock element with a different style resource does not already do this. Damage and critical numbers are one element with two styles, not two elements.

## Steps

1. **Create the directory** `project/ui/hud/<element>/` holding `<element>.gd`, `<element>.tscn`, `style.gd` and at least one preset `.tres`. Copy the shape from `project/ui/hud/bar/`, which is the smallest complete example.

2. **Write the element script** as `class_name Hud<Name> extends Control`, using the `Node` script template. Its public API is whatever the *game* would want to say — `set_value(value, max_value)`, `pop(value)` — named for the thing it shows, not for the channel it arrives on.

   Two rules bind every element, both because breaking them fails silently:

   - **Public methods must work before the element's own `_ready`.** An entity placed in a map scene at author time calls them from a `_ready` that runs first, so an element resolving its children with `@onready` must guard on `is_node_ready()` and apply the value when it is ready. `HudBar.set_value` is the worked example, and `bar_test.gd:test_value_set_before_ready_is_applied` is the test to copy.
   - **Find the group with `HudGroup.of(self)`, never `owner`.** `owner` names the root of the scene the element was *saved* in, which stops being the group the moment the element sits inside a sub-scene reused across several groups. `group_test.gd:test_of_finds_the_group_from_an_element_it_does_not_own` covers it.

3. **Split appearance from behavior.** This is the dividing line Godot itself draws:

   | Goes in the theme type variation | Goes in the style `Resource` |
   | --- | --- |
   | Colors, fonts, styleboxes, icons | Durations, delays, curves, distances, easing |
   | Anything `Theme` can express | Anything it cannot |

   Add the variation to `project/ui/theme.tres` named `hud_<element>`, following `hud_bar` and `hud_number`. Write `style.gd` as `class_name Hud<Name>Style extends Resource` using the `Resource` script template, with one `@export` per tunable and a doc comment saying what it does in feel terms, not in units. Ship at least one preset `.tres`.

   Use `StdTweenCurve` for any curve export — `HudBarStyle.drain` and `HudNumberStyle.motion` both do, and it carries the delay as well as the easing.

4. **Render with no art.** Every stock element draws from theme boxes, `ProgressBar`s or `_draw`, so the template ships no textures. Follow that: a new element that needs a `.png` to be legible is a game's element, not the template's.

5. **Reach world space through the group, never the layer's `Variant` API.** If the element needs a screen position:

   - `HudGroup.make_world_origin()` returns a `Callable` that freezes the entity's world point and re-projects it on every call — what keeps a floating number over the spot it came from while the camera pans.
   - `HudGroup.project_target()` returns the entity's live, **unclamped** projection — what an arrow pinned to the viewport edge points along. Reading the element's own rect instead gives where it *is*, not where it should point, which is a bug `HudIndicator` shipped once.

   Both keep the dimension-blind `Variant` handling in one place. `HudLayer.of(self)` is still the way to reach `get_screen_rect()`, and to parent something that must outlive the group.

6. **Write the test** as `project/ui/hud/<element>/<element>_test.gd`, in the fixture shape of `bar_test.gd` — map double, `SubViewportContainer`, `SubViewport`, a later `UI` sibling holding the layer. Cover the API, the pre-`_ready` call from step 2, and whatever the style resource is supposed to change.

7. **Verify.** `gdformat --check`, `gdlint`, `godot --headless -s tools/check.gd`, then GUT (see AGENTS.md Commands). For anything whose point is how it looks or moves, confirm it on a live game with the `run-game` skill; `tools/bridge.sh call hud` reports every element's class, rect and visibility.

8. **List the element** in the stock-element table of the `add-entity-hud` skill, so the next session placing a HUD finds it without reading the directory. `AGENTS.md` names no elements and does not change.

## Key reference files

- `project/ui/hud/bar/` — the smallest complete element: script, scene, style, preset, test
- `project/ui/hud/numbers/` — an element that spawns its own nodes and needs world space
- `project/ui/hud/indicator/` — an element that draws itself and reads group state
- `project/ui/hud/group.gd` — `of`, `make_world_origin`, `project_target`, `is_target_in_view`
- `project/ui/hud/layer.gd` — `of`, `get_screen_rect`, and why the layer holds no game vocabulary
- `project/ui/theme.tres` — the `hud_*` type variations
- `addons/std/tween/curve.gd` — `StdTweenCurve`
- `script_templates/Node/node.gd`, `script_templates/Resource/resource.gd` — the file shapes
