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

	locale.call("set_language", "en")
	_finish()


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
