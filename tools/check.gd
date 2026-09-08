##
## tools/check.gd
##
## Checks project files for problems that a normal boot or import will not surface, and
## repairs the ones that can be repaired.
##
## Every check is a `Rule` in the registry below: it declares the extensions and roots it
## covers, reports `Problem`s, and optionally fixes them. Rules share one `SourceFile` per
## file, so the text is read once and a scene is loaded and instantiated at most once no
## matter how many rules want it. Discovery derives from the registry, so a rule covering
## a new extension extends the scan by existing.
##
## NOTE: Rules live here rather than one per file because a parse error in a `preload`ed
## script leaves the engine with no main loop and exits 0, reporting success while
## checking nothing; a broken *entry* script exits 1. Should a rule outgrow this file,
## load it with `ResourceLoader.load` rather than `preload` and report an empty
## `get_instance_base_type()` as a problem, which keeps that failure loud.
##
## Usage:
##   godot --headless -s tools/check.gd                  # every rule, every file
##   godot --headless -s tools/check.gd -- a.gd b.tscn   # only the given files
##   godot --headless -s tools/check.gd -- --fix a.tscn  # repair, then re-check
##   godot --headless -s tools/check.gd -- --list        # print the rule registry
##
## Exits 0 when there is nothing to report and 1 when there is, whether that is a problem
## found or a repair applied.
##

extends SceneTree

# -- DEFINITIONS --------------------------------------------------------------------- #

## PROJECT_ROOTS are the directories holding project-authored scenes and resources.
const PROJECT_ROOTS: Array[String] = ["res://project", "res://system", "res://platform"]

## SCAN_ROOT is the fallback root for rules that declare none of their own.
const SCAN_ROOT: Array[String] = ["res://"]

## SCAN_EXCLUDE are directory names never scanned. Vendored addons are not ours to check,
## and the script templates hold `_BASE_` placeholders that intentionally do not compile.
const SCAN_EXCLUDE: Array[String] = ["addons", "script_templates"]


## Problem is one rule violation. It formats as `path:line: [rule] message` so a terminal
## and an editor can both link to it; `line` is 0 when the rule has no line to point at.
class Problem:
	extends RefCounted

	var path: String
	var line: int
	var rule: StringName
	var message: String

	func _init(
		file_path: String, file_line: int, rule_name: StringName, text: String
	) -> void:
		path = file_path
		line = file_line
		rule = rule_name
		message = text

	## format renders the problem as a single reportable line.
	func format() -> String:
		if line > 0:
			return "%s:%d: [%s] %s" % [path, line, rule, message]

		return "%s: [%s] %s" % [path, rule, message]


## SourceFile is the per-file context every rule shares. The text is read once and the
## resource loaded and instantiated at most once, so N rules cost one read and one load.
class SourceFile:
	extends RefCounted

	var path: String

	var _instance: Node = null
	var _instantiated: bool = false
	var _lines := PackedStringArray()
	var _loaded: bool = false
	var _read: bool = false
	var _resource: Resource = null
	var _text: String = ""

	func _init(file_path: String) -> void:
		path = file_path

	## text returns the file's contents verbatim, line endings included.
	func text() -> String:
		if not _read:
			_read = true

			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				_text = file.get_as_text()
				_lines = _text.replace("\r\n", "\n").split("\n")

		return _text

	## lines returns the contents split on newlines, with carriage returns normalized out.
	func lines() -> PackedStringArray:
		text()
		return _lines

	## resource returns the loaded resource, or null if it does not load.
	func resource() -> Resource:
		if not _loaded:
			_loaded = true
			_resource = ResourceLoader.load(
				path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
			)

		return _resource

	## instance returns the instantiated scene root, or null if this is not a scene or it
	## does not load.
	func instance() -> Node:
		if not _instantiated:
			_instantiated = true

			var scene := resource() as PackedScene
			if scene != null:
				_instance = scene.instantiate()

		return _instance

	## release frees the instantiated scene, if one was created.
	func release() -> void:
		if _instance != null:
			_instance.free()
			_instance = null

	## reset drops everything cached, so rules running after a fix see the new contents.
	func reset() -> void:
		release()

		_instantiated = false
		_lines = PackedStringArray()
		_loaded = false
		_read = false
		_resource = null
		_text = ""


## Rule is one check over one kind of file. Subclasses set `name`, `extensions` and
## `roots` in `_init` and override `check`; only rules that can repair what they find
## override `fix` and `fixable`.
class Rule:
	extends RefCounted

	var name: StringName = &""
	var extensions: Array[String] = []
	var roots: Array[String] = []

	## applies reports whether this rule covers the given file.
	func applies(path: String) -> bool:
		if path.get_extension() not in extensions:
			return false

		if roots.is_empty():
			return true

		for root in roots:
			if path.begins_with(root + "/"):
				return true

		return false

	## check reports every problem this rule finds in the file.
	func check(_file: SourceFile) -> Array[Problem]:
		return []

	## fix repairs what `check` reported and returns whether the file changed.
	func fix(_file: SourceFile) -> bool:
		return false

	## fixable reports whether this rule implements `fix`.
	func fixable() -> bool:
		return false


## CompileRule reports scripts that do not compile.
##
## NOTE: `godot --check-only` does not register autoload singletons, so it reports a false
## "Identifier not found" for most of this project; loading from inside a running
## `SceneTree` resolves them. A script that fails to parse still loads as a non-null
## object, so the load itself proves nothing — but a compiled script always resolves a
## native base type while a failed one reports an empty string. `reload()` looks like the
## cleaner signal and cannot be used: it errors on any script with live instances.
class CompileRule:
	extends Rule

	## self_path is this checker, which must not be re-loaded with CACHE_MODE_IGNORE_DEEP
	## from inside itself: re-loading the running script hangs the engine.
	var self_path: String = ""

	func _init() -> void:
		name = &"compile"
		extensions = ["gd"]

	func check(file: SourceFile) -> Array[Problem]:
		if file.path == self_path:
			return []

		var script: Script = ResourceLoader.load(
			file.path, "Script", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		)

		if script != null and script.get_instance_base_type() != &"":
			return []

		return [Problem.new(file.path, 0, name, "does not compile")]


## UidRule reports scenes and resources whose header carries no uid, and can assign one.
##
## NOTE: A file written outside the editor has no uid, so it can only be referenced by
## `res://` path, which Godot's move/rename fixup never rewrites inside string properties
## such as `StdScreen.attachment_scenes`. The engine never assigns one headless
## (`--import` writes `.uid` sidecars for scripts only). Ids derive from the path, so
## every machine assigns the same uid to the same file and the engine steers a derived id
## away from any uid already in the cache; a script process does not persist that cache,
## so `godot --import --headless` must follow a fix.
class UidRule:
	extends Rule

	func _init() -> void:
		name = &"uid"
		extensions = ["tscn", "tres"]
		roots = PROJECT_ROOTS

	func check(file: SourceFile) -> Array[Problem]:
		if _has_uid(file):
			return []

		var message := "no uid in header; re-run with --fix to assign one"
		return [Problem.new(file.path, 1, name, message)]

	func fix(file: SourceFile) -> bool:
		if _has_uid(file):
			return false

		# NOTE: The header line alone is rewritten; the rest of the file, line endings
		# included, is written back byte for byte.
		var text := file.text()
		var end := text.find("\n")
		var header := text if end < 0 else text.substr(0, end)
		var close := header.rfind("]")

		if not header.begins_with("[") or close < 0:
			push_error("%s: no resource header on the first line" % file.path)
			return false

		var uid := ResourceUID.id_to_text(ResourceUID.create_id_for_path(file.path))
		header = header.left(close) + ' uid="%s"' % uid + header.substr(close)

		var out := FileAccess.open(file.path, FileAccess.WRITE)
		if out == null:
			push_error("%s: cannot write" % file.path)
			return false

		out.store_string(header if end < 0 else header + text.substr(end))
		out.close()

		return true

	func fixable() -> bool:
		return true

	func _has_uid(file: SourceFile) -> bool:
		var lines := file.lines()
		return not lines.is_empty() and lines[0].contains(' uid="')


## PathRefRule reports references in a scene or resource that do not resolve, and
## `res://` strings that should be uid references.
##
## NOTE: The engine's move and rename fixup rewrites `ext_resource` headers and nothing
## else, so a path kept in a string property — `StdScreen.scene_path` and its attachment
## and dependency lists, `StdConditionLoader.scene` — points at nothing the moment its
## target moves, and does so silently: nothing reads the string until the screen is
## pushed or the condition allows. A `uid://` reference survives the move, because the id
## travels in the target's own header.
##
## NOTE: An `[ext_resource]` header is validated but never rewritten. The engine writes
## both a uid and a path there and prefers the uid, so the dependency is broken only when
## neither resolves; a stale path beside a good uid repairs itself on the next save.
## Checking it is not redundant with `load`: a scene whose dependency is missing still
## loads and still instantiates, dropping the node that needed it, so the only signal is
## an engine message on stderr that no exit code reflects.
##
## NOTE: Resolution reads the uid cache, which a script process does not rebuild, so a
## reference to a target created since the last import reports as unknown, and a `res://`
## string whose target is that new file is left unconverted. Both settle after the
## `godot --import --headless` the `uid` rule already asks for.
##
## NOTE: Paths in `project.godot` — the main scene, autoloads, the bus layout, the
## translation list — are the same kind of fragile string and are *not* covered. That
## file is not a scene or a resource, its entries are read by the engine before any of
## this runs, and several of them name files that carry no uid at all.
class PathRefRule:
	extends Rule

	## EXT_RESOURCE_PREFIX marks a dependency header: validated, never rewritten.
	const EXT_RESOURCE_PREFIX := "[ext_resource "

	## REFERENCE_PATTERN matches one quoted `res://` or `uid://` string literal.
	const REFERENCE_PATTERN := '"((?:res|uid)://[^"]*)"'

	## SELF_HEADER_PREFIXES mark the file's own header, whose uid belongs to `uid`.
	const SELF_HEADER_PREFIXES: Array[String] = ["[gd_resource ", "[gd_scene "]

	var _reference := RegEx.create_from_string(REFERENCE_PATTERN)

	func _init() -> void:
		name = &"path-ref"
		extensions = ["tscn", "tres"]
		roots = PROJECT_ROOTS

	func check(file: SourceFile) -> Array[Problem]:
		var problems: Array[Problem] = []
		var lines := file.lines()

		for i in lines.size():
			var line := lines[i]

			if _is_self_header(line):
				continue

			if line.begins_with(EXT_RESOURCE_PREFIX):
				var broken := _describe_dependency(line)
				if broken != "":
					problems.append(Problem.new(file.path, i + 1, name, broken))

				continue

			for found in _reference.search_all(line):
				var message := _describe(found.get_string(1))
				if message != "":
					problems.append(Problem.new(file.path, i + 1, name, message))

		return problems

	func fix(file: SourceFile) -> bool:
		# NOTE: The raw text is split on newlines alone, so a carriage return rides along
		# at the end of its line and the file is written back with its endings intact.
		var lines := file.text().split("\n")
		var changed := false

		for i in lines.size():
			var line: String = lines[i]
			if _is_engine_owned(line):
				continue

			var replaced := line

			for found in _reference.search_all(line):
				var reference := found.get_string(1)
				var uid := _preferred_uid(reference)
				if uid != "":
					replaced = replaced.replace('"%s"' % reference, '"%s"' % uid)

			if replaced != line:
				lines[i] = replaced
				changed = true

		if not changed:
			return false

		var out := FileAccess.open(file.path, FileAccess.WRITE)
		if out == null:
			push_error("%s: cannot write" % file.path)
			return false

		out.store_string("\n".join(lines))
		out.close()

		return true

	func fixable() -> bool:
		return true

	## _describe returns what is wrong with a reference, or an empty string if it is fine.
	func _describe(reference: String) -> String:
		if reference.begins_with("uid://"):
			return _describe_uid(reference)

		return _describe_path(reference)

	## _describe_dependency returns what is wrong with an `[ext_resource]` header, or an
	## empty string. One resolving reference on the line is enough, since the engine falls
	## back from the uid to the path.
	func _describe_dependency(line: String) -> String:
		var references := PackedStringArray()

		for found in _reference.search_all(line):
			var reference := found.get_string(1)
			if _resolves(reference):
				return ""

			references.append(reference)

		if references.is_empty():
			return ""

		return "dependency does not resolve: %s" % " ".join(references)

	## _describe_path returns what is wrong with a `res://` reference, or an empty string
	## if there is nothing wrong with it.
	func _describe_path(reference: String) -> String:
		if not _resolves(reference):
			return "path does not exist"

		var uid := _preferred_uid(reference)
		if uid == "":
			return ""

		return "reference this as %s; a res:// string is dropped on a move" % uid

	## _describe_uid returns what is wrong with a `uid://` reference, or an empty string
	## if there is nothing wrong with it.
	func _describe_uid(reference: String) -> String:
		var id := ResourceUID.text_to_id(reference)
		if id == ResourceUID.INVALID_ID or not ResourceUID.has_id(id):
			return "unknown uid; if its target is new, run `godot --import --headless`"

		var target := ResourceUID.get_id_path(id)
		if not FileAccess.file_exists(target):
			return "uid resolves to a missing file: %s" % target

		return ""

	## _is_engine_owned reports whether the line is a header this rule never rewrites.
	func _is_engine_owned(line: String) -> bool:
		return line.begins_with(EXT_RESOURCE_PREFIX) or _is_self_header(line)

	## _is_self_header reports whether the line is the file's own resource header.
	func _is_self_header(line: String) -> bool:
		for prefix in SELF_HEADER_PREFIXES:
			if line.begins_with(prefix):
				return true

		return false

	## _preferred_uid returns the uid a `res://` reference should use, or an empty string
	## when there is none to use — an unimported file, a directory, or a kind of file that
	## carries no uid.
	func _preferred_uid(reference: String) -> String:
		if not reference.begins_with("res://"):
			return ""

		var id := ResourceLoader.get_resource_uid(reference)
		if id == ResourceUID.INVALID_ID:
			return ""

		return ResourceUID.id_to_text(id)

	## _resolves reports whether a reference points at something that exists.
	func _resolves(reference: String) -> bool:
		if reference.begins_with("uid://"):
			return _describe_uid(reference) == ""

		return (
			FileAccess.file_exists(reference)
			or DirAccess.dir_exists_absolute(reference)
		)


## LoadRule reports files that do not parse or instantiate.
##
## NOTE: Loading is synchronous by design. Concurrent threaded loads of scenes with
## overlapping dependencies trip an upstream engine race, so a full project boot is not a
## reliable way to check whether a scene is well-formed.
class LoadRule:
	extends Rule

	func _init() -> void:
		name = &"load"
		extensions = ["tscn", "tres"]
		roots = PROJECT_ROOTS

	func check(file: SourceFile) -> Array[Problem]:
		if file.resource() == null:
			return [Problem.new(file.path, 0, name, "failed to load")]

		if file.path.get_extension() == "tres":
			return []

		if file.instance() == null:
			return [Problem.new(file.path, 0, name, "failed to instantiate")]

		return []


## ScriptOrderRule reports script-declared properties assigned ahead of `script =` in the
## same block, which Godot drops silently: the file loads clean while the values never
## apply. Properties belonging to the base type are exempt, since they apply regardless of
## the script and the editor writes them first.
##
## NOTE: `[resource]` and `[sub_resource]` blocks are covered as well as `[node]`. The
## pitfall is not node-specific, and this project hand-writes `.tres` files that carry a
## script and its exports.
class ScriptOrderRule:
	extends Rule

	## PROPERTY_PATTERN matches a top-level property assignment, skipping continuation
	## lines of a multi-line value.
	const PROPERTY_PATTERN := "^([A-Za-z_][A-Za-z0-9_/]*) = "

	## SCRIPT_VALUE_PATTERN captures the ext_resource id a `script =` line references.
	const SCRIPT_VALUE_PATTERN := '^script = ExtResource\\("([^"]+)"\\)'

	## SCRIPT_RESOURCE_PATTERN captures the path and id of a declared script resource.
	const SCRIPT_RESOURCE_PATTERN := 'type="Script".*path="([^"]+)".*id="([^"]+)"'

	var _property := RegEx.create_from_string(PROPERTY_PATTERN)
	var _script_resource := RegEx.create_from_string(SCRIPT_RESOURCE_PATTERN)
	var _script_value := RegEx.create_from_string(SCRIPT_VALUE_PATTERN)

	func _init() -> void:
		name = &"script-order"
		extensions = ["tscn", "tres"]
		roots = PROJECT_ROOTS

	func check(file: SourceFile) -> Array[Problem]:
		var problems: Array[Problem] = []
		var scripts := _script_resources(file)

		var in_block := false
		var preceding := PackedStringArray()
		var lines := file.lines()

		for i in lines.size():
			var line := lines[i]

			if line.begins_with("["):
				in_block = (
					line.begins_with("[node ")
					or line.begins_with("[resource")
					or line.begins_with("[sub_resource ")
				)
				preceding.clear()
				continue

			if not in_block:
				continue

			var found := _property.search(line)
			if found == null:
				continue

			var property := found.get_string(1)
			if property != "script":
				preceding.append(property)
				continue

			in_block = false

			if preceding.is_empty():
				continue

			var id := _script_value.search(line)
			if id == null:
				continue

			var exports := _script_exports(scripts.get(id.get_string(1), ""))
			var dropped := PackedStringArray()

			for candidate in preceding:
				if candidate in exports:
					dropped.append(candidate)

			if dropped.is_empty():
				continue

			var message := (
				"%s assigned before `script =`; silently dropped" % ", ".join(dropped)
			)
			problems.append(Problem.new(file.path, i + 1, name, message))

		return problems

	## _script_resources maps ext_resource ids to script paths for the given file.
	func _script_resources(file: SourceFile) -> Dictionary:
		var scripts := {}

		for line in file.lines():
			if not line.begins_with("[ext_resource "):
				continue

			var found := _script_resource.search(line)
			if found != null:
				scripts[found.get_string(2)] = found.get_string(1)

		return scripts

	## _script_exports returns the names of the properties a script itself declares.
	func _script_exports(script_path: String) -> PackedStringArray:
		var names := PackedStringArray()
		if script_path == "":
			return names

		var script: Script = ResourceLoader.load(script_path, "Script")
		if script == null:
			return names

		for property in script.get_script_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				names.append(property.name)

		return names


## NodePathRule reports NodePath exports that resolve to null on the instantiated scene.
## The usual cause is a path pointing at a node whose type does not match the export's
## declared type, which Godot resolves to null without complaint.
class NodePathRule:
	extends Rule

	func _init() -> void:
		name = &"nodepath"
		extensions = ["tscn"]
		roots = PROJECT_ROOTS

	func check(file: SourceFile) -> Array[Problem]:
		var problems: Array[Problem] = []

		var scene := file.resource() as PackedScene
		var root := file.instance()
		if scene == null or root == null:
			return problems

		var state := scene.get_state()

		for i in state.get_node_count():
			var node_path := state.get_node_path(i)
			var node := root.get_node_or_null(node_path)
			if node == null:
				continue

			for j in state.get_node_property_count(i):
				var value = state.get_node_property_value(i, j)
				if not (value is NodePath) or String(value) == "":
					continue

				var property := state.get_node_property_name(i, j)
				if node.get(property) != null:
					continue

				var message := (
					"node '%s' export `%s` points at '%s' but resolves to null"
					% [node_path, property, value]
				)
				problems.append(Problem.new(file.path, 0, name, message))

		return problems


# -- ENGINE METHODS (OVERRIDES) ------------------------------------------------------ #


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rules := _registry()

	if args.has("--list"):
		_list(rules)
		quit(0)
		return

	var should_fix := args.has("--fix")

	var paths: Array[String] = []
	var expanded := {}

	for arg in args:
		if arg.begins_with("--"):
			continue

		var path := _localize(arg)

		# A directory argument is expanded rather than checked, since a path no rule
		# applies to would otherwise be reported as clean.
		if DirAccess.dir_exists_absolute(path):
			_scan(path, _extensions(rules), expanded)
			continue

		paths.append(path)

	if not expanded.is_empty():
		var found: Array[String] = []
		found.append_array(expanded.keys())
		found.sort()
		paths.append_array(found)

	if paths.is_empty():
		paths = _discover(rules)

	var problems: Array[Problem] = []
	var fixed := 0

	for path in paths:
		var file := SourceFile.new(path)

		for rule in rules:
			if not rule.applies(path):
				continue

			var found := rule.check(file)

			if not found.is_empty() and should_fix and rule.fixable():
				if rule.fix(file):
					fixed += 1
					file.reset()
					found = rule.check(file)

			problems.append_array(found)

		file.release()

	for problem in problems:
		print("  ", problem.format())

	print("checked %d file(s), %d problem(s)" % [paths.size(), problems.size()])

	if fixed > 0:
		print(
			"fixed %d file(s); run `godot --import --headless` so they resolve" % fixed
		)

	# NOTE: A non-zero exit means "there is something the caller must read", whether that
	# is a problem found or a repair applied, so no caller has to parse this output. It
	# cannot say which: `SceneTree.quit()` collapses every non-zero code to 1 in `-s`
	# mode, printing the requested code to stderr while the process still returns 1.
	quit(1 if not problems.is_empty() or fixed > 0 else 0)


# -- PRIVATE METHODS ----------------------------------------------------------------- #


## _discover returns every file any rule covers, sorted and free of duplicates.
func _discover(rules: Array[Rule]) -> Array[String]:
	var seen := {}

	for rule in rules:
		for root in rule.roots if not rule.roots.is_empty() else SCAN_ROOT:
			_scan(root, rule.extensions, seen)

	var found: Array[String] = []
	found.append_array(seen.keys())
	found.sort()

	return found


## _extensions returns every extension covered by any rule, free of duplicates.
func _extensions(rules: Array[Rule]) -> Array[String]:
	var found: Array[String] = []

	for rule in rules:
		for extension in rule.extensions:
			if extension not in found:
				found.append(extension)

	return found


## _list prints the registry: what each rule is called, what it covers, and whether it
## can repair what it finds.
func _list(rules: Array[Rule]) -> void:
	for rule in rules:
		var roots := SCAN_ROOT if rule.roots.is_empty() else rule.roots
		print(
			(
				"%-13s %-12s %-45s %s"
				% [
					rule.name,
					" ".join(PackedStringArray(rule.extensions)),
					" ".join(PackedStringArray(roots)),
					"fixable" if rule.fixable() else "",
				]
			)
		)


## _localize turns a relative or native absolute command-line path into a `res://` path.
func _localize(path: String) -> String:
	if path.begins_with("res://"):
		return path.simplify_path()

	if path.is_absolute_path():
		return ProjectSettings.localize_path(path)

	return "res://" + path.simplify_path()


## _registry returns every rule, in the order they run. Adding a check means adding a
## `Rule` subclass above and one entry here; discovery, dispatch and `--list` all follow
## from this list. `uid` runs ahead of the rules that load the file, so a `--fix` run
## repairs the header before anything reads it.
func _registry() -> Array[Rule]:
	var compile := CompileRule.new()
	compile.self_path = get_script().resource_path

	var rules: Array[Rule] = []
	rules.append(compile)
	rules.append(UidRule.new())
	rules.append(PathRefRule.new())
	rules.append(LoadRule.new())
	rules.append(ScriptOrderRule.new())
	rules.append(NodePathRule.new())

	return rules


## _scan records every file under a directory carrying one of the given extensions.
##
## NOTE: Hidden directories are skipped outright, since `.git` alone holds ~11k files.
func _scan(dir_path: String, extensions: Array[String], seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()

	var entry := dir.get_next()
	while entry != "":
		var path := dir_path.path_join(entry)

		if dir.current_is_dir():
			if not entry.begins_with(".") and entry not in SCAN_EXCLUDE:
				_scan(path, extensions, seen)
		elif entry.get_extension() in extensions:
			seen[path] = true

		entry = dir.get_next()

	dir.list_dir_end()
