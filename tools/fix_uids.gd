##
## tools/fix_uids.gd
##
## Lists scene and resource files with no `uid=` header, or assigns one to given files.
##
## A hand-written `.tscn` or `.tres` has no uid, so it can only be referenced by `res://`
## path, which Godot's move/rename fixup never rewrites inside string properties such as
## `StdScreen.attachment_scenes`. The engine never assigns one headless (`--import` writes
## `.uid` sidecars for scripts only), so this script does.
##
## Ids derive from the path (`ResourceUID.create_id_for_path`), so every machine assigns
## the same uid to the same file, and the engine steers a derived id away from any uid
## already in the project's cache. A script process does not persist that cache, so run
## `godot --import --headless` afterwards for a new uid to resolve.
##
## Usage:
##   godot --headless -s tools/fix_uids.gd              # list files missing a uid
##   godot --headless -s tools/fix_uids.gd -- a.tres    # assign uids to the given files
##

extends SceneTree

enum Result { SKIPPED, ASSIGNED, FAILED }

## SCAN_ROOTS hold the project-authored scenes and resources; files elsewhere are neither
## listed nor assigned.
const SCAN_ROOTS := ["res://project", "res://system", "res://platform"]
const EXTENSIONS := ["tscn", "tres"]


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()

	if paths.is_empty():
		quit(_list())
		return

	var assigned := 0
	var failed := 0
	for path in paths:
		match _assign(_localize(path)):
			Result.ASSIGNED:
				assigned += 1
			Result.FAILED:
				failed += 1

	print("checked %d file(s), assigned %d uid(s)" % [paths.size(), assigned])
	if assigned > 0:
		print("run `godot --import --headless` so the new uid(s) resolve")

	quit(1 if failed > 0 else 0)


## _list prints every scanned file that has no uid and returns the exit code.
func _list() -> int:
	var files := _find_files()
	var missing: Array[String] = []

	for path in files:
		if not _has_uid(path):
			missing.append(path)

	print("checked %d file(s), %d missing a uid" % [files.size(), missing.size()])
	for path in missing:
		print("  ", path)

	return 1 if missing else 0


## _assign gives the file a path-derived uid unless it has one or lies outside the
## scanned roots.
func _assign(path: String) -> Result:
	if not _in_scope(path):
		print("%s: skipped, not a .tscn/.tres under %s" % [path, ", ".join(SCAN_ROOTS)])
		return Result.SKIPPED

	if _has_uid(path):
		return Result.SKIPPED

	var uid := ResourceUID.id_to_text(ResourceUID.create_id_for_path(path))
	return Result.ASSIGNED if _write_uid(path, uid) else Result.FAILED


## _write_uid inserts the uid into the file's header line. Only that line changes; the
## rest of the file, line endings included, is written back byte for byte.
func _write_uid(path: String, uid: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("%s: cannot read" % path)
		return false

	var text := file.get_as_text()
	file.close()

	var end := text.find("\n")
	var header := text if end < 0 else text.substr(0, end)
	var close := header.rfind("]")
	if not header.begins_with("[") or close < 0:
		push_error("%s: no resource header on the first line" % path)
		return false

	header = header.left(close) + ' uid="%s"' % uid + header.substr(close)
	text = header if end < 0 else header + text.substr(end)

	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("%s: cannot write" % path)
		return false

	file.store_string(text)
	file.close()

	print("%s: %s" % [path, uid])
	return true


## _localize turns a relative or absolute command-line path into a `res://` path.
func _localize(path: String) -> String:
	if path.begins_with("res://"):
		return path.simplify_path()
	if path.is_absolute_path():
		return ProjectSettings.localize_path(path)
	return "res://" + path.simplify_path()


## _in_scope reports whether the path is a scene or resource under a scanned root.
func _in_scope(path: String) -> bool:
	if path.get_extension() not in EXTENSIONS:
		return false

	for root in SCAN_ROOTS:
		if path.begins_with(root + "/"):
			return true

	return false


## _has_uid reports whether the file's header line carries a uid.
func _has_uid(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	return file.get_line().contains(' uid="')


## _find_files returns every scene and resource under the scanned roots, sorted.
func _find_files() -> Array[String]:
	var found: Array[String] = []

	for root in SCAN_ROOTS:
		_scan(root, found)

	found.sort()
	return found


## _scan appends the scenes and resources under a directory, recursively.
func _scan(dir_path: String, found: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()

	var name := dir.get_next()
	while name != "":
		var path := dir_path.path_join(name)

		if dir.current_is_dir():
			_scan(path, found)
		elif name.get_extension() in EXTENSIONS:
			found.append(path)

		name = dir.get_next()

	dir.list_dir_end()
