# Save System Overhaul — godot-plugin-std

## Context

The save system in `godot-plugin-std` needs hardening and new features before the
project template can adopt them. See `SUMMARY.md` for the full research and gap analysis
that motivated this work. This plan implements 6 improvements to the std library only.
Template migration (async slot enumeration, golden file tests, project config updates)
will follow in a separate effort.

Changes are ordered so each phase builds on the previous.

### Scope

All file paths below are relative to the `godot-plugin-std` repository root
(`../godot-plugin-std` from this template repository). No changes are made to
`godot-project-template` in this plan.

---

## Design Decisions

These decisions were made during planning and are not captured in `SUMMARY.md`.

### Keep MD5 (do not migrate to CRC32)

`SUMMARY.md` recommends CRC32 as the pragmatic choice for corruption detection. However,
Godot does not expose a built-in CRC32 for `PackedByteArray`. The options evaluated were:

1. **GDScript CRC32 implementation** — Pure GDScript is too slow for large buffers.
2. **Keep MD5** — Already implemented, adequate for corruption detection, and `HashingContext`
   supports it natively.
3. **SHA-256** — Overkill for corruption detection; no tamper resistance is needed.

**Decision: Keep MD5.** The 12-byte savings from CRC32 are not worth a custom implementation
or a GDExtension dependency.

### Compression mode byte (not a bit flag)

Rather than a single flag bit for "compressed yes/no", the first byte of the new format
encodes *which* Godot compression mode was used. This makes the format self-describing and
allows the compression algorithm to be changed without a format migration.

Encoding: `stored_byte = godot_mode + 1` for compressed data, `0x00` for uncompressed.
All Godot compression modes (FASTLZ=0, DEFLATE=1, ZSTD=2, GZIP=3, BROTLI=4) map to
values `0x01`–`0x05`, fitting in a single byte.

The writer's `compression_mode` export uses `-1` for "no compression" (default) and any
`FileAccess.COMPRESSION_*` constant (0–4) to enable compression.

### Two-level dictionary sorting (not recursive)

`SUMMARY.md` recommends recursive dictionary sorting. However, `Config._data` is always
exactly 2 levels deep: `{category_name: {key_name: value}}`. `StdConfigItem` does not
support Dictionary-typed properties — the supported types are `bool`, `float`, `int`,
`String`, `Vector2`, and their packed array equivalents. Therefore, recursive sorting is
unnecessary. The implementation sorts the outer dictionary keys and calls `.sort()` on
each inner dictionary.

### Backup rotation timing

Backup rotation happens **after writing `.tmp` but before renaming `.tmp` → target**:

1. New data is safely written to `.tmp` first, so it is protected even if rotation fails.
2. Rotation preserves the current main file as `.bak` before the rename overwrites it.
3. If rotation fails (disk full, permissions), the `.tmp` → target rename can still
   proceed — the write is not blocked by a backup failure.
4. If the rename itself fails, the `.tmp` remains for crash recovery (existing behavior).

---

## Phase 1: Deterministic Serialization

**Why**: `var_to_bytes()` serializes dictionaries in insertion order, not sorted order.
Sorting ensures golden file comparison works and bytes are reproducible.

### `config/writer/binary.gd`

1. **Add `_sort_config_data(data: Dictionary) -> Dictionary`** (private, static):
   - Duplicate the outer dictionary
   - Call `data.sort()` on the outer keys (Godot 4.4+)
   - For each value (which is an inner `Dictionary`), call `value.sort()`
   - Return the sorted copy (never mutates the input)
   - Only 2 levels deep — `StdConfigItem` properties are never Dictionaries

2. **Modify `_serialize_var()`**: call `_sort_config_data()` on the variant before
   `var_to_bytes()`

3. **Add static `_compute_checksum_static(bytes: PackedByteArray) -> PackedByteArray`**:
   - Same logic as `_compute_checksum` but static
   - Refactor instance `_compute_checksum` to delegate to it

4. **Add static `to_bytes(config: Config, compression_mode: int = -1) -> PackedByteArray`**:
   - Sort → `var_to_bytes` → optional compress → checksum → prepend header → return
   - Uses new format (Phase 2) with compression mode byte

5. **Add static `from_bytes(bytes: PackedByteArray) -> Config`**:
   - Extract compression mode + checksum → validate → decompress if needed →
     `bytes_to_var` → return Config or null
   - Falls back to legacy format (no compression byte) if new format checksum fails

### `config/writer/binary_test.gd`

Add tests (all using temp directory pattern from existing tests):
- `test_serialize_produces_deterministic_output_regardless_of_insertion_order` — two
  Configs with same data in different insertion order → same bytes
- `test_to_bytes_from_bytes_round_trip` — serialize → deserialize → assert values match
- `test_from_bytes_rejects_invalid_checksum` — tamper with a byte → assert null returned

---

## Phase 2: Compression Mode Byte + Optional Compression

**Why**: A 1-byte compression mode header makes the binary format self-describing. Without
it, changing compression settings silently breaks old files.

### Binary format (new)

```
[1-byte compression mode][16-byte MD5 checksum][payload]
```

Total header: 17 bytes. The checksum covers the payload only (after compression, if any).

### Compression mode encoding

| Stored byte | Meaning                                    |
|-------------|--------------------------------------------|
| `0x00`      | No compression (uncompressed data follows)  |
| `0x01`      | `FileAccess.COMPRESSION_FASTLZ` (Godot 0)  |
| `0x02`      | `FileAccess.COMPRESSION_DEFLATE` (Godot 1)  |
| `0x03`      | `FileAccess.COMPRESSION_ZSTD` (Godot 2)     |
| `0x04`      | `FileAccess.COMPRESSION_GZIP` (Godot 3)     |
| `0x05`      | `FileAccess.COMPRESSION_BROTLI` (Godot 4)   |

Mapping: `stored_byte = godot_mode + 1` for compressed, `0` for none.
The reader uses `stored_byte - 1` to get the Godot decompression mode.

### Legacy format (current)

```
[16-byte MD5 checksum][payload]
```

The reader must support both formats. Detection: try new format first (validate checksum
at bytes 1–17). If that fails, try legacy format (checksum at bytes 0–16).

### `config/writer/binary.gd`

1. Add constants:
   ```gdscript
   const COMPRESSION_MODE_BYTE_LENGTH := 1
   const HEADER_BYTE_LENGTH := COMPRESSION_MODE_BYTE_LENGTH + CHECKSUM_BYTE_LENGTH  # 17
   const COMPRESSION_MODE_NONE := 0x00
   ```

2. Add export: `@export var compression_mode: int = -1`
   - `-1` means no compression (default, backwards compatible)
   - Valid values: any `FileAccess.COMPRESSION_*` constant (0–4)

3. Modify `_serialize_var()`:
   - After sorting + `var_to_bytes`:
   - If `compression_mode >= 0`, compress the data bytes using the specified mode
   - Compute the stored compression byte: `compression_mode + 1` if compressing, `0` if not
   - Compute MD5 checksum of the (possibly compressed) data
   - Return: `[1-byte compression mode][16-byte MD5][data]`

4. Modify `_deserialize_var()`:
   - Try new format first:
     - Extract compression mode (byte 0), checksum (bytes 1–17), data (bytes 17+)
     - Validate MD5 of data portion
     - If compression mode > 0, decompress using
       `PackedByteArray.decompress_dynamic(-1, mode - 1)`
   - If new format checksum fails, fall back to legacy format via
     `_deserialize_var_legacy()`

5. Add `_deserialize_var_legacy()`: original `_deserialize_var` logic (checksum at bytes
   0–16, data at 16+, no compression)

6. Update `_config_read_bytes()`: update `.tmp` file checksum validation to handle both
   new and legacy formats

7. Update `to_bytes()` / `from_bytes()` statics to use the new format

### `config/writer/binary_test.gd`

Add tests (all using temp directory pattern):
- `test_reads_legacy_format_without_compression_byte` — manually write old-format
  bytes → load succeeds
- `test_round_trips_with_zstd_compression` — store with ZSTD → load → assert data matches
- `test_round_trips_with_each_compression_mode` — store with each of the 5 modes →
  load → verify
- `test_compressed_file_readable_regardless_of_writer_compression_setting` — write
  compressed → change writer's `compression_mode = -1` → load still works (format is
  self-describing)

---

## Phase 3: Disk Space Check

**Why**: Prevent silent save failures when disk is full.

### `config/writer/writer.gd`

Modify `_config_write_bytes()`: before opening `.tmp`, check
`DirAccess.get_space_left()`:

- Open `DirAccess` for the target directory
- `_config_write_bytes` receives the complete serialized blob from `_serialize_var`
  (header bytes + payload already included), so `data.size()` reflects the full on-disk
  file size
- Threshold: `data.size() * 2` — accounts for `.tmp` + target file coexisting during
  the atomic rename
- If `space_left > 0` (platform supports it) and `space_left < data.size() * 2`, return
  `ERR_FILE_CANT_WRITE`
- `space_left == 0` on some platforms means "unsupported" → skip check gracefully

Error propagates via existing `StdThreadWorkerResult` → `StdSaveFile._handle_result()` →
maps to `STATUS_UNKNOWN`.

---

## Phase 4: Rolling Backups

**Why**: If the game writes bad data atomically, the single save file is overwritten.
Rolling backups provide a fallback.

### `config/writer/writer.gd`

1. **Add export**: `@export var backup_count: int = 0`

2. **Add `_get_backup_filepath(index: int) -> String`**:
   - index 0 → `".bak"`, index 1 → `".bak2"`, index 2 → `".bak3"`, etc.

3. **Add `_rotate_backups(config_path: String) -> void`**:
   - If `backup_count <= 0`, return
   - Delete oldest `.bak{N}` if it exists
   - Shift each backup up: `.bak{N-1}` → `.bak{N}`, ..., `.bak` → `.bak2`
   - Copy current file → `.bak`
   - Best-effort: errors logged but don't fail the write
   - Uses `FilePath.make_project_path_absolute()` for all paths

4. **Modify `_config_write_bytes()`**: call `_rotate_backups(config_path)` **after writing
   `.tmp` but before renaming `.tmp` → target** (see Design Decisions above for rationale).

5. **Modify `_worker_impl()` LOAD branch** — backup fallback loop:
   ```
   Read + deserialize main file
   If fails AND backup_count > 0:
     For each backup index 0..backup_count-1:
       Read + deserialize backup file
       If success: use it, break
   If all fail:
     Return ERR_FILE_NOT_FOUND (no files exist) or ERR_INVALID_DATA (files corrupt)
   ```
   - This preserves the EMPTY vs BROKEN distinction
   - `.tmp` recovery (in `StdConfigWriterBinary._config_read_bytes`) runs for main file
     only

### `config/writer/writer_test.gd`

Add tests (all in temp directory — using
`path_test_dir = "user://".path_join("test-%d" % randi())` pattern):
- `test_creates_backup_on_write` — two stores → `.bak` file exists in temp dir
- `test_rotates_backups` — three stores with `backup_count = 2` → `.bak` and `.bak2`
  exist in temp dir
- `test_falls_back_to_backup_on_corrupted_main` — store valid, store again, corrupt main
  file in temp dir → load gets previous value from `.bak`

### `config/writer/binary_test.gd`

Add test (in temp directory):
- `test_binary_falls_back_to_backup_on_corrupted_main` — same pattern with checksummed
  binary format

---

## Phase 5: Schema Versioning + Migration

**Why**: Without a version number, any schema change silently drops data. This is
impossible to retrofit once save files exist.

### `config/schema/meta.gd` — NEW

```gdscript
class_name StdConfigSchemaMeta extends StdConfigItem

@export var version: int = 0

func _get_category() -> StringName:
    return &"__meta__"
```

Version is stored as a `StdConfigItem` in the `__meta__` category of the `Config`
dictionary. This reuses the existing property introspection machinery — no special binary
format changes needed.

### `config/schema/migration.gd` — NEW

```gdscript
class_name StdConfigSchemaMigration extends Resource

@export var version_from: int = 0

func _migrate(_config: Config) -> void:
    pass
```

Migrations operate on raw `Config` dictionaries, not typed schema objects. This means old
schema scripts do not need to be preserved. Subclasses override `_migrate()` to transform
data (rename categories, change key types, restructure, etc.).

### `config/schema/schema.gd`

1. Add dependencies:
   ```gdscript
   const SchemaMeta := preload("meta.gd")
   const SchemaMigration := preload("migration.gd")
   ```

2. Add exports:
   - `@export var version: int = 0`
   - `@export var migrations: Array[StdConfigSchemaMigration] = []`

3. Add private: `var _meta := StdConfigSchemaMeta.new()`

4. **Change `load()` return type from `void` to `bool`**:
   - Load `_meta` from config to get saved version
   - If `saved_version > version`: return `false` (forward version / game downgrade)
   - If `saved_version < version`: apply migration chain, stamp new version
   - Hydrate items (existing logic)
   - Return `true`

5. **Modify `store()`**: stamp `_meta.version = version` and `_meta.store(config)` before
   storing items

6. **Add `get_saved_version(config: Config) -> int`**: creates temp
   `StdConfigSchemaMeta`, loads from config, returns version

7. **Add `_apply_migrations(config, from_version)`**:
   - Sort migrations by `version_from`
   - Apply each where `version_from >= from_version AND version_from < version`
   - Gaps are allowed (treated as additive-only — no transformation needed)

8. **Add `_validate_migrations()`**: assert no duplicate `version_from`, assert none
   `>= version`

### `save/file.gd`

Modify `load_save_data()` and `load_save_data_sync()`:

1. After loading config from disk:
   - Call `data.get_saved_version(config)` to check version
   - If `saved_version < data.version`: create pre-migration backup via
     `_create_pre_migration_backup(saved_version)`

2. Call `data.load(config)` — now returns `bool`
   - If `false`: emit `save_loaded` with `STATUS_BROKEN`, return

3. If migration ran (`saved_version < data.version`):
   - Re-save migrated data: `data.store(config)` → `store_config(config)` → await/wait
   - This persists the migration so it doesn't re-run next load

4. **Add `_create_pre_migration_backup(saved_version: int)`**:
   - Copy current file to `{path}.v{N}.bak` (where N = saved_version)
   - Use `DirAccess.copy_absolute()` — preserves original file (fall back to read+write
     via `FileAccess.get_file_as_bytes()` → `FileAccess.open(WRITE)` →
     `store_buffer()` if unavailable)
   - Skip if backup already exists (idempotent)
   - Pre-migration backups are never rotated by rolling backups

### `config/schema/schema_test.gd`

Add inner class `ConfigSchemaMigrationTest extends StdConfigSchemaMigration` with
tracking (records whether `_migrate` was called and with what arguments).

Add tests:
- `test_store_stamps_version` — store schema v1 → config has `__meta__/version = 1`
- `test_load_applies_migrations` — config at v0, schema at v1, migration from 0 →
  migration called, version stamped
- `test_load_rejects_forward_version` — config at v2, schema at v1 → returns false
- `test_load_handles_legacy_saves` — config with data but no `__meta__` → loads as v0,
  upgrades work

---

## File Change Summary

### New Files

| File | Class |
|---|---|
| `config/schema/meta.gd` | `StdConfigSchemaMeta` |
| `config/schema/migration.gd` | `StdConfigSchemaMigration` |

### Modified Files

| File | Key Changes |
|---|---|
| `config/writer/binary.gd` | 2-level sorting, compression mode byte, legacy compat, static `to_bytes`/`from_bytes` |
| `config/writer/writer.gd` | Disk space check, backup rotation + fallback in `_worker_impl` |
| `config/schema/schema.gd` | `version` + `migrations` exports, migration chain in `load()`, version stamp in `store()`, `load()` returns `bool` |
| `save/file.gd` | Pre-migration backup, forward version detection, re-save after migration |
| `config/writer/binary_test.gd` | Determinism, compression modes, legacy compat, backup fallback tests |
| `config/writer/writer_test.gd` | Backup creation, rotation, and fallback tests |
| `config/schema/schema_test.gd` | Version stamping, migration chain, forward version, legacy save tests |

---

## Verification

1. **Run existing tests first**: Ensure no regressions in `binary_test.gd`,
   `writer_test.gd`, `schema_test.gd`.

2. **Run new tests**: All new tests should pass. Key things to verify:
   - Deterministic output: same data in different insertion order → identical bytes
   - Compression round-trips: each of the 5 Godot compression modes produces loadable
     data
   - Legacy compat: files written without the compression byte still load
   - Backup fallback: corrupted main file → data recovered from `.bak`
   - Schema versioning: migrations run in order, forward version rejected, legacy saves
     (no `__meta__`) load as v0

3. **Manual verification**: Write a save, check file size with vs. without ZSTD. Corrupt
   the main file, verify `.bak` fallback works.

---

## Risks

1. **`StdConfigSchema.load()` return type change** (`void` → `bool`): Breaking API.
   GDScript doesn't require consuming return values, so existing callers that ignore the
   return won't error. Only `StdSaveFile` callers are updated to check the return.

2. **Legacy format compat**: `_deserialize_var` tries new format first, falls back to
   legacy. Detection: validate checksum at new position (bytes 1–17); if it fails, try
   legacy position (bytes 0–16). False positive is astronomically unlikely (would require
   a random byte 0 that happens to make the shifted checksum validate).

3. **`DirAccess.copy_absolute()`**: Verify this static method exists in the target Godot
   version. If not, fall back to `FileAccess.get_file_as_bytes()` →
   `FileAccess.open(WRITE)` → `store_buffer()`.
