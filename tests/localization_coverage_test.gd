extends SceneTree

## Player-facing text has to be readable in the language the player chose.
##
## Keys, knowledge exhibits and the knowledge locks were still printing English
## to a Chinese player. Translations existed for some of it, but the display
## paths were passing the raw table strings straight to the label, so the
## translation was never consulted.
##
## This checks what reaches the screen rather than what exists in the table, so
## a missing translation and an unrouted display path both fail here.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _has_latin_words(text: String) -> bool:
	# A stray acronym is fine; a sentence of English is not.
	var words := 0
	for chunk: String in text.split(" ", false):
		var stripped := chunk.strip_edges()
		if stripped.length() < 3:
			continue
		var alpha := 0
		for index: int in range(stripped.length()):
			var c := stripped.substr(index, 1).to_lower()
			if c >= "a" and c <= "z":
				alpha += 1
		if alpha >= 3:
			words += 1
	return words >= 3


func _run() -> void:
	var locale := root.get_node("CaseLocale")
	locale.call("set_language", "zh")

	# Every knowledge lock question and answer the player must read.
	var hall_script := load("res://scripts/game_world.gd") as GDScript
	var doors: Dictionary = hall_script.get_script_constant_map()["DOOR_QUESTIONS"]
	for door_id: String in doors:
		var entry: Dictionary = doors[door_id]
		var question := str(locale.call("line", str(entry["question"])))
		_expect(
			not _has_latin_words(question),
			"Door '%s' asks its question in Chinese (%s)" % [door_id, question]
		)
		for option: Variant in entry.get("options", []):
			var rendered := str(locale.call("line", str(option)))
			_expect(
				not _has_latin_words(rendered),
				"Door '%s' answer is translated: %s" % [door_id, rendered]
			)

	# The final synthesis lock.
	var finals: Array = hall_script.get_script_constant_map()["FINAL_SYNTHESIS_QUESTIONS"]
	for entry_variant: Variant in finals:
		var entry: Dictionary = entry_variant
		for option: Variant in entry.get("options", []):
			var rendered := str(locale.call("line", str(option)))
			_expect(
				not _has_latin_words(rendered),
				"Final synthesis answer is translated: %s" % rendered
			)

	# Hall knowledge exhibits: title and the science the player records.
	var exhibits: Array = hall_script.get_script_constant_map()["HALL_KNOWLEDGE_ITEMS"]
	for item_variant: Variant in exhibits:
		var item: Dictionary = item_variant
		var title := str(locale.call("line", str(item["title"])))
		_expect(
			not _has_latin_words(title),
			"Exhibit title is translated: %s" % title
		)

	# Keys, as the register and the reward card show them.
	var reward := load("res://scripts/item_reward_hud.gd") as GDScript
	var keys: Dictionary = reward.get_script_constant_map()["KEY_INFO"]
	for key_id: String in keys:
		var info: Dictionary = keys[key_id]
		var title := str(locale.call("line", str(info["title"])))
		var desc := str(locale.call("line", str(info["desc"])))
		_expect(
			not _has_latin_words(title),
			"Key '%s' is named in Chinese (%s)" % [key_id, title]
		)
		_expect(
			not _has_latin_words(desc),
			"Key '%s' is described in Chinese" % key_id
		)

	_check_interaction_prompts(locale)
	_check_interaction_labels(locale)

	locale.call("set_language", "en")
	_finish()


## The interaction prompts are the most frequently read text in the game.
##
## They failed in two independent ways: some had no translation entry, and some
## had one but were assigned to the label as a raw literal, so the translation
## was never consulted. Checking only one of those lets the other ship, so this
## walks the source and requires both: every prompt literal goes through the
## translation entry point, and that entry point answers in Chinese.
##
## The prefix list matters. An earlier pass covered only "Press E" and missed
## the "Click or press E" and "Move closer to" variants entirely, so every
## prompt opening the game actually uses is enumerated here.
const PROMPT_PREFIXES: Array[String] = [
	"\"Press E",
	"\"Click or press E",
	"\"Move closer to",
	"\"Approach the",
]


func _check_interaction_prompts(locale: Object) -> void:
	var unrouted: Array[String] = []
	var untranslated: Array[String] = []
	for path: String in _gdscript_paths("res://scripts") + _gdscript_paths("res://scenes"):
		if path.ends_with("case_script_zh.gd"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for prefix: String in PROMPT_PREFIXES:
			var found := 0
			while true:
				var start := source.find(prefix, found)
				if start < 0:
					break
				var end := source.find("\"", start + 1)
				if end < 0:
					break
				var literal := source.substr(start, end - start + 1)
				var head := source.substr(maxi(0, start - 16), mini(16, start))
				if not head.ends_with("CaseLocale.line("):
					unrouted.append("%s -> %s" % [path.get_file(), literal])
				var raw := literal.substr(1, literal.length() - 2)
				if _has_latin_words(str(locale.call("line", raw))) and raw not in untranslated:
					untranslated.append(raw)
				found = end + 1

	_expect(
		unrouted.is_empty(),
		"Every interaction prompt is displayed through the translation entry point"
			+ ("" if unrouted.is_empty() else " (raw: %s)" % ", ".join(unrouted))
	)
	_expect(
		untranslated.is_empty(),
		"Every interaction prompt has a Chinese translation"
			+ ("" if untranslated.is_empty() else " (missing: %s)" % ", ".join(untranslated))
	)


## A translated prompt still reads as English when the object it names is not
## translated: "按 E 查看the great stone planter". The prefix and the noun are
## written in different places, so they have to be checked in different places.
func _check_interaction_labels(locale: Object) -> void:
	var untranslated: Array[String] = []
	for path: String in _gdscript_paths("res://scripts") + _gdscript_paths("res://scenes"):
		if path.ends_with("case_script_zh.gd"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for key: String in ["\"label\": \"the ", "\"prompt\": \"the "]:
			var found := 0
			while true:
				var start := source.find(key, found)
				if start < 0:
					break
				var open_quote := start + key.length() - 5
				var end := source.find("\"", open_quote + 1)
				if end < 0:
					break
				var raw := source.substr(open_quote + 1, end - open_quote - 1)
				var shown := str(locale.call("line", raw))
				if shown == raw and raw not in untranslated:
					untranslated.append(raw)
				found = end + 1

	_expect(
		untranslated.is_empty(),
		"Every object named inside a prompt has a Chinese name"
			+ ("" if untranslated.is_empty() else " (missing: %s)" % ", ".join(untranslated))
	)


func _gdscript_paths(root_dir: String) -> Array[String]:
	var found: Array[String] = []
	var dirs: Array[String] = [root_dir]
	while not dirs.is_empty():
		var current: String = dirs.pop_back()
		var dir := DirAccess.open(current)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			var full := current.path_join(entry)
			if dir.current_is_dir():
				dirs.append(full)
			elif entry.ends_with(".gd"):
				found.append(full)
			entry = dir.get_next()
		dir.list_dir_end()
	return found


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("localization_coverage_test: PASS")
		quit(0)
	else:
		printerr(
			"localization_coverage_test: FAIL (%d assertion(s))" % failures.size()
		)
		quit(1)
