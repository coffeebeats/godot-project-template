##
## tools/fix_uids.gd
##
## Finds scene and resource files with no `uid=` header and assigns one on request.
##
## A `.tscn` or `.tres` written by hand has no uid, so it can only be referenced by
## `res://` path, which Godot's move/rename fixup never rewrites inside string properties
## such as `StdScreen.attachment_scenes`. Nothing headless assigns one: `--import` writes
## `.uid` sidecars for scripts only, and the editor's "Upgrade Project Files" has no
## command-line equivalent. This script fills the gap.
##
## Ids derive from the file path (`ResourceUID.create_id_for_path`), so every machine
## assigns the same uid to the same file. A script process does not persist the uid
## cache, so run `godot --import --headless` afterwards for a new uid to resolve.
##
## Usage:
##   godot --headless -s tools/fix_uids.gd              # list files missing a uid
##   godot --headless -s tools/fix_uids.gd -- a.tres    # assign uids to the given files
##

extends SceneTree

const SCAN_ROOTS := ["res://project", "res://system", "res://platform"]
const EXTENSIONS := ["tscn", "tres"]


func _initialize() -> void:
	var paths := OS.get_cmdline_user_args()

	if paths.is_empty():
		quit(_list())
		return

	var assigned := 0
	for path in paths:
		var normalized := path if path.begins_with("res://") else "res://" + path
		if _assign(normalized):
			assigned += 1

	print("checked %d file(s), assigned %d uid(s)" % [paths.size(), assigned])
	if assigned > 0:
		print("run `godot --import --headless` so the new uid(s) resolve")

	quit(0)


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


## _assign writes a path-derived uid into the file's header line. Only that line changes;
## the rest of the file, line endings included, is written back byte for byte.
func _assign(path: String) -> bool:
	if _has_uid(path):
		return false

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

	var uid := ResourceUID.id_to_text(ResourceUID.create_id_for_path(path))
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


func _has_uid(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	return file.get_line().contains(' uid="')


func _find_files() -> Array[String]:
	var found: Array[String] = []

	for root in SCAN_ROOTS:
		_scan(root, found)

	found.sort()
	return found


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
