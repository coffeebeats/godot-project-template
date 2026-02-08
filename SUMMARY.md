# Save System Critical Analysis

## Context

This document captures a comprehensive evaluation of the project's save system against
industry best practices and battle-tested patterns from other game engines and libraries.
The analysis was performed by reviewing the full implementation across all layers:

- **System-level orchestrator:** `system/save/` (`saves.gd`, `slot.gd`, `writer.gd`,
  `saves.tscn`, `scope.tres`, `sync_target.tres`)
- **Addon library (reusable):** `addons/std/save/` (`data.gd`, `file.gd`, `summary.gd`)
- **Config writer chain:** `addons/std/thread/worker.gd`, `addons/std/file/writer.gd`,
  `addons/std/config/writer/writer.gd`, `addons/std/config/writer/binary.gd`
- **Config and schema:** `addons/std/config/config.gd`, `addons/std/config/schema/`
  (`item.gd`, `schema.gd`)
- **Settings system (slot metadata):** `addons/std/setting/` (`scope.gd`, `repository.gd`,
  `sync_target.gd`, `sync_target_file.gd`), `platform/profile/sync_target.gd`
- **Profile system:** `platform/platform.gd`, `platform/profile/` (`profile.gd`,
  `user_profile.gd`, `steam/profile.gd`, `unknown/profile.gd`)
- **Project-level data:** `project/save/data/` (`data.gd`, `example.gd`, `summary.gd`)
- **UI layer:** `project/save/menu.gd`, `project/save/slot_button.gd`,
  `project/main/load/loading.gd`, `project/main/menu/main_menu.gd`
- **Example usage:** `project/maps/example/scene.gd`
- **Supporting utilities:** `system/system.gd`, `addons/std/group/group.gd`, `feature.gd`,
  `addons/std/thread/result.gd`, `addons/std/file/path.gd`

The goal was to identify strengths, gaps, and concrete improvement opportunities by
comparing this implementation against patterns used by shipped games, major engines, and
well-regarded open-source libraries.

---

## Research: Industry Best Practices

### General Architecture

Across engines and studios, the dominant pattern is a **centralized save manager** that
mediates between game objects and persistent storage. Individual objects register what data
they need persisted; the manager orchestrates collection, serialization, and writing.

- **Unreal Engine** provides `USaveGame` with `UPROPERTY(SaveGame)`-marked fields and
  binary serialization via `FMemoryWriter`. An interface-based approach (`ISavableActor`)
  identifies which actors participate in saving. Tom Looman notes the built-in system has
  no version tracking, no level-streaming support, and no handling of runtime-spawned
  actors without custom extensions.
- **Unity** commonly uses ScriptableObjects as data containers with JSON (JsonUtility or
  Newtonsoft) or binary serialization. Hedberg Games documents a mature architecture with
  persistence scripts, a scene change watcher, a save slot manager, and a world state
  object backed by LiteDB/SQLite.
- **RPG Maker (MV/MZ)** uses Base64-encoded JSON with structured sections (system, screen,
  switches, variables, actors, party, map, player). Each save slot is fully self-contained.
- **Skyrim (.ess format)** uses a sophisticated single-file structure: magic string, header
  with version/screenshot/player stats, plugin list, file location table, global data
  tables, and **change forms** (only modified objects are stored as deltas from base game
  data). Compression is applied via zLib or LZ4 after the header.

### Serialization Formats

| Format | Size | Speed | Human-Readable | Best For |
|---|---|---|---|---|
| Binary (raw) | Smallest | Fastest | No | Performance-critical, anti-cheat |
| FlatBuffers | Very small | Near-zero parse | No | Zero-copy memory-mapped loading |
| Protobuf | Small | ~6x faster than JSON | No | Structured data with evolution |
| JSON | Large | Moderate | Yes | Debug, modding, interchange |
| SQLite | Variable | Moderate | Via tools | Complex relational data |

A number like `12345678` requires 8 bytes in JSON but only 4 bytes as a binary int32.
When factoring JSON structural overhead, binary can be 3-10x smaller.

**Practical recommendation from sources:** Use JSON during development for debuggability,
then consider binary/Protobuf/FlatBuffers for shipping. Or keep JSON and add compression.

### Data Integrity and Corruption Prevention

**Atomic writes (write-temp-rename)** is the single most important technique:

1. Write to a temporary file in the same directory.
2. `fsync()` the temporary file.
3. Rename (atomic on POSIX) the temp file over the target.
4. `fsync()` the parent directory.

This guarantees either the old or new save exists in its entirety -- never a half-written
file.

**Rolling backups** are the second line of defense: keep the N most recent saves
(`save.dat`, `save.dat.bak1`, `save.dat.bak2`). If the primary is corrupt, fall back to
the most recent backup.

**Checksums:** CRC32 is the most common lightweight choice. Some games use SHA-1 or MD5.
A Merkle tree approach can validate individual sections independently.

### Migration and Versioning

The universal best practice is to embed a **version number** at the start of every save
file. The most robust approach uses **sequential version-to-version migration**:

1. Store a version number with the save file.
2. On load, migrate from V(n) to V(n+1), then V(n+1) to V(n+2), until reaching the
   current version.
3. Each step handles: new fields (default), matching fields (copy), deprecated fields
   (migrate/transform), nested versioned structs (recurse).

This means you only write migration code for adjacent versions, and the chain handles
arbitrarily old saves. The Chickensoft serialization library (C#/Godot) implements this
with `[Version(n)]` attributes and `IOutdated.Upgrade()` methods.

**The Sims** handles missing content gracefully: objects from uninstalled expansions
convert to "failsafe objects" from the base game rather than crashing.

### Security

The most dangerous issue is **insecure deserialization**. Untitled Goose Game shipped
with a .NET `BinaryFormatter` vulnerability allowing arbitrary code execution from
crafted save files (disclosed October 2019, patched within 5 days).

Prevention rules:

- Never use unrestricted deserializers on untrusted data.
- Use serialization that only supports primitive data types.
- Validate and sanitize all deserialized values before use.
- For tamper resistance: HMAC with a secret key is significantly harder to forge than a
  plain checksum. For truly tamper-proof saves, server-side validation is the only
  reliable approach.

### Performance

- **Async I/O** is mandatory -- synchronous saves cause visible hitches, especially on
  consoles or with large files.
- **Dirty flag pattern** (Game Programming Patterns, Robert Nystrom): track which data
  changed since the last save; only process dirty data. Skyrim exemplifies this with
  change forms.
- **Compression:** Zstd level 1 is 3.4x faster than zlib level 1 while achieving better
  compression than zlib level 9 (Factorio forums). LZ4 is fastest for latency-sensitive
  cases.
- **Caching:** Maintain in-memory cache of most recently loaded save data to avoid
  redundant disk reads.

### Common Pitfalls

1. Treating the save system as an afterthought (design it early -- it touches everything).
2. Saving too much data (only save minimum state needed to reconstruct the game).
3. No version number in save files (any schema change breaks all existing saves).
4. Using unsafe deserializers (arbitrary code execution risk).
5. No corruption recovery (write-temp-rename + backups).
6. Not handling edge cases (disk full, permissions, file locking, clock manipulation).
7. Blocking the main thread (async I/O always).
8. Tight coupling between game logic and serialization (use a DTO/data transfer layer).
9. Not testing save/load roundtrips (dedicated save system tests are critical).

---

## Research: Godot-Specific Best Practices

### Official Recommendations

The Godot documentation recommends a "Persist" group pattern with JSON serialization:
tag nodes for saving via groups, iterate them to collect dictionaries, write as JSON
lines. This is intentionally basic -- the community has developed more sophisticated
patterns.

### Community-Preferred Approaches

| Scenario | Recommended Method |
|---|---|
| Simple player progress | `FileAccess.store_var()` |
| Complex nested save data | Resources (`.tres`/`.res`) |
| Game settings | `ConfigFile` |
| Web API integration | JSON |
| Maximum file size control | Custom binary |
| Large-scale relational data | SQLite (GDExtension) |

**Resources** are the community favorite for Godot 4: static typing, editor integration,
seamless Godot type support, nested composition, and minimal boilerplate. GDQuest
recommends `.tres` (text) for development and `.res` (binary) for release.

**`FileAccess.store_var()`** is recommended as the best balance of simplicity, performance,
and security. It is safe by default (no code execution). The `full_objects = true` variant
should be avoided on untrusted data.

### The Variant Deserialization Vulnerability (Godot Issue #80562)

`str_to_var()` and `ConfigFile`'s `load()`/`parse()` methods deserialize object instances,
and `_init()` methods execute immediately during parsing. This enables arbitrary code
execution from save files. The issue has been open since August 2023.

**Safe methods (no code execution):**

- `FileAccess.store_var()` / `FileAccess.get_var()` (without `full_objects = true`)
- `var_to_bytes()` / `bytes_to_var()` (without `_with_objects` variants)

**Unsafe methods (can execute code):**

- `ResourceLoader.load()` on `.tres` files
- `str_to_var()`
- `ConfigFile.load()` / `ConfigFile.parse()`
- `var_to_bytes_with_objects()` / `bytes_to_var_with_objects()`

### Notable Godot Save Libraries

- **Godot Safe Resource Loader** (179 stars): drop-in `ResourceLoader.load()` replacement
  that scans `.tres` for embedded GDScript before loading.
- **WCSafeResourceFormat**: whitelist-based solution; explicitly whitelist allowed resource
  types. Secure by default.
- **Save Made Easy**: Unity PlayerPrefs-inspired; encryption with OS unique ID.
- **Godot Improved JSON**: preserves exact Variant types through JSON; supports stable IDs
  for class/property renames.
- **Talo Game Services**: open-source cloud save backend with offline sync.
- **godot-sqlite**: GDExtension SQLite wrapper for complex relational data.

### Thread Safety in Godot

- `FileAccess` read/write is safe from background threads.
- `ResourceLoader` supports threaded loading via `load_threaded_request()`.
- Interacting with the active SceneTree is NOT thread-safe -- use `call_deferred()`.
- Container element access is fine across threads, but resizing requires a Mutex.

---

## Research Sources

### Industry / General

- [Unreal Engine SaveGame Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/saving-and-loading-your-game-in-unreal-engine)
- [Tom Looman - Unreal Engine C++ Save System](https://www.tomlooman.com/unreal-engine-cpp-save-system/)
- [Hedberg Games - Save Architecture Part 1](https://www.hedberggames.com/blog/save-architecture-part-1)
- [Game Programming Patterns - Dirty Flag (Robert Nystrom)](https://gameprogrammingpatterns.com/dirty-flag.html)
- [Macoy Madson - Binary Data Version Migration](https://macoy.me/blog/programming/BinaryVersionMigration)
- [Chickensoft - Serialization for C# Games](https://chickensoft.games/blog/serialization-for-csharp-games)
- [UESP Wiki - Skyrim Save File Format](https://en.uesp.net/wiki/Skyrim_Mod:Save_File_Format)
- [RPG Maker Save File Structure](https://saveeditor.top/blog/rpg-maker-save-file-structure/)
- [Gamedeveloper.com - Save the Saves (Cross-Platform)](https://www.gamedeveloper.com/programming/save-the-saves)
- [Wayline.io - Why Games Need Save System Architects](https://www.wayline.io/blog/games-need-save-system-architects)
- [Gabriel's Virtual Tavern - Serialization for Games](https://jorenjoestar.github.io/post/serialization_for_games/)
- [That One Game Dev - JSON vs Binary Serialization](https://thatonegamedev.com/cpp/json-vs-binary-serialization/)
- [Pulse Security - Untitled Goose Game Deserialization Vulnerability](https://pulsesecurity.co.nz/advisories/untitled-goose-game-deserialization)
- [GameMaker - How to Protect Your Save Files](https://gamemaker.io/en/blog/protect-your-savefiles)
- [Norman's Oven - Save Game Data Integrity Checking (Merkle Trees)](https://www.normansoven.com/post/save-game-data-integrity-checking-idea)
- [GameDev.net - How to Transfer Save Data Through Versions](https://www.gamedev.net/forums/topic/702903-how-to-transfer-save-data-through-versions/)
- [Factorio Forums - Zstd for Savegame Compression](https://forums.factorio.com/viewtopic.php?t=34273)
- [Google Play Games - Saved Games API](https://developers.google.com/games/services/common/concepts/savedgames)

### Godot-Specific

- [Godot Official - Saving Games](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [GDQuest - Saving and Loading with Resources](https://www.gdquest.com/library/save_game_godot4/)
- [GDQuest - Save and Load Cheat Sheet](https://www.gdquest.com/library/cheatsheet_save_systems/)
- [GDQuest - Choosing the Right Save Game Format](https://www.gdquest.com/tutorial/godot/best-practices/save-game-formats/)
- [Godot Forum - Complete Serialization Tutorial](https://forum.godotengine.org/t/how-to-load-and-save-things-with-godot-a-complete-tutorial-about-serialization/44515)
- [Variant Deserialization Vulnerability (Issue #80562)](https://github.com/godotengine/godot/issues/80562)
- [Proposal: Load Resources Without Scripts (#4925)](https://github.com/godotengine/godot-proposals/issues/4925)
- [Proposal: Safeguards for Untrusted Resources (#10968)](https://github.com/godotengine/godot-proposals/issues/10968)
- [Godot Safe Resource Loader](https://github.com/derkork/godot-safe-resource-loader)
- [godot-sqlite (GDExtension)](https://github.com/2shady4u/godot-sqlite)
- [Save Made Easy Plugin](https://github.com/AdamKormos/SaveMadeEasy)
- [Godot Improved JSON](https://github.com/neth392/godot-improved-json)
- [Talo Game Services for Godot](https://github.com/TaloDev/godot)
- [Godot Thread-Safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [Godot3To4FileConversion Addon](https://godotengine.org/asset-library/asset/2307)

---

## Implementation Architecture

### System Access Pattern

Game code accesses the save system via `Systems.saves()`, a static method on the `Systems`
utility class (`system/system.gd`). Rather than referencing the autoloaded `System` scene
node directly, `Systems` uses `StdGroup` -- a custom group system (`addons/std/group/
group.gd`) -- to look up the runtime instance by group ID.

This indirection exists as a **workaround for Godot issue #98865**: scripts that reference
autoloads directly encounter errors when loaded in background threads. `StdGroup` solves
this by maintaining a static `Dictionary` of groups outside the scene tree. Unlike Godot's
built-in node groups, `StdGroup` is not limited to `Node` instances, is globally accessible
without a scene tree reference, and emits `member_added`/`member_removed` signals.

The `Saves` node registers itself via `StdGroup.with_id(GROUP_SAVES_SHIM).add_member(self)`
in `_enter_tree()` and unregisters in `_exit_tree()`.

### Profile System

Save files are isolated per user via the profile system (`platform/profile/`). A
`UserProfile` is a `Resource` with a single `id: String` property. Profile creation is
**platform-conditional**:

- **Steam builds:** The `IfSteam` condition loader creates a profile with the player's
  Steam user ID (`Steam.getSteamID()` converted to string). Falls back to `"public"` if
  the Steam API is unavailable.
- **Editor/unknown builds:** The `IfGodot` condition loader creates a profile with
  `id = "public"`.

The profile ID is embedded in save paths:
`user://profiles/{profile.id}/saves/{slot_index}/save.dat`

This means a Steam user with ID `12345678` on slot 0 writes to
`user://profiles/12345678/saves/0/save.dat`, while editor builds use
`user://profiles/public/saves/0/save.dat`. Multiple Steam accounts on the same machine
get fully isolated save data.

### Layers

The save system spans six layers of inheritance for the writer chain, plus the data model
and orchestration layers:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Project Layer                                                      │
│  ProjectSaveData, ProjectSaveSummary, ProjectExampleData            │
│  Save menu UI, SlotButton, Loading screen                           │
├─────────────────────────────────────────────────────────────────────┤
│  System Layer (system/save/)                                        │
│  Saves (orchestrator), SaveSlot, SaveFileWriter                     │
│  StdSettingsRepository + StdSettingsScope (slot metadata sync)      │
├─────────────────────────────────────────────────────────────────────┤
│  Addon Layer (addons/std/)                                          │
│  Config, StdConfigSchema, StdConfigItem, StdSaveData, StdSaveFile,  │
│  StdConfigWriterBinary, StdConfigWriter, StdFileWriter,             │
│  StdThreadWorker, StdThreadWorkerResult                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Writer Inheritance Chain

The writer is a 6-level inheritance chain, each layer adding a distinct responsibility:

```
StdThreadWorker              Threading: semaphore-based background thread, graceful
│                            shutdown, single-job-at-a-time via mutex
├── StdFileWriter            File I/O: open/close/read/write/delete/move primitives,
│                            auto-creates directory trees
├── StdConfigWriter          Config bridging: load_config/store_config API, .tmp-based
│                            atomic write, abstract serialize/deserialize hooks
├── StdConfigWriterBinary    Integrity: MD5 checksumming, .tmp file crash recovery
│                            on read, checksum validation before accepting data
├── StdSaveFile              Save semantics: bridges StdSaveData <-> Config,
│                            async/sync load/store, Status enum, signals
└── SaveFileWriter           Project-specific: slot-aware path resolution via
                             profile system, cross-platform directory deletion
```

**Why 6 levels?** An alternative config writer exists -- `StdProjectSettingsConfigWriter`
-- which extends `StdConfigWriter` directly and uses `ConfigFile` text format for project
settings overrides. This writer is explicitly documented as insecure (referencing Godot
issue #80562), which demonstrates that the binary writer branch (`StdConfigWriterBinary`)
was a **deliberate security choice**, not just a default.

### Slot Metadata Persistence

The active slot index is persisted separately from save data using the settings system.
The `saves.tscn` scene includes a `StdSettingsRepository` node configured with:

- **scope:** `system/save/scope.tres` (a `StdSettingsScope` wrapping a `Config` instance)
- **sync_target:** `system/save/sync_target.tres` (a `StdSettingsSyncTargetProfileFile`
  writing to `saves.dat` under the user's profile directory)

When `saves.gd` calls `slot_scope.config.set_int(&"__slots__", &"active", index)`, the
Config emits its `changed` signal. The `StdSettingsRepository` connects to this signal and
starts a **debounce timer** (0.25s min, 0.75s max). When the timer fires, it writes the
Config to `user://profiles/{id}/saves.dat` via its own `StdConfigWriterBinary` instance.

This means slot metadata changes are batched efficiently -- rapid slot switches don't
trigger a write per change.

### Data Model

The data model uses property introspection to auto-discover serializable fields:

```
Resource
  │
  ├── StdConfigItem                    Single category of serializable properties.
  │     Introspects get_property_list() for exported script variables
  │     (PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_STORAGE).
  │     On store(), default/empty values are erased rather than written.
  │     Subclasses override _get_category() -> StringName.
  │     │
  │     ├── StdSaveSummary             Category "summary". Has time_last_saved: float.
  │     │     └── ProjectSaveSummary   Game-specific summary (currently empty).
  │     │
  │     └── ProjectExampleData         Category "example". Has count: int.
  │
  └── StdConfigSchema                  Composite of StdConfigItem instances.
        Iterates exported properties that are StdConfigItem instances.
        Enforces unique category names across all items.
        │
        └── StdSaveData                Schema + required summary: StdSaveSummary.
              └── ProjectSaveData      Concrete schema: summary + example.
```

### Data Flow (Store)

1. Game code calls `Systems.saves().store_save_data(data)`.
2. `saves.gd` deep-copies the data (`data.duplicate(true)`) to isolate it from the caller
   and stamps `summary.time_last_saved` with the current unix time.
3. `SaveFileWriter.store_save_data()` creates a transient `Config` object and calls
   `data.store(config)`.
4. `StdConfigSchema.store` iterates exported `StdConfigItem` properties; each serializes
   its exported fields into the `Config` as category/key/value entries. Default and empty
   values are erased rather than stored, minimizing file size.
5. `StdConfigWriter.store_config()` posts work to the background thread via `run()`.
6. On the background thread, `StdConfigWriterBinary._serialize_var()` locks `config._data`,
   calls `var_to_bytes()`, computes a 16-byte MD5 checksum, and prepends it to the bytes.
7. `StdConfigWriter._config_write_bytes()` writes to `{path}.tmp`, then renames to the
   final path via `StdFileWriter._file_move()`.
8. `StdThreadWorkerResult.done` signal fires via `call_deferred`; `StdSaveFile` emits
   `save_stored`. Back in `saves.gd`, slot status and summary are updated.

### Data Flow (Load)

The reverse: read file, validate checksum, `bytes_to_var()`, populate `Config`, call
`data.reset()` then `data.load(config)` to hydrate schema items.

On read, `StdConfigWriterBinary._config_read_bytes()` first checks for an orphaned `.tmp`
file. If found and its checksum validates, it is promoted to the main file path (handling
the case where a crash occurred after `.tmp` was written but before the rename).

### Save File Format

```
[16-byte MD5 checksum][var_to_bytes(Dictionary)]
```

The `Dictionary` keys are `StringName` category names; values are `Dictionary` instances
mapping `StringName` keys to typed values (bool, float, int, String, Vector2, or their
packed array equivalents).

### File Paths

- **Save data:** `user://profiles/{profile_id}/saves/{slot_index}/save.dat`
- **Slot metadata:** `user://profiles/{profile_id}/saves.dat`

### Slot Management

Fixed slot count (default 5, configured in `saves.tscn`). Each slot has a `SaveSlot`
(`RefCounted`) tracking `status` and `summary`, both emitting `changed` on reassignment.

Slot statuses mirror `StdSaveFile.Status`: `UNKNOWN` (0), `OK` (1), `EMPTY` (2),
`BROKEN` (3).

On startup (`_ready`), all slots are loaded synchronously via `load_save_data_sync` to
populate their status and summary. If a previously active slot was persisted and is `OK`,
it is automatically re-activated.

### Signal Flow

| Signal | Source | Emitted When |
|---|---|---|
| `slot_activated(index)` | `saves.gd` | Slot activated via `activate_slot()` |
| `slot_deactivated(index)` | `saves.gd` | Slot deactivated (switch or clear) |
| `slot_erased(index)` | `saves.gd` | Slot data directory deleted |
| `save_loaded(data, status)` | `StdSaveFile` | Load operation completes |
| `save_stored(data, status)` | `StdSaveFile` | Store operation completes |
| `changed` | `SaveSlot` | Status or summary property changes |
| `changed(category, key)` | `Config` | Any value mutated |

The UI layer connects to these: `SlotButton` listens to `slot_activated`,
`slot_deactivated`, `slot_erased`, and its slot's `changed` signal to refresh display.
The save menu handles slot selection and triggers scene transitions via `SceneHandle`.
The loading screen awaits `load_save_data`, then transitions to the game scene on success
or back to the main menu on failure.

### Developer Conveniences

The example scene (`project/maps/example/scene.gd`) uses `Feature.is_editor_build()`
(a static wrapper around `OS.has_feature("editor")`) to auto-activate slot 0 and load
save data when running in the editor, bypassing the normal menu flow. In exported builds,
if no save data is cached, it navigates back to the main menu instead.

---

## Evaluation: Strengths

### 1. Security: Deserialization Safety

The `Config` class is explicitly documented as "a secure replacement for `ConfigFile` that
doesn't load `Variant` types from disk," referencing Godot issue #80562. The system uses
`var_to_bytes()`/`bytes_to_var()` in safe mode (no object instantiation), avoiding the
entire class of arbitrary code execution vulnerabilities that affect `ResourceLoader.load()`
on `.tres` files, `str_to_var()`, and `ConfigFile.load()`.

This is a **deliberate architectural choice**, not a coincidence: the codebase also contains
`StdProjectSettingsConfigWriter`, which uses `ConfigFile` text format and is explicitly
documented as insecure. The binary writer branch was chosen specifically for save data
safety.

This puts the implementation ahead of the majority of Godot save systems, including the
official tutorial pattern and the popular Resource-based approach.

### 2. Atomic Writes with Crash Recovery

`StdConfigWriterBinary` implements write-temp-rename -- the industry-standard technique for
preventing corruption. Additionally, on read, orphaned `.tmp` files with valid checksums
are promoted to the final path, handling the edge case where a crash occurred after the
`.tmp` was written but before the rename completed. This matches patterns used by Skyrim,
Factorio, and other shipped titles.

**Platform caveat:** Godot's `FileAccess` does not expose `fsync()`. The industry-standard
atomic write pattern calls `fsync()` on the temporary file before renaming and on the
parent directory after. Without `fsync()`, the OS may reorder the write and rename
operations, meaning a power loss (not just an application crash) could theoretically still
produce corruption. This is a Godot platform limitation, not an implementation oversight.

### 3. Background Thread I/O

All file I/O runs on a dedicated background thread via `StdThreadWorker` with a
semaphore-based wake pattern. Thread lifecycle management is thorough: graceful shutdown in
`_exit_tree` (waits for in-progress work, then unblocks the thread for clean exit),
mutex-protected state, `call_deferred` for signal emission back to the main thread. The
system correctly prevents concurrent operations via `is_worker_in_progress()` checks.

### 4. Data Isolation via Deep Copy

`store_save_data` duplicates the caller's data (`data.duplicate(true)`) before writing.
`load_save_data` copies loaded data into the caller's resource via `StdConfigItem.copy()`.
This prevents the game from mutating data while a background write is in progress -- a
subtle race condition many implementations miss.

### 5. Type-Safe Config API

`Config` provides typed getters/setters (`get_bool`, `set_int`, `get_vector2`, etc.) that
return the caller's `default` if the stored value's type doesn't match. This prevents type
confusion at the application layer while keeping the internal representation flexible.

### 6. Composable Schema Design with Property Introspection

The `StdConfigSchema` + `StdConfigItem` pattern cleanly decomposes save data into
independent category-owning items. `StdConfigItem` auto-discovers serializable fields by
introspecting `get_property_list()` and filtering for `PROPERTY_USAGE_SCRIPT_VARIABLE |
PROPERTY_USAGE_STORAGE` flags. This means adding a new field is as simple as adding an
`@export var` -- no manual registration needed.

Default and empty values are erased during `store()` rather than written, which minimizes
file size and means loading an old save after adding a new field naturally yields the
field's default value.

This is conceptually similar to Unreal's `USaveGame` with `UPROPERTY(SaveGame)`, but with
better composability -- new save data sections are added by creating a `StdConfigItem`
subclass and exporting it on the schema.

### 7. In-Memory Caching

Loaded save data is cached in `saves.gd`, avoiding redundant disk reads. The cache is
correctly invalidated on slot changes (`activate_slot`, `clear_active_slot`) and load
failures (broken/unknown status). Cache hits trigger an immediate copy to the caller.

### 8. Profile-Isolated Save Paths

Save data is isolated per platform user via the profile system. Steam users get their
Steam ID as the profile identifier; editor builds use `"public"`. This provides automatic
multi-account support without any save system configuration.

### 9. Debounced Slot Metadata Sync

The active slot index is persisted via the settings system's debounce mechanism (0.25s min,
0.75s max). Rapid state changes are batched into a single write, avoiding unnecessary I/O.

### 10. Slot Deletion Safety

Desktop platforms use `OS.move_to_trash()` rather than permanent deletion, allowing
recovery from accidental slot erasure. Other platforms fall back to recursive directory
deletion.

---

## Evaluation: Gaps

### 1. No Save File Versioning (Critical)

Save files contain no version number. This is identified as a day-one requirement by
every industry source surveyed. Without it, any schema change between releases causes
existing saves to silently load with default values for changed fields -- data is lost,
not migrated.

The current forward-compatibility is partial: missing fields gracefully default because
`StdConfigItem.load` uses typed Config getters, and new `@export` fields auto-default.
But renamed categories, restructured data, removed fields, or type changes have no upgrade
path. A renamed category would appear as an entirely new (empty) data section while the
old category's data would be silently ignored.

**Recommendation:** Embed a version integer in the binary format (before or after the
checksum). On load, compare against the current expected version and run a migration chain.
This is cheap to add now and impossible to retrofit once players have save files in the
wild.

### 2. No Rolling Backups

Atomic writes prevent corruption during the write itself, but there is no protection
against writing bad data atomically. If a bug serializes corrupted game state, the single
save file is overwritten and the previous good save is gone.

**Recommendation:** Before renaming `.tmp` to `save.dat`, rename the existing `save.dat`
to `save.dat.bak`. On load, if `save.dat` is invalid, try `save.dat.bak`. This is
minimal code for significant safety.

### 3. No Compression

Save files are uncompressed `var_to_bytes()` output. Acceptable for small saves, but as
data grows, compression reduces both file size and write time (less data to flush).

**Recommendation:** Consider `PackedByteArray.compress()` with Zstd or gzip when save
sizes become non-trivial.

### 4. No Dirty Flag / Incremental Saves

Every save serializes the entire data set. The `Config.changed` signal already provides
the foundation for tracking which categories are dirty since the last save, but this
capability is not leveraged by the save system.

**Recommendation:** Low priority for small saves. Worth revisiting if save data grows
large or autosaves become frequent.

### 5. No Autosave Mechanism

The system provides `store_save_data` but no autosave orchestration (periodic, checkpoint,
or scene-transition triggers). This is arguably a game-level concern rather than a
framework gap.

### 6. MD5 Checksum Positioning

MD5 is adequate for corruption detection (its purpose here) but cryptographically broken.
For pure corruption detection, CRC32 would be faster (~3x on modern CPUs); for stronger
integrity guarantees, SHA-256 would be more robust. MD5 occupies an awkward middle ground
-- slower than CRC32 for corruption detection, weaker than SHA-256 for integrity. If
tamper resistance is ever needed, an upgrade to HMAC-SHA256 with an embedded key would be
required regardless.

That said, the 16-byte fixed checksum size is convenient for the binary format, and the
performance difference is negligible for small save files.

### 7. Constrained Type Palette (Deliberate Tradeoff)

`StdConfigItem` supports: `bool`, `float`, `int`, `String`, `Vector2`, `PackedInt64Array`,
`PackedStringArray`, `PackedVector2Array`. Types like `Color`, `Vector3`, `Quaternion`,
`Vector2i`/`Vector3i`, `Dictionary`, and nested arrays are not directly supported.

This is a **deliberate security/simplicity tradeoff**: the supported types are all
primitive or packed array types that `var_to_bytes()` handles safely without ambiguity.
Supporting `Dictionary` or `Array` would re-introduce type flexibility that could
undermine the type safety the system is designed around. The design supports extension
(add getter/setter pairs to `Config` and cases in `StdConfigItem`), but each new type
requires manual plumbing through multiple files.

For types like `Color` or `Vector3`, game code must use workarounds (e.g., encode Color
as a String or store Vector3 components as individual floats). Whether this is a gap or
a reasonable constraint depends on the game's data needs.

### 8. No Disk Space Guardrails

The write path does not check available disk space before writing. A full-disk scenario
produces a truncated `.tmp` file. The checksum prevents loading it, but the player's
previous valid save is preserved (the rename never occurs for a truncated `.tmp`). However,
there is no user-facing error or recovery flow -- the save silently fails. Console
certification often requires pre-checking available storage and notifying the user.

### 9. Synchronous Startup Slot Enumeration

`_load_save_slots()` uses `load_save_data_sync` for all slots (default 5) during
`_ready()`. Each call performs a full load -- reading the file, validating the checksum,
deserializing the dictionary, and populating the entire schema -- just to extract the
summary metadata. On slow media (SD cards, HDDs, network storage) this could cause a
visible startup hitch.

**Recommendation:** Consider either async enumeration or a lighter-weight summary-only
load path that reads just the summary category from the deserialized dictionary without
hydrating the full schema.

### 10. No Template-Level Tests

The `addons/std/` addon has test UID stubs (e.g., `binary_test.gd.uid`,
`schema_test.gd.uid`, `worker_test.gd.uid`) indicating tests exist in the addon's source
repository, but the template project has zero test files for system-level or project-level
save code.

**Recommendation:** At minimum, add roundtrip tests (create, store, load, assert equality),
corruption tests (tampered bytes yield `BROKEN`), and forward-compatibility tests (new
schema field loads from old file with defaults).

---

## Summary Scorecard

| Area | Rating | Notes |
|---|---|---|
| Security | Excellent | Deliberate choice of safe `var_to_bytes`; unsafe alternative exists and is documented as such |
| Atomic writes | Excellent | Write-temp-rename with `.tmp` crash recovery; limited by Godot lacking `fsync()` |
| Thread safety | Excellent | 6-layer writer chain with mutexes at each level; background I/O with `call_deferred` marshaling |
| Architecture | Excellent | Clean layering across addon/system/project; composable schema with property introspection |
| Profile isolation | Good | Steam and editor profiles; platform-conditional loading |
| Data integrity | Good | MD5 checksum catches corruption; no backup for logically-bad writes |
| Caching | Good | In-memory cache with proper invalidation on slot changes and failures |
| Type safety | Good | Typed getters prevent Variant confusion; constrained palette is a deliberate tradeoff |
| Slot metadata | Good | Debounced persistence via settings system; survives restarts |
| Versioning | Missing | No version number, no migration path |
| Backups | Missing | Single file, no rolling backups |
| Compression | Missing | Uncompressed binary |
| Autosave | Missing | No framework support (game-level concern) |
| Tests | Missing | No template-level test coverage |

---

## Priority Recommendations

1. **Add save file versioning.** Prepend a version integer to the binary format. This is
   cheap to add now and impossible to retrofit once save files exist in the wild.

2. **Add a single rolling backup.** Before overwriting `save.dat`, rename the existing
   file to `save.dat.bak`. Fall back to the backup on load failure.

3. **Add roundtrip tests.** Create, store, load, assert equality. Test corruption
   handling. Test forward compatibility (new field, old file).

4. **Consider compression and type expansion** as game data grows.

---

## Deep Research: Save File Versioning & Schema Migration

### The LBP Method (Media Molecule) -- Industry Gold Standard

The most celebrated approach in the industry, used across the entire LittleBigPlanet series
and Dreams. A level made in LittleBigPlanet 1 on PS3 in 2008 can be loaded in
LittleBigPlanet 3 on PS4 in 2017.

**How it works:** A single global version number is maintained. Both serialization and
deserialization are handled by the same `Serialize` function. Fields are conditionally
read/written based on version checks:

```cpp
if (serializer_version > 0)
    serialize(&data->v1_padding);

if (serializer_version > 1) {
    serialize(&data->position);
} else {
    data->position = {0.f, 0.f};  // Default for older versions
}
```

Data structures retain ALL historical members, and the serializer determines which to
process based on version comparisons. After LBP1, Media Molecule experimented with
**branchable version numbers** and **per-structure revisions** (which added complexity for
little benefit), and **self-descriptive serialization** (which reduced complexity but at too
high a cost in flexibility). They returned to the LBP Method -- "which could be coded in an
afternoon" -- and used it consistently for over a decade.

**Key takeaway:** Media Molecule explicitly rejected per-structure versioning after trying
it, finding it "increased complexity for comparatively little added capabilities."

**Source:** [How Media Molecule Does Serialization (Handmade Network)](https://yave.handmade.network/blogs/p/2723-how_media_molecule_does_serialization)

### Unreal Engine's FGuid-Based Custom Versioning

Unreal has the most sophisticated engine-level versioning in the industry, with multiple
layers:

1. **Engine-Level Versioning** via `EUnrealEngineObjectUE5Version` -- a global enum
   incremented whenever a built-in serializer changes.
2. **Object-Level Custom Versions** via FGuid -- the recommended approach for game-specific
   code. Each custom version contains an integer version number (implemented as an enum)
   and a GUID making it possible to have many parallel custom versions without conflicts.

This architecture specifically solves the problem of parallel development: "reordering
constants when merging will corrupt or invalidate Assets saved with those version numbers."
Each team/system maintains its own GUID, so version bumps in one branch never conflict with
another.

**Relevance to this project:** Overkill for a solo-dev indie game. The GUID-based approach
solves team collaboration problems that don't apply here.

**Sources:**
[Unreal Engine 5.7: Versioning of Assets and Packages](https://dev.epicgames.com/documentation/en-us/unreal-engine/versioning-of-assets-and-packages-in-unreal-engine),
[FArchive::UsingCustomVersion](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Core/Serialization/FArchive/UsingCustomVersion)

### Unity Ecosystem (No Built-in Standard)

Unity has no built-in save versioning system, leading to a rich ecosystem of third-party
solutions. The community consensus from Unity Discussions:

- Include a version number in the save file
- Implement migration functions upgrading old saves to current format
- Design data structures with default values for newly added fields
- The save data schema version does NOT have to match the build version

Notable libraries:

- **FullSerializer** (jacobdufault): First-class migration support using `PreviousModels`
  attribute and constructor-based chaining. Automatically routes
  `Model_v1 -> Model_v2(Model_v1) -> Model(Model_v2)`.
- **Chickensoft Serialization** (for Godot C#): Uses `[Version(N)]` attributes and
  `IOutdated` interface with `Upgrade()` methods, supporting dependency injection during
  migration.

**Sources:**
[Unity Discussions: Backward Compatible Save Files](https://discussions.unity.com/t/backward-compatible-save-files/779866),
[FullSerializer Versioning Wiki](https://github.com/jacobdufault/fullserializer/wiki/Versioning),
[Chickensoft: Serialization for C# Games](https://chickensoft.games/blog/serialization-for-csharp-games)

### Forward-Only Migration Chains (V1 -> V2 -> V3)

This is the dominant migration pattern across the industry. The clearest implementation is
**TypedMigrate.NET** (open-source, designed for Unity):

```csharp
// Each version is a separate class
public class GameStateV1 : GameStateBase { ... }
public class GameStateV2 : GameStateBase { ... }
public class GameState : GameStateBase { ... }  // Current

// Migration functions are statically typed
public static GameStateV3 ToV3(this GameStateV2 fromState) =>
    new() {
        playerProfile = new PlayerProfile {
            playerName = fromState.playerName,
            coins = fromState.coins,
        }
    };
```

This system is **serializer-agnostic** -- it even supports switching from JSON (v1-v2) to
MessagePack (v3+) mid-chain.

**Meta's official Unity save-game best practices** explicitly prescribe this pattern: "Have
routines that migrate your save data up to the next version. If your save data is older by
several versions, call each routine in succession until it is up-to-date (e.g.,
v4 -> v5 -> v6). This reduces the amount of logic you need to migrate between large version
gaps."

**Sources:**
[TypedMigrate.NET](https://github.com/dmitrybaltin/TypedMigrate.NET),
[Meta: Save Game Best Practices](https://developers.meta.com/horizon/documentation/unity/ps-save-game-best-practices/)

### The Tagged/Self-Describing Format Pattern

**Metaplay SDK** implements a production-grade tagged binary format inspired by Protocol
Buffers. Each serialized member gets a `[MetaMember(tagId)]` attribute. Rules:
- TagIds are unique within a class hierarchy
- Members can be safely added with previously unused tagIds
- Members can be safely removed -- the deserializer ignores unrecognized tags
- TagIds must **never** be reused
- Missing members get their default value from the empty-argument constructor

For more complex migrations, Metaplay provides registered schema migrations:

```csharp
[SupportedSchemaVersions(1, 3)]
public class PlayerModel : PlayerModelBase {
    [MigrateFromVersion(1)]
    void MigrateV1ToV2() { /* transform state */ }
    [MigrateFromVersion(2)]
    void MigrateV2ToV3() { /* transform state */ }
}
```

**Source:** [Metaplay: Deep Dive Data Serialization](https://docs.metaplay.io/game-logic/utilities/deep-dive-data-serialization.html)

### Notable Indie/Open-Source Approaches

**Factorio** maintains forward-only migration scripts. Each major version supports loading
saves from one or more previous formats. The game tells you if your save is too old.

**Dwarf Fortress** maintains backward compatibility within major releases but explicitly
breaks compatibility across major versions when "maintaining save compatibility was too hard
due to the number of things that changed."

**GearBlocks** (indie Unity game) started with BinaryReader/BinaryWriter (fast, compact, but
zero version tolerance), added messy version-checking code, then migrated to a key-value
JSON approach with BSON compression. The key-value format inherently handles missing/extra
fields.

### Key Design Decisions Summary

| Decision | Recommendation | Rationale |
|---|---|---|
| Version number location | Inside serialized data (as a `StdConfigItem`) | Schema-level concern, not format-level; reuses existing config item machinery |
| Whole save vs per-component | Single global version on `StdConfigSchema` | Media Molecule rejected per-structure after trying it; solo-dev doesn't need parallel versioning |
| Additive changes | Version bump, no migration resource needed | Golden file tests track all schema changes; missing migration in chain = additive (no-op) |
| Breaking changes | Version bump + `StdConfigSchemaMigration` resource | Renames, type changes, restructures need explicit migration code on the raw `Config` |
| Migration direction | Forward-only, gaps allowed | Industry consensus; gaps are safe because additive changes only add keys with defaults |
| Old schema scripts | Not kept | Migrations operate on raw Config dictionaries, not typed schema objects |

---

## Deep Research: Backup Strategies & Corruption Recovery

### How Shipped Games Handle Backups

| Game | Strategy | Backup Count | Details |
|---|---|---|---|
| **Elden Ring** (FromSoftware) | Ping-pong A/B | 1 `.bak` | `.sl2.bak` overwritten every save |
| **Hollow Knight** (Team Cherry) | Rolling rotation | 3 `.bak` files | `.bak1`, `.bak2`, `.bak3`; also creates backup on version change |
| **Stardew Valley** (ConcernedApe) | Previous-day backup | 1 `_old` | Current + previous day; SMAPI mod extends to 10 |
| **Hades** (Supergiant) | Paired backups | 1 `.bak` per file | Separate persistent/run state files, each with `.bak` |
| **Factorio** (Wube) | Ring buffer autosave | 3 (configurable) | `_autosave1.zip` through `_autosave3.zip`, user-configurable count and interval |
| **The Sims 4** (Maxis/EA) | Multi-point | Last 4 saves | Players can revert to earlier save points |
| **Skyrim** (Bethesda) | Unlimited manual saves | User-managed | No built-in rotation; community recommends capping at ~20 |

### The Microsoft GDK "Digest + Alternating Files" Pattern

The most formally documented pattern from a platform holder:

1. Maintain a small "digest" file that records which of two data files contains the last
   known-good save.
2. Always write new data to the **other** file (not the one the digest points to).
3. Only after the write succeeds, update the digest to point to the new file.
4. This ensures you always have one fully valid save to fall back to.

This solves interrupted writes but does **not** solve the "writing bad data" problem, since
both files will eventually contain bad data.

**Source:** [Microsoft GDK: XGameSave Best Practices](https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/system/overviews/game-save/game-saves-best-practice)

### Corruption Recovery: The Two Distinct Problems

The industry treats physical corruption and logical corruption as fundamentally different:

**Physical corruption** (interrupted writes, disk errors, power loss):
- Solved by atomic writes, checksums, and backup rotation.
- A CRC32/MD5 hash detects truncated or garbled files.
- One rolling backup covers this comprehensively.

**Logical corruption** (game writes valid-format but semantically wrong data):
- Much harder. A checksum will pass because the data was written correctly -- it's just
  wrong.
- As one GameDev.net discussion noted: "if your game is the source of the corruption, and
  that corruption gets computed into the checksum, then the checksum accomplishes nothing."

### Defenses Against Logical Corruption

No mainstream game fully solves the "writing bad data" problem in a general way. The
practical defenses are layered:

1. **Range validation on load** -- individual components validate their data when loaded.
   Out-of-range values reset to defaults rather than propagating. This is the most
   underrated defense.

2. **Tiered backup strategy (time-diversified backups)** -- inspired by the
   Grandfather-Father-Son (GFS) pattern from enterprise backup:
   - **"Son" backups** (frequent): Most recent 1-2 saves, rotated on every save. Protects
     against physical corruption and interrupted writes.
   - **"Father" backups** (periodic): A snapshot taken less frequently (every N saves or
     hours of play). Survives longer, less likely to all be overwritten before a bug is
     noticed.
   - **"Grandfather" backups** (milestone): Created on version upgrade or major game events.
     Never overwritten by normal rotation. Serves as "known good" recovery point.

3. **Pre-migration backup** -- when a version migration runs, preserve the pre-migration
   file. This is a "known good at the time" snapshot that can't be overwritten by normal
   saves.

4. **Validate-before-promote** -- after writing to temp file, re-read and validate it
   (parse, check ranges, verify structural integrity) before promoting. Catches
   serialization bugs but not in-memory state corruption.

5. **Thorough QA and testing of the save/load path** remains the primary defense.

### Console Certification Requirements

All major platform holders require graceful handling of corrupt saves:

- **Xbox (XR-052):** "Titles must not cause unintentional loss of user data." Games must
  properly handle sign-in/sign-out, suspend/resume, and device roaming.
- **Xbox (XR-003):** Content-updated versions must successfully load saves from non-updated
  versions.
- **Xbox (XR-037):** If a save cannot load due to missing DLC, the game must display a
  clear message.
- **PlayStation (TRC):** The game must not crash when encountering corrupted save data.
- **All platforms:** The game must never crash, hang, or silently lose data due to a storage
  failure.

**Sources:**
[Microsoft GDK: XGameSave Best Practices](https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/system/overviews/game-save/game-saves-best-practice),
[Microsoft GDK: Certification Requirements](https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/policies/console/certification-requirements),
[Stardew Valley Wiki: Saves](https://stardewvalleywiki.com/Saves),
[Hollow Knight: Recover a Lost Save File](https://steamcommunity.com/sharedfiles/filedetails/?id=2878788255),
[Elden Ring Save Data Backup Management](https://eldenring.wiki.fextralife.com/Save+Data+Backup+Management),
[Factorio Autosaves and Rolling Back](https://nodecraft.com/support/games/factorio/factorio-autosaves-and-rolling-back-to-an-autosave),
[Hades Save File Info (Speedrun.com)](https://www.speedrun.com/hades/guides/uj036)

---

## Deep Research: Slot Loading & Summary Strategies

### Separate Metadata Files vs. Header-in-File

The industry strongly favors **summary data embedded in the save file**, not separate files.

**Separate files have a real divergence problem.** The GameDev.net analysis warns: "if the
user manually moves or modifies the savefiles, the table of savegame-metadata will no longer
sync with the actual save files." Two files to manage atomically is strictly harder than one.
If the save writes but the metadata doesn't (or vice versa), they are out of sync.

**Google Play Games Services** is the exception that proves the rule: it stores metadata
separately because the platform needs to display save info without downloading potentially
large save data from the cloud. This is an appropriate design for cloud saves where download
cost is real -- not for local files.

**Pros of header-in-file:**
- Single source of truth -- metadata always matches the save data
- Simpler atomic write (one file to write-temp-rename)
- Simpler error recovery

**Cons of header-in-file:**
- Still requires opening and reading each file to enumerate slots
- Header format must be stable across versions

**Sources:**
[GameDev.net - Savegame Headers](https://www.gamedev.net/forums/topic/694597-savegame-headers/),
[Google Play Games - Saved Games API](https://developers.google.com/games/services/common/concepts/savedgames)

### The Skyrim Pattern: Fixed Header + Compressed Body

Skyrim (.ess) is the best-documented example: a fixed-layout header containing version,
screenshot, player name, level, location, and play time, followed by compressed game state.
The slot UI reads only the header. The game never needs to decompress the full save just to
display slot information.

### Partial Reads with Godot's var_to_bytes

Godot's `var_to_bytes()` format does not support partial reads. The entire `PackedByteArray`
must be deserialized to recover the `Dictionary`. There is no way to seek to a specific key
within the serialized blob without fully parsing it.

This means for the current architecture, the optimization is not at the file level but at
the schema hydration level: deserialize the full Dictionary from disk, but only populate the
summary `StdConfigItem`, skipping all other schema items.

### Async Slot Loading in Practice

Unreal Engine provides `AsyncLoadGameFromSlot` / `AsyncSaveGameToSlot` which run I/O on a
background thread and fire a delegate when complete. The documentation recommends this as
the preferred method: "running asynchronously prevents framerate hitches and avoids possible
certification issues on some platforms."

In practice, async slot enumeration looks like:
1. Show a loading indicator on the save slot UI
2. Fire async load requests for each slot in parallel
3. As each completes, update that slot's UI with the summary data
4. Enable slot interaction once all slots are loaded

For Godot specifically, `FileAccess` reads are safe from background threads, so the same
pattern works with the existing `StdThreadWorker` infrastructure.

### Practical Impact

For 4-5 slots with small save files, the performance difference between sync and async is
negligible on PC. It matters on Steam Deck SD cards and consoles. Async is the right
long-term choice regardless.

**Sources:**
[Unreal Engine Save Game Documentation](https://dev.epicgames.com/documentation/en-us/unreal-engine/saving-and-loading-your-game-in-unreal-engine),
[Unreal Engine Async Save/Load](https://dev.epicgames.com/documentation/en-us/unreal-engine/BlueprintAPI/SaveGame/AsyncSaveGametoSlot)

---

## Deep Research: CRC32 vs MD5 vs SHA-256

### Industry Standard

There is no single enforced standard. The choice varies by engine, platform, and context:

- **CRC32** is the most common for corruption detection in games and asset pipelines.
- **MD5** is used by some implementations (including the current codebase).
- **SHA-256** is rare for game saves but standard for security-critical applications.

### Comparison

| Algorithm | Output Size | Speed (100KB) | Collision Resistance | Best For |
|---|---|---|---|---|
| CRC32 | 4 bytes | ~22 μs (hardware-accelerated, potentially sub-μs) | 1 in 4.3 billion | Corruption detection |
| MD5 | 16 bytes | ~50-100 μs | Cryptographically broken since 2004 | Legacy; adequate for corruption |
| SHA-256 | 32 bytes | ~100-200 μs | No known practical attacks | Tamper detection |

All three are imperceptible for small files. The difference between them is swamped by file
I/O cost (typically milliseconds).

### What Engines Use

- **Unity:** CRC32 for AssetBundle integrity verification.
- **Unreal Engine:** CRC32 built into the engine for package verification. `USaveGame` does
  not add checksums by default.
- **Console SDKs:** Platform save data APIs typically handle integrity at the filesystem
  level (the platform manages checksums transparently).

### Recommendation

**CRC32 is the pragmatic choice** for corruption detection: smallest output (4 bytes vs 16),
fastest computation, and perfectly adequate for the job. MD5 is fine if already implemented.
SHA-256 would only be justified if tamper resistance becomes a requirement.

**For this project:** MD5 is already implemented and works. Switching to CRC32 saves 12
bytes per file with negligible performance gain. Not worth a breaking format change unless
one is already happening (e.g., for versioning). If making a breaking change anyway, CRC32
is the better fit.

**Sources:**
[Unity AssetBundle Integrity Verification](https://docs.unity3d.com/Manual/AssetBundles-Integrity.html),
[Unreal Wiki - CRC32](https://beyondunrealwiki.github.io/pages/crc32.html),
[Fastest CRC32 Implementation (komrad36)](https://github.com/komrad36/CRC),
[Fast CRC32 - Stephan Brumme](https://create.stephan-brumme.com/crc32/),
[Harvest Moon Save File Checksums](https://hmapl.wordpress.com/2019/11/23/save-file-checksums/),
[Game Dev FAQs - Hashing and Checksums for Save Integrity](https://gamedevfaqs.com/hashing-and-checksums-to-validate-game-save-integrity/)

---

## Deep Research: Compression & Encryption

### Compression in Games

Common among games with large save states:

- **Skyrim:** zLib or LZ4 compression on the game state portion (after uncompressed header).
- **Factorio:** Zip format; developers evaluated Zstd and found it "3.4x faster than zlib
  level 1 while achieving better compression than zlib level 9."
- **RPG Maker MV/MZ:** Base64-encoded JSON (not strictly compression).

**Algorithm comparison for game saves:**

| Algorithm | Compression Speed | Decompression Speed | Ratio | Best For |
|---|---|---|---|---|
| LZ4 | ~800 MB/s | ~4000 MB/s | Low | Latency-critical (real-time autosave) |
| Zstd (level 3) | ~500 MB/s | ~1500 MB/s | Good | Best all-around balance |
| gzip/Deflate | ~100 MB/s | ~400 MB/s | Good | Maximum compatibility |
| Zstd (level 19) | ~10 MB/s | ~1500 MB/s | Best | Archival, not real-time |

For save files under 100KB, compression is "nice to have" rather than essential.

### Godot's Built-in Compression Support

**`FileAccess.open_compressed()`** supports FastLZ, Deflate, Zstd, gzip, and brotli
(decompress only). However, it uses a custom block-based format with magic header "GCPF",
and has [known poor compression ratios](https://github.com/godotengine/godot/issues/77820)
(10-100x worse than equivalent command-line tools due to low compression level and per-block
overhead). Can only read files written by Godot's own format.

**`PackedByteArray.compress()` / `.decompress()`** is the better API for this use case:
byte-level compression with direct control, no custom format overhead. This is what the
current codebase should use if compression is added.

### Encryption in Games

**Rarely worthwhile for single-player indie games.** The consensus across multiple sources:

- The encryption key must ship in the game binary, making it extractable by any motivated
  reverse engineer.
- It prevents only casual tampering (hex editing), not determined tampering.
- It adds complexity, debug friction, and a failure mode (corrupted key = unrecoverable
  saves).
- It is actively hostile to modding communities.

**GameMaker's team recommends** HMAC for tamper detection rather than encryption for tamper
prevention: "Everyone can read what you're storing, it just stops them from editing it."

**When encryption IS appropriate:** Competitive multiplayer with local saves, online
leaderboards validated client-side, premium currency stored locally.

### Pipeline Architecture

The `read -> decompress -> decrypt -> deserialize` pipeline is a standard pattern. The order
matters: **compress before encrypt**, because encrypted data has maximum entropy and cannot
be compressed effectively.

```
Write: serialize -> compress -> encrypt -> checksum -> write
Read:  read -> validate checksum -> decrypt -> decompress -> deserialize
```

Godot has [an open proposal (#13842)](https://github.com/godotengine/godot-proposals/issues/13842)
requesting built-in support for compressing files before encryption because the current
`open_encrypted` API does not support this natively.

**Sources:**
[Factorio Forums - Zstd for Save Compression](https://forums.factorio.com/viewtopic.php?t=34273),
[Godot File Compression (bitbrain)](https://bitbra.in/blog/godot-file-compression/),
[Godot Compression Ratio Issue #77820](https://github.com/godotengine/godot/issues/77820),
[GameMaker - How to Protect Your Save Files](https://gamemaker.io/en/blog/protect-your-savefiles),
[Quora - Encrypting Save Files for Single Player](https://www.quora.com/What-is-the-point-of-encrypting-save-data-for-single-player-games),
[Asset Archive Format (Medium)](https://medium.com/@alexandrus18/creating-an-asset-archive-file-for-games-featuring-compression-checksum-hashes-and-encryption-c3c5199ac9d5),
[Compression Algorithm Comparison (DEV Community)](https://dev.to/konstantinas_mamonas/which-compression-saves-the-most-storage-gzip-snappy-lz4-zstd-1898)

---

## Deep Research: Disk Space Guardrails

### Godot API

**`DirAccess.get_space_left()`** returns available space in bytes on the filesystem
containing the opened directory. Returns 0 if the platform-specific query fails or is not
implemented.

```gdscript
var dir := DirAccess.open("user://")
var space_bytes: int = dir.get_space_left()
```

**Platform support:** Implemented on Windows, macOS, and Linux. Returns 0 on unsupported
platforms (some mobile/console targets).

### Known Godot Bugs

- [Issue #45354](https://github.com/godotengine/godot/issues/45354): Godot writes empty
  files when disk is full with no error displayed.
- [Issue #80026](https://github.com/godotengine/godot/issues/80026): Corrupted project files
  from full storage.
- The engine does not currently handle disk-full gracefully at the framework level.

**The existing atomic write pattern provides partial protection:** if `.tmp` is truncated
due to disk full, the rename never happens, so the previous valid `save.dat` is preserved.
But the player receives no notification that the save failed.

### Console Certification Requirements

- **Xbox (XR-074):** Titles must "gracefully handle errors" and "appropriately manage
  messaging the user."
- **Xbox (XR-133):** Titles must not exceed 1 GiB of total writes to persistent local
  storage in a 5-minute increment.
- **PlayStation (TRC):** Before saving, the application must check that storage is available
  and that there are enough free blocks. On-screen error messages must conform to
  platform-specific templates.
- **Nintendo (Lotcheck):** Save data is stored in System Memory (not microSD), which is
  limited.

### Practical Recommendation

For a small indie game: check `DirAccess.get_space_left()` before writing and surface a
user-facing error if space is insufficient. This is ~5 lines of code in the write path.
Low effort, handles the edge case, and satisfies console cert requirements if ever needed.

**Sources:**
[Godot DirAccess Documentation](https://docs.godotengine.org/en/stable/classes/class_diraccess.html),
[Godot Issue #45354 - Empty Files on Disk Full](https://github.com/godotengine/godot/issues/45354),
[Godot Issue #80026 - File Corruption on Full Storage](https://github.com/godotengine/godot/issues/80026),
[Xbox Certification Requirements](https://learn.microsoft.com/en-us/gaming/gdk/_content/gc/policies/console/certification-requirements),
[Console Compliance QA (Ixie Gaming)](https://www.ixiegaming.com/blog/console-compliance-testing/)

---

## Deep Research: Serialization Determinism

### The Problem

Godot's `var_to_bytes()` serializes Dictionary entries in **insertion order**, not sorted
order. This is confirmed by the engine source code (`core/io/marshalls.cpp`) -- the
serializer iterates the Dictionary's internal linked list with no sorting step.

Godot Dictionaries use Robin Hood hashing with a doubly-linked list that preserves insertion
order (similar to Python 3.7+ dicts). Both `Dictionary.hash()` and `var_to_bytes()` are
order-dependent. The official documentation states: "Dictionaries with the same entries but
in a different order will not have the same hash."

**Consequence:** If two code paths populate the same Config with the same data in different
insertion orders, `var_to_bytes()` produces different byte sequences. This breaks golden file
testing, where we need identical data to always produce identical bytes.

### Current State

In practice, the current codebase IS deterministic because:
- `get_property_list()` returns properties in source-code definition order (stable)
- `Config._data` is always populated fresh from an empty Dictionary through the same path
- `StdConfigSchema.store()` iterates items in `get_property_list()` order

But this is fragile -- reordering `@export` vars in source code silently changes serialized
bytes.

### Solution

**Recursively sort all Dictionary keys before serialization.** Godot 4.4+ provides
`Dictionary.sort()` (sorts by key in-place, added in PR #77213). For nested dicts (which
is what `Config._data` is), recursive sorting is needed.

This should be done in `StdConfigWriterBinary._serialize_var()` before calling
`var_to_bytes()`. On the deserialization side, no change is needed -- `bytes_to_var()`
reconstructs the Dictionary with keys in the serialized (sorted) order.

**Sources:**
[Godot Dictionary Documentation](https://docs.godotengine.org/en/stable/classes/class_dictionary.html),
[GitHub Issue #54648 - var_to_bytes insertion order](https://github.com/godotengine/godot/issues/54648),
[godot-proposals #9452 - Dictionary hash order-dependence](https://github.com/godotengine/godot-proposals/issues/9452),
[PR #77213 - Dictionary.sort()](https://github.com/godotengine/godot/pull/77213),
[Godot marshalls.cpp source](https://github.com/godotengine/godot/blob/master/core/io/marshalls.cpp)

---

## Analysis: Recommended Approach

Based on the deep research above, filtered for a small, solo-developer indie game context,
the following improvements are recommended. Items are ordered by priority.

### 1. Save Data Versioning (Must Do)

**Problem:** Any schema change after the first release silently drops player data. This is
impossible to retrofit once save files exist in the wild.

**Approach:** Versioning is a schema-level concern. The version lives inside the serialized
`Config` data as a `StdConfigItem` under the `__meta__` category. The `StdConfigWriterBinary`
layer does not need to know about save semantics -- it just checksums and writes bytes.
Migrations are declarative `Resource` objects attached to the schema.

**Design -- new components in `addons/std`:**

**`StdConfigSchemaMeta`** (new, `config/schema/meta.gd`):
An internal `StdConfigItem` for the `__meta__` category. Holds a single `version: int`
property. Managed privately by `StdConfigSchema` -- game code never sees it.

```gdscript
class_name StdConfigSchemaMeta extends StdConfigItem

@export var version: int = 0

func _get_category() -> StringName:
    return &"__meta__"
```

**`StdConfigSchemaMigration`** (new, `config/schema/migration.gd`):
A `Resource` with a `version_from: int` and a virtual `_migrate(config)` method. Each
migration transforms Config data from `version_from` toward the next version.

```gdscript
class_name StdConfigSchemaMigration extends Resource

## The schema version this migration upgrades from.
@export var version_from: int = 0

## Override to transform Config data from version_from toward the next version.
func _migrate(_config: Config) -> void:
    pass
```

**`StdConfigSchema`** (modified, `config/schema/schema.gd`):
Gains `version: int`, `migrations: Array[StdConfigSchemaMigration]`, and migration logic.

```gdscript
## The current version of this schema.
@export var version: int = 0

## Migration rules for upgrading from older schema versions. Only needed for
## breaking changes (renames, restructures, type changes). Additive changes
## (new fields with defaults) need no migration -- just bump the version.
## Gaps in the chain are allowed and treated as additive-only version bumps.
@export var migrations: Array[StdConfigSchemaMigration] = []

var _meta := StdConfigSchemaMeta.new()

func load(config: Config) -> void:
    _meta.load(config)
    var saved_version := _meta.version
    if saved_version < version:
        _apply_migrations(config, saved_version)
        _meta.version = version
        _meta.store(config)
    # ... existing item hydration (unchanged)

func store(config: Config) -> void:
    _meta.version = version
    _meta.store(config)
    # ... existing item store (unchanged)

func _apply_migrations(config: Config, from: int) -> void:
    var sorted := migrations.duplicate()
    sorted.sort_custom(func(a, b): return a.version_from < b.version_from)
    for migration in sorted:
        if migration.version_from >= from and migration.version_from < version:
            migration._migrate(config)
```

**Key design properties:**

- **Additive changes are free.** New `@export var` fields with defaults need no migration
  code. `StdConfigItem.load()` returns the default for missing keys. The developer only
  needs to bump `version` and regenerate the golden file.
- **Breaking changes require a migration resource.** The developer creates a script extending
  `StdConfigSchemaMigration`, overrides `_migrate()`, and adds it to the schema's
  `migrations` array.
- **Gaps in the migration chain are allowed.** A missing migration between versions N and
  N+1 is treated as an additive-only change (no transformation needed). The migration loop
  skips to the next available migration. This is safe because additive changes only add new
  keys with defaults -- old data is structurally identical to new data minus the new keys.
- **Migrations operate on raw Config.** Before any typed schema items are hydrated, the
  migration has full access to the Config dictionary. It can rename categories, move keys
  between categories, transform values, change types -- anything. This decouples migration
  from the current schema structure.
- **No old schema scripts needed.** The migration code knows what keys existed in old
  versions as facts encoded in the migration function. It doesn't need old typed classes.
  The golden binary file for each version IS the canonical representation of that version's
  data.
- **Validation:** The schema validates on first `load()` or `store()` -- check for duplicate
  `version_from` values and that no migration has `version_from >= version`. Validation
  should assert (fail loudly during development), not silently skip.

**Edge cases:**

- **Legacy saves (version 0 / missing `__meta__`):** Save files created before versioning
  is added will not have a `__meta__` category. `StdConfigSchemaMeta.load()` returns
  `version = 0` (the `@export` default) because the key is missing. The migration chain
  then applies all migrations from version 0. This means setting `version = 1` on the
  initial schema intentionally creates an upgrade path: version 0 is "pre-versioning save,"
  and the migration from 0 to 1 (if needed) handles the transition. For most projects, no
  migration from 0 to 1 is needed -- the gap is treated as additive.
- **Forward version (game downgrade):** If a save file has `version > schema.version`, the
  player has downgraded the game (e.g., rolled back from a beta). The schema should reject
  these saves and report an error status. The `load()` method checks for this case and
  returns early without hydrating, allowing `StdSaveFile` to report `BROKEN` (or a
  dedicated `INCOMPATIBLE` status if warranted). The save file is not modified -- the player
  can upgrade the game again to access it.
- **Migration errors:** If `_migrate()` throws an error or leaves Config in a bad state, the
  load path catches the error and reports `BROKEN` status. The pre-migration backup
  (`save.dat.v{N}.bak`) preserves the original file on disk. The schema does not hydrate
  from a Config that failed migration -- it returns the error to the caller.

**Why this approach:**

- Follows the LBP Method / Meta best practices (single global version, forward-only chain).
- The "pit of success" is deep: additive changes just work, breaking changes force you
  through the migration path.
- Declarative migration resources are idiomatic Godot -- same pattern as exported arrays of
  typed Resources (e.g., `Array[Texture2D]` on a SpriteFrames, Resources with virtual
  methods like `AnimationNode`).
- Versioning lives on `StdConfigSchema` (not `StdSaveData`), making it available to any
  schema-based system (settings, save data, etc.).

### 2. Deterministic Serialization (Must Do)

**Problem:** `var_to_bytes()` serializes Dictionaries in insertion order, not sorted order.
This makes golden file comparison unreliable if insertion order ever changes.

**Approach:** Recursively sort all Dictionary keys before serialization.

**Design:**

- `StdConfigWriterBinary._serialize_var()` recursively sorts `Config._data` (and all nested
  category dicts) by key before calling `var_to_bytes()`.
- Add static utility methods `StdConfigWriterBinary.to_bytes(config) -> PackedByteArray` and
  `StdConfigWriterBinary.from_bytes(bytes) -> Config` for use in tests without spinning up
  a writer instance or touching the filesystem.
- Deserialization needs no change -- `bytes_to_var()` reconstructs the Dictionary with keys
  in the serialized (sorted) order.

### 3. Single Rolling Backup + Pre-Migration Backup (Must Do)

**Problem:** If the game writes bad data, the single save file is overwritten and the
previous good save is gone.

**Approach:** One `.bak` file created before every save, plus a version-specific backup
created when a migration runs.

**Design:**

- `StdConfigWriter._config_write_bytes()`: before renaming `.tmp` to `save.dat`, rotate the
  existing `save.dat` to `save.dat.bak`.
- `StdConfigWriter._config_read_bytes()`: on load failure, automatically try `save.dat.bak`.
- `StdSaveFile`: when a version migration runs during load, preserve the pre-migration file
  as `save.dat.v{N}.bak` (where N is the old version). This "known good at the time"
  snapshot can never be overwritten by normal saves.
- After successful migration, immediately re-save to persist the migrated data. This
  happens in the load path, which is unusual, but is justified because the pre-migration
  `.bak` preserves the original and re-migration on every launch would be wasteful.

**Read path with `.bak` and `.tmp` (three-tier fallback):**

The existing `.tmp` crash recovery and the new `.bak` backup interact as follows:

1. Check for `.tmp` file -- if found and checksum is valid, promote to main file (existing
   crash recovery logic, unchanged).
2. Read main file (`save.dat`) -- validate checksum.
3. If main file fails (missing, truncated, bad checksum), try `.bak` (`save.dat.bak`) --
   validate checksum.
4. If `.bak` also fails → `BROKEN` status.

This extends the existing read path with one additional fallback tier. The `.tmp` recovery
runs first (it handles the "crash during write" case), then the main file is tried, then
the backup.

**Why one backup, not three:**

- One backup covers the overwhelmingly common case: the most recent save is bad due to a
  one-off bug, and the previous save is fine.
- The pre-migration backup covers the next most common case: a migration bug corrupts the
  upgraded data.
- A solo indie developer is better served by thorough save/load testing than by complex
  backup rotation.

### 4. Summary-Only Load Path + Async Slot Enumeration (Should Do)

**Problem:** Loading all 5 slots synchronously in `_ready()` performs full schema hydration
for each slot, just to extract the summary. This can hitch on slow media.

**Approach:** Add a lightweight summary-only load path and switch to async enumeration.

**Design:**

- `StdSaveFile` gains `load_summary(summary: StdSaveSummary) -> Status` which deserializes
  the full file (unavoidable with `var_to_bytes`) but only hydrates the summary item from
  the Config, skipping all other schema items.
- `_load_save_slots()` in `saves.gd` uses async loads with a completion counter. The save
  menu shows placeholder/loading states per slot.
- **No separate metadata file.** The summary stays embedded in the save data -- single
  source of truth, no divergence risk.

### 5. Disk Space Check (Should Do)

**Problem:** A full-disk scenario produces a truncated `.tmp` file. The player gets no
feedback that the save failed.

**Design:**

- Before writing, check `DirAccess.get_space_left()`.
- If space is below a threshold (e.g., 2x estimated save file size), return an error.
- The error propagates through the existing `StdThreadWorkerResult` and status system.

**Implementation cost:** ~5 lines of code.

### 6. Pipeline Hooks for Future Compression/Encryption (Nice to Have)

**Problem:** Adding compression or encryption later requires modifying the binary writer.

**Design:** Make `_serialize_var` / `_deserialize_var` extensible for optional byte
transforms without implementing them now. Save files for a small indie game will stay under
a few KB. `PackedByteArray.compress()` with Zstd is trivial to add later.

### Not Recommended

**Incremental saves / file sharding:** Over-engineering for small saves. Breaks the "one
file = one atomic unit = one checksum = one backup" invariant.

**CRC32 migration:** MD5 is already implemented and works. Not worth a breaking format
change for 12 bytes of savings.

**Multi-file dirty flag system:** Violates single-file atomicity. Cross-file consistency is
strictly harder.

**StdConfigProperty resource-based schema:** While architecturally appealing (schema as
declarative data, no reflection ambiguity), the ergonomic cost is too high. Game code loses
typed property access (`data.example.count` becomes `data.get_int("example", "count")`).
The current `@export`-based `StdConfigItem` is idiomatic Godot and gives developers typed
access. Deterministic serialization is solved by sorting dictionaries before writing, which
removes the ordering fragility without changing the schema definition model.

---

## Testing Strategy

### Principle: Two Distinct Test Layers

**`addons/std` unit tests** (no file I/O, byte arrays only):
- Test migration chain logic: construct Config in memory, apply migrations, assert state
- Test deterministic serialization: serialize Config → bytes → deserialize → assert equality
- Test byte-level round-trip: serialize → deserialize → reserialize → assert bytes match
- Use static utilities: `StdConfigWriterBinary.to_bytes(config)` and
  `StdConfigWriterBinary.from_bytes(bytes)`

**`godot-project-template` integration tests** (golden files on disk):
- Golden-file-based save system tests that exercise the full stack
- Located under `tests/`, with golden data under `tests/testdata/golden/`

### Golden File Tests

**Directory structure:**

```
tests/
  testdata/
    golden/
      saves/
        save_v1.dat           # golden binary for version 1
        save_v2.dat           # golden binary for version 2 (when it exists)
  save/
    test_save_roundtrip.gd    # canonical data + golden comparison + round-trip
    test_save_migration.gd    # load old goldens, migrate, verify
```

**`test_save_roundtrip.gd`** -- verifies the current schema version:

```gdscript
func test_current_version_round_trip() -> void:
    # Canonical test data defined inline -- this IS the spec
    var data := ProjectSaveData.new()
    data.example.count = 42
    # ... set all fields to known values

    # Serialize via production path
    var config := Config.new()
    data.store(config)
    var bytes := StdConfigWriterBinary.to_bytes(config)

    # Compare to golden
    var golden_path := "res://tests/testdata/golden/saves/save_v1.dat"
    var golden := FileAccess.get_file_as_bytes(golden_path)
    assert_eq(bytes, golden, "Schema changed -- regenerate golden or add migration")

    # Round-trip
    var loaded_config := StdConfigWriterBinary.from_bytes(bytes)
    var loaded_data := ProjectSaveData.new()
    loaded_data.load(loaded_config)
    assert_eq(loaded_data.example.count, 42)
```

If the schema changes without updating the version and golden file, this test fails and
tells the developer exactly what to do: either regenerate the golden (for additive changes)
or increment the version and write a migration (for breaking changes).

**`test_save_migration.gd`** -- verifies the full migration chain:

```gdscript
func test_migrate_v1_to_current() -> void:
    # Load old golden
    var bytes := FileAccess.get_file_as_bytes(
        "res://tests/testdata/golden/saves/save_v1.dat"
    )
    var config := StdConfigWriterBinary.from_bytes(bytes)

    # Hydrate through current schema (triggers migration chain)
    var data := ProjectSaveData.new()
    data.load(config)

    # Assert specific values survived migration
    assert_eq(data.example.count, 42)
```

For each historical version, a test method loads that version's golden file, runs the
migration chain to current, and verifies expected values. The golden binary file IS the
specification for that version -- no companion expected-state script needed.

### Golden File Generation

Golden files are generated by a standalone script that can be run headless:

```
tests/save/generate_golden.gd
```

Run via: `godot --headless --script tests/save/generate_golden.gd`

The script creates canonical test data (same values as the round-trip test), serializes it
via `StdConfigWriterBinary.to_bytes()`, and writes the result to the golden file path. No
Gut dependency needed for generation -- it's a plain GDScript with a `_ready()` that writes
the file and quits.

The canonical test data values are defined in BOTH `generate_golden.gd` and
`test_save_roundtrip.gd`. This intentional duplication ensures the golden file and the test
agree on expected values. If they diverge, the round-trip test fails.

### Golden File Workflow

1. **Initial setup:** Run `generate_golden.gd` to create golden file for v1. Commit it.
2. **Additive schema change:** Bump `version`, run `generate_golden.gd` to regenerate the
   golden file for the new version, commit it. Tests pass.
3. **Breaking schema change:** Bump `version`, create migration resource, run
   `generate_golden.gd` for the new version. The migration test verifies old goldens still
   load correctly. Commit the new golden file and migration resource.
4. **Old golden files are committed forever.** They are never regenerated -- they represent
   the exact bytes a player's save file would contain at that version.

---

## Updated Summary Scorecard

| Area | Current | Target | Notes |
|---|---|---|---|
| Security | Excellent | Excellent | No change needed |
| Atomic writes | Excellent | Excellent | No change needed |
| Thread safety | Excellent | Excellent | No change needed |
| Architecture | Excellent | Excellent | No change needed |
| Profile isolation | Good | Good | No change needed |
| Data integrity | Good | Good | MD5 is adequate; CRC32 optional if breaking format anyway |
| Caching | Good | Good | No change needed |
| Type safety | Good | Good | No change needed |
| Slot metadata | Good | Good | No change needed |
| **Versioning** | **Missing** | **Excellent** | Schema-level version + declarative migration resources |
| **Determinism** | **Fragile** | **Robust** | Recursive dict sorting before `var_to_bytes()` |
| **Backups** | **Missing** | **Good** | Single .bak + pre-migration backup |
| **Slot loading** | **Sync** | **Async** | Summary-only path + async enumeration |
| **Disk space** | **Missing** | **Good** | Pre-write check + user-facing error |
| **Tests** | **Missing** | **Good** | Golden file round-trip + migration chain tests |
| Compression | Missing | Deferred | Pipeline hooks only; implement when needed |
| Encryption | Missing | Not planned | Not appropriate for single-player indie |
| Autosave | Missing | Not planned | Game-level concern |

---

## Implementation Plan: `addons/std` Changes

| File | Change | Priority |
|---|---|---|
| `config/schema/meta.gd` | **New.** `StdConfigSchemaMeta` -- internal config item for `__meta__` category with `version: int` | Must Do |
| `config/schema/migration.gd` | **New.** `StdConfigSchemaMigration` -- Resource with `version_from: int` and virtual `_migrate(config)` | Must Do |
| `config/schema/schema.gd` | **Modified.** Add `version`, `migrations`, private `_meta`, migration chain in `load()`, version stamp in `store()` | Must Do |
| `config/writer/binary.gd` | **Modified.** Recursive dict sorting in `_serialize_var()`. Static `to_bytes()` / `from_bytes()` utilities | Must Do |
| `config/writer/writer.gd` | **Modified.** Rotate existing file to `.bak` before `.tmp` rename. Try `.bak` on read failure | Must Do |
| `save/file.gd` | **Modified.** Create `save.dat.v{N}.bak` pre-migration backup. Re-save after migration | Must Do |
| `save/file.gd` | **Modified.** Add `load_summary()` for lightweight slot enumeration | Should Do |

## Implementation Plan: `godot-project-template` Changes

| File | Change | Priority |
|---|---|---|
| `project/save/data/data.gd` | **Modified.** Set `version = 1`, empty `migrations` array | Must Do |
| `project/save/migrations/` | **New directory.** Future migration scripts go here | Must Do |
| `tests/save/generate_golden.gd` | **New.** Standalone script to generate golden files (`godot --headless --script`) | Must Do |
| `tests/save/test_save_roundtrip.gd` | **New.** Canonical data + golden comparison + round-trip | Must Do |
| `tests/save/test_save_migration.gd` | **New.** Load old goldens, migrate, verify values | Must Do |
| `tests/testdata/golden/saves/save_v1.dat` | **New.** Golden binary for version 1 | Must Do |

## Unchanged Components

- `StdConfigItem` -- keeps `@export` vars, typed access, reflection-based discovery
- `Config` -- unchanged
- `StdSaveData` -- inherits versioning from `StdConfigSchema`
- `StdThreadWorker`, `StdFileWriter` -- unchanged
- Game code access patterns -- `data.example.count` still works
- Profile system, slot management, signal flow -- unchanged
