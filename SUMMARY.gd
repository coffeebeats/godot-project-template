##
## SUMMARY.gd
##
## Branch summary for `feat/project/world-coordinates`. Captures background,
## goals, completed work, dismissed designs, open considerations, and next
## steps for the ProjectMap projection bridge + composable WorldTracker
## components. This file is documentation only; it is not loaded at runtime.
##

## ============================================================================
## BACKGROUND / CONTEXT
## ============================================================================
##
## The project template ships three style-specific base map templates under
## `project/maps/base/`:
##
##   - `2d/`        — straight 2D rendering inside a `SubViewport`.
##   - `2d_pixel/`  — 2D pixel art with smooth-camera rendering. Uses a
##                    `canvas_transform` rounding step in `frame_pre_draw`
##                    paired with a shader `vertex_offset` (Klems sampling) so
##                    sprites snap to the integer pixel grid while the shader
##                    visually cancels the snap. The net effect is sub-pixel
##                    smoothness without aliasing on rotation/zoom.
##   - `3d/`        — 3D rendering with a `Camera3D` inside the `SubViewport`.
##
## All three host their game world inside a `SubViewportContainer ->
## SubViewport` pair. HUD widgets live in a sibling `Control` subtree (so they
## render at HUD resolution rather than world-pixel resolution).
##
## The branch began life trying to solve a single concrete need: a tooltip
## that anchors to a `Node2D` living inside the world `SubViewport`. That
## first attempt was an inheritance chain — `TooltipWorld2D extends Tooltip
## extends CenterContainer` — which conflated world-tracking with the
## tooltip-specific concerns Tooltip already carries (hover delays, fade
## animations, anchor-to-face positioning). It also made the world-tracking
## code unreusable for any other widget type, since GDScript only allows
## single inheritance.
##
## A short detour explored a `TooltipNode2D extends Tooltip` variant (anchor
## via `NodePath`). Same shape, same fundamental problem. Both inheritance
## experiments were scrapped in favor of composition.
##

## ============================================================================
## GOALS
## ============================================================================
##
## 1. Provide a single reusable mechanism for any HUD `Control` to follow a
##    world-space entity inside a map's `SubViewport`. Use cases include
##    health bars, damage numbers, name plates, tooltips, and off-screen
##    indicators.
##
## 2. Decouple world-tracking from widget-specific concerns. Tracking should
##    not require inheriting from a particular base class.
##
## 3. Achieve pixel-perfect visual alignment between HUD and world content.
##    The 2D pixel base mutates `canvas_transform` during the camera's
##    `_process`. A widget that reads `canvas_transform` BEFORE the camera
##    writes it lags world content by one frame, producing a visible shimmer.
##    The fix must be enforced at config time, not left to convention.
##
## 4. Surface misconfigurations loudly at startup with actionable assertion
##    messages, not as subtle visual drift at runtime.
##
## 5. Mirror the existing `ProjectMap` / `ProjectMap3D` split with parallel
##    `WorldTracker2D` / `WorldTracker3D` classes. Static typing on the
##    target gives compile-time errors instead of runtime dispatch.
##
## 6. Keep the API minimal. No round-trip / inverse APIs, no rectangle
##    helpers, no off-screen-indicator clamping until a real consumer asks
##    for it.
##

## ============================================================================
## WORK COMPLETED
## ============================================================================
##
## --- ProjectMap base (2D projection bridge) ---
##
## `project/maps/base/scene.gd`:
##
##   - Added `class_name ProjectMap` so trackers and tests can reference the
##     type without a `preload`.
##   - Moved `_get_container()` up from `2d_pixel/scene.gd`. All subclasses
##     now share it.
##   - `_container_visual_scale()` returns the per-axis scale factor between
##     SubViewport-local pixels and SubViewportContainer-local pixels. It is
##     `Vector2.ONE` when `container.stretch == false` (the visual scale is
##     captured by `container.global_transform` in that mode); when stretch
##     is on, it equals `container.size / sub_viewport.size`.
##   - `viewport_to_hud(viewport_pos)` projects a SubViewport-local position
##     to HUD space by applying the visual scale and the container's global
##     transform.
##   - `world_to_hud_2d(world_pos)` composes `_world_to_viewport_2d` with
##     `viewport_to_hud`.
##   - Virtual `_world_to_viewport_2d(world_pos)` defaults to applying
##     `sub_viewport.canvas_transform`. Subclasses can override (the 2D pixel
##     base intentionally does not — see "Designs dismissed").
##   - New configuration warning when `stretch_shrink <= 0` while
##     `container.stretch` is on.
##
## --- ProjectMap3D ---
##
## `project/maps/base/3d/scene.gd`:
##
##   - `world_to_hud_3d(world_pos, camera = null)` uses
##     `Camera3D.unproject_position` then `viewport_to_hud`. If `camera` is
##     null, it falls back to `sub_viewport.get_camera_3d()`. Returns
##     `Vector2.INF` (check via `pos.is_finite()`) when projection cannot
##     happen: no SubViewport, no active or supplied camera, or the position
##     is behind the camera. Off-frustum-but-in-front projections produce
##     finite (off-screen) HUD coordinates by design — useful for off-screen
##     indicator widgets that clamp to viewport edges.
##
## --- 2D pixel base ---
##
## `project/maps/base/2d_pixel/scene.gd`:
##
##   - Removed the local `_get_container()` (now inherited from base).
##   - Added `get_container_scale()` and `get_container_offset()` accessors
##     for the integer-scaling container transform. These exist for callers
##     that need the raw values (e.g. shader parameter wiring) outside the
##     projection bridge.
##   - Added a NOTE in `_on_frame_pre_draw` explaining why no
##     `_world_to_viewport_2d` override is needed: callers in `_process`
##     read the un-rounded `canvas_transform`. The rendered sprite ends up
##     at `rounded * world_pos + shader_remainder`, which equals
##     `unrounded * world_pos`. Projection therefore agrees with rendered
##     content as long as it happens during `_process` (before
##     `frame_pre_draw` fires). Future overrides must respect that ordering.
##
## --- WorldTracker2D / WorldTracker3D ---
##
## `project/ui/tracker/world_tracker_2d.gd` and
## `project/ui/tracker/world_tracker_3d.gd`:
##
##   - Both declare `class_name WorldTracker2D` / `WorldTracker3D` so they
##     are inspector-droppable and tab-completable from scene scripts.
##   - Both extend `Node` (not `Control`) deliberately. A `Control` tracker
##     would contribute to layout (size flags, anchors, focus traversal)
##     and could fight with the host widget's own layout. `Node` is
##     invisible to layout; its only job is to write to its parent each
##     frame.
##   - Three exports: `map` (typed `ProjectMap` / `ProjectMap3D`), `target`
##     (typed `Node2D` / `Node3D`), `offset` (HUD-space pixels).
##   - `_process` projects `target.global_position`, applies `offset`,
##     writes to `_host.global_position`. The 3D variant skips the write
##     when `world_to_hud_3d` returns non-finite (host keeps its last
##     position rather than jumping to `(-INF, -INF)`).
##   - `_ready` uses a defensive double-validation pattern throughout:
##     `assert(X, "...")` followed by `if not X: return`. The asserts fire
##     loudly in debug builds (where misconfigurations are actionable);
##     the early-returns keep release builds (where asserts are stripped)
##     from crashing on the next dereference. The same pattern guards the
##     `_process` path against freed `map`/`target` references.
##   - Validation runs in two phases. First: parent must be a `Control`,
##     `map` and `target` must be set. If any fails, return early —
##     subsequent invariants would dereference them. Second:
##     `map.sub_viewport` exists, `target` lives inside it, and the
##     tracker's tree position is greater than the SubViewport's via
##     `is_greater_than(map.sub_viewport)`.
##
## --- Tests ---
##
##   - `project/maps/base/scene_test.gd`        — 7 cases on the 2D bridge
##                                                (identity, container
##                                                position/scale,
##                                                canvas_transform, combined
##                                                transforms, stretch with
##                                                shrink, no-subviewport
##                                                passthrough).
##   - `project/maps/base/3d/scene_test.gd`     — 6 cases on the 3D bridge:
##                                                in-front returns finite,
##                                                behind-camera returns
##                                                INF, no-camera returns
##                                                INF, no-subviewport
##                                                returns INF, explicit
##                                                `camera` arg overrides
##                                                the active camera, and
##                                                off-frustum-but-in-front
##                                                stays finite (the
##                                                contract that lets
##                                                off-screen-indicator
##                                                widgets clamp to viewport
##                                                edges).
##   - `project/ui/tracker/world_tracker_2d_test.gd` — 8 cases (projection,
##                                                offset, camera-pan
##                                                follow, target-move
##                                                follow, freed-target
##                                                no-op, three startup
##                                                assertions).
##   - `project/ui/tracker/world_tracker_3d_test.gd` — 8 cases (the 2D set
##                                                adapted, minus the
##                                                camera-pan test, plus
##                                                `test_no_op_when_behind_camera`).
##
##   All test fixtures use `partial_double(MapScript).new()` with
##   `stub(_map, "_ready").to_do_nothing()` because the real `_ready`
##   calls `Main.get_active_save_data()`, which requires the full autoload
##   chain (Lifecycle, Platform, System) to be initialized. `before_all`
##   sets `debug/gdscript/warnings/native_method_override = false` to
##   silence the unactionable warning that `partial_double` triggers.
##
##   Last full-sweep result was clean (format, lint, all tests passing)
##   but the absolute number is omitted here because the project test
##   count drifts independently of this branch.
##
## --- Cleanup ---
##
##   - Deleted `project/ui/tooltip/tooltip_node2d.gd` (+ `.uid`). The
##     abandoned inheritance experiment is no longer reachable.
##   - Fixed an `animatint` -> `animating` typo in two assertion messages
##     in `project/ui/tooltip/tooltip.gd`.
##
## --- Branch state ---
##
##   `git log main..HEAD` is empty. All changes above live in the working
##   tree (modified or untracked); nothing has been committed yet. See
##   "Proposed next steps" for the suggested commit shape.
##

## ============================================================================
## DESIGNS DISMISSED
## ============================================================================
##
## --- Inheritance-based world-tracking widget ---
##
## The branch's first attempt was `TooltipNode2D extends Tooltip` (which
## itself extends `CenterContainer`), with a target node referenced via
## `NodePath`. An even earlier sketch (not present in this branch's
## history, but discussed during planning) layered a `TooltipWorld2D`
## subclass on top of `Tooltip`. Both shapes were rejected for the same
## reason: GDScript only supports single inheritance, so every widget
## type that wants world-tracking would need its own subclass,
## duplicating the tracking logic. Composition via a child `Node` lets
## one tracker serve every widget class.
##
## --- Single tracker class with runtime target dispatch ---
##
## A unified `WorldTracker` that accepted either `Node2D` or `Node3D` and
## dispatched at runtime. Rejected: the existing `ProjectMap` /
## `ProjectMap3D` split already captures the dimensional distinction, and
## static typing on `target` gives compile-time errors when a scene
## misassigns. Mirroring the split with `WorldTracker2D` / `WorldTracker3D`
## is consistent with the rest of the codebase.
##
## --- Implicit map discovery via ancestor walk ---
##
## A prior tracker iteration carried `_find_project_map()` that walked up
## the tree looking for a `ProjectMap` ancestor. Rejected because it is
## implicit (no editor visibility), fragile under reparenting, and ambiguous
## when a HUD lives in a different subtree than its corresponding map.
## Replaced with an explicit `@export var map`. Editors and scenes wire it
## directly; misconfigurations are visible in the inspector.
##
## --- `process_priority = 100` for ordering ---
##
## The original sketch forced trackers to run after the camera by bumping
## `process_priority`. Rejected because it is a magic number, silently
## breakable by any unrelated node bumping its own priority higher, and the
## failure mode (HUD pixel shimmer) is hard to debug. Replaced with the
## `is_greater_than(map.sub_viewport)` assertion, which leverages Godot's
## depth-first `_process` traversal: place the tracker in a subtree later
## than the SubViewport (typically a HUD that is a later sibling of the
## SubViewportContainer). The assertion fires loudly at startup if the
## convention is violated.
##
## --- Inverse / round-trip projection APIs ---
##
## Earlier iterations included `hud_to_world_2d`, `hud_to_viewport`,
## `world_to_hud_rect`, and round-trip tests that exercised them. Removed
## because no current consumer needs them. The forward direction
## (world -> HUD) is what trackers, anchored UI, and indicators all use.
## Inverses can come back if a real consumer (e.g. world-space click
## targeting from HUD coordinates) appears.
##
## --- Override `_world_to_viewport_2d` in the 2D pixel base ---
##
## Considered overriding the virtual to apply the same rounding the camera
## does in `frame_pre_draw`. Rejected once the math worked out: the shader's
## `vertex_offset` cancels the rounding visually, so a caller that reads
## the un-rounded `canvas_transform` during `_process` lands on the same
## screen pixel as the rendered sprite. Documented this in
## `_on_frame_pre_draw` so future maintainers do not "fix" the missing
## override.
##
## --- Off-screen indicator clamping helper ---
##
## Tempting to add `clamp_to_viewport_edge(hud_pos)` as a `ProjectMap`
## helper. Deferred until an actual off-screen-indicator widget exists to
## inform the API shape (clamp rectangle, edge margin, behind-camera
## handling).
##

## ============================================================================
## OPEN CONSIDERATIONS
## ============================================================================
##
## --- Multi-camera HUDs (3D) ---
##
## `WorldTracker3D` always uses `sub_viewport.get_camera_3d()` (the active
## camera). A scene with multiple `Camera3D`s where a HUD widget should
## track relative to a non-active camera (e.g. a minimap or rear-view
## indicator) cannot be expressed today. `world_to_hud_3d` already accepts
## an optional `camera` parameter; the natural extension is an
## `@export var camera: Camera3D` on the 3D tracker. Skip until needed.
##
## --- Re-assigning `target` or reparenting the tracker mid-life ---
##
## No test exercises swapping `tracker.target = other_node` after `_ready`,
## nor reparenting the tracker (e.g. moving its host into a different HUD
## subtree). The `_process` path tolerates both — it re-reads `target` and
## `_host` each frame — but the topology assertions in `_ready` only run
## once. A target swap to a node outside `map.sub_viewport`, or a
## reparenting that breaks the `is_greater_than(map.sub_viewport)`
## ordering, would silently produce wrong projections (or one-frame HUD
## lag) instead of asserting. If either pattern becomes common, either
## re-validate on assignment via setters / `NOTIFICATION_PARENTED` or
## document that swaps must stay inside the same SubViewport and the
## tracker must not be reparented out of its HUD subtree.
##
## --- Underspecified follow tests for 3D ---
##
## Two related gaps. `WorldTracker2D` has `test_follows_camera_pan`
## (mutate `canvas_transform`, verify host shifts by the same delta);
## `WorldTracker3D` has no equivalent (move the camera, verify host
## shifts in the opposite direction). Separately,
## `WorldTracker2D.test_follows_target_movement` asserts the host delta
## equals `(20, 0)` precisely; the 3D equivalent only asserts
## `host_pos != before` and `is_finite()`. Both 3D tests catch
## "something changed" but not "changed by the right amount", and would
## miss a sign error or magnitude bug.
##
## --- Concrete consumers ---
##
## No HUD widget actually uses these trackers yet. Damage numbers, health
## bars, name plates, off-screen indicators, and the rebuilt tooltip
## (host `Control` with `WorldTracker2D` child + `Tooltip` anchored to
## host) are all out of scope for this branch.
##
## --- Documentation ---
##
## `AGENTS.md` does not yet list "Adding a HUD widget" as a workflow.
## Would be a one-paragraph entry describing the
## `Control + WorldTracker2D/3D` pattern with a pointer to the tracker
## doc-comment for scene layout.
##
## --- 2d_pixel accessors ---
##
## `get_container_scale()` and `get_container_offset()` were added for
## anticipated shader-parameter wiring but have no in-tree consumer yet.
## If they remain unused after the demonstrator widget lands, they should
## be removed (per the project rule against speculative API surface).
##
## --- Test naming convention drift ---
##
## `AGENTS.md` specifies `test_<subject>_<scenario>_<expectation>`. Several
## new tests don't strictly fit: `test_follows_camera_pan` (no
## expectation), `test_no_op_when_target_freed` (subject/scenario blur),
## `test_positions_host_at_projection` (reads as a sentence, not the
## convention). Either tighten the names on the next sweep or relax the
## convention in `AGENTS.md`.
##

## ============================================================================
## PROPOSED NEXT STEPS
## ============================================================================
##
## 1. Commit the current branch and open a PR. The branch currently has
##    zero commits — all work is in the working tree. Suggested shape: a
##    single `feat(project): add ProjectMap world-projection bridge and
##    WorldTracker components` covering everything (the changes form one
##    cohesive feature and reviewing them split-out provides little
##    extra signal). The PR body should call out the
##    composition-over-inheritance pivot and the
##    `is_greater_than(sub_viewport)` ordering rationale.
##
## 2. Build a demonstrator widget on a follow-up branch. Strongest
##    candidate: rebuild the world-anchored tooltip as
##    `host Control + WorldTracker2D child + Tooltip anchored to host`.
##    This proves the composition story end-to-end and replaces the
##    deleted `TooltipNode2D` use case with a cleaner pattern.
##
## 3. Wire one demonstrator into a base map scene
##    (`project/maps/base/2d_pixel/scene.tscn` is the most demanding
##    target — pixel alignment is visible there). Use it as the smoke test
##    for the tree-order assertion.
##
## 4. Once a demonstrator exists, delete `get_container_scale()` /
##    `get_container_offset()` if still unused, or document their
##    consumer.
##
## 5. Add an "Adding a HUD widget" section to `AGENTS.md`. Cover: pick
##    the right tracker (`2D` vs `3D`), parent must be a `Control`, place
##    the tracker's host inside a HUD subtree that is a later sibling of
##    the `SubViewportContainer`, set `map` and `target` exports.
##
## 6. Optional follow-ups, scope-permitting:
##    - `add-hud-widget` Claude skill that scaffolds a new
##      `Control + WorldTracker` widget from a template.
##    - Off-screen-indicator helper (`clamp_to_viewport_edge`) once a
##      real consumer drives the API.
##    - 3D `test_follows_camera_pan` equivalent, plus tightening
##      `test_follows_target_movement` in the 3D suite to assert an
##      exact host delta (currently only checks `!=` and `is_finite()`).
##    - `@export var camera: Camera3D` on `WorldTracker3D` for
##      multi-camera HUDs.
##    - Setter on `WorldTracker*.target` that re-runs the topology
##      assertions if mid-life swaps become a real pattern.
##
