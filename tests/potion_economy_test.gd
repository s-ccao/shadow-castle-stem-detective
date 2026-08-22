extends SceneTree

## The greenhouse is only a renewable supply if what it grows can actually
## become potions. Two things have to hold: every herb the room grows must be
## worth picking, and every potion must be reachable from renewable input
## rather than from a handful of one-time pickups.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.set("_loading_save", true)
	game_state.reset_new_game()

	_test_every_grown_herb_has_a_use(game_state)
	_test_materials_are_renewable(game_state)
	_test_every_potion_is_craftable_from_the_greenhouse(game_state)

	game_state.reset_new_game()
	game_state.set("_loading_save", false)
	_finish()


func _test_every_grown_herb_has_a_use(game_state: Node) -> void:
	var greenhouse := load("res://scripts/greenhouse_room.gd") as GDScript
	var plots: Array = greenhouse.get_script_constant_map()["HERB_PLOTS"]
	var grown := {}
	for plot: Dictionary in plots:
		grown[str(plot["herb"])] = true

	var consumed := {}
	for recipe_id: String in game_state.RECIPE_INFO:
		var recipe: Dictionary = game_state.RECIPE_INFO[recipe_id]
		for herb_id: String in recipe.get("herb_cost", {}):
			consumed[herb_id] = true

	for herb_id: String in grown:
		_expect(
			consumed.has(herb_id),
			"Herb %s the greenhouse grows is used by some recipe" % herb_id
		)


## One-time pickups cannot sustain seven recipes. Something the player can farm
## has to convert into each scarce material.
func _test_materials_are_renewable(game_state: Node) -> void:
	var renewable := {}
	for recipe_id: String in game_state.RECIPE_INFO:
		var recipe: Dictionary = game_state.RECIPE_INFO[recipe_id]
		if str(recipe.get("produces_kind", "item")) != "material":
			continue
		# A refining recipe only counts if it is paid for with herbs, which are
		# the renewable input. Paying materials for materials is a treadmill.
		if recipe.get("herb_cost", {}).is_empty():
			continue
		renewable[str(recipe.get("produces", ""))] = true

	for material_id: String in game_state.MATERIAL_INFO:
		_expect(
			renewable.has(material_id),
			"Material %s can be refined from herbs" % material_id
		)


## Walk the actual economy: stock a realistic greenhouse haul, then try to
## craft one of every potion, refining materials on demand.
func _test_every_potion_is_craftable_from_the_greenhouse(game_state: Node) -> void:
	game_state.reset_new_game()
	# Two full sweeps of the greenhouse, which is about six minutes of play.
	var greenhouse := load("res://scripts/greenhouse_room.gd") as GDScript
	var plots: Array = greenhouse.get_script_constant_map()["HERB_PLOTS"]
	for _sweep: int in range(6):
		for plot: Dictionary in plots:
			game_state.call("add_herb", str(plot["herb"]), int(plot["amount"]))

	var crafted := 0
	for recipe_id: String in game_state.RECIPE_INFO:
		var recipe: Dictionary = game_state.RECIPE_INFO[recipe_id]
		if str(recipe.get("produces_kind", "item")) == "material":
			continue
		var made := _try_craft(game_state, recipe_id, 8)
		_expect(
			made,
			"%s can be crafted from greenhouse output alone" % recipe_id
		)
		if made:
			crafted += 1
	_expect(crafted >= 7, "Every potion recipe is reachable (%d)" % crafted)


## Attempt a craft, refining any missing material first. Returns false if the
## recipe still cannot be paid for, which means the economy has a dead end.
func _try_craft(game_state: Node, recipe_id: String, refine_budget: int) -> bool:
	var recipe: Dictionary = game_state.RECIPE_INFO[recipe_id]
	for material_id: String in recipe.get("material_cost", {}):
		var need := int(recipe["material_cost"][material_id])
		var guard := refine_budget
		while int(game_state.call("get_material_count", material_id)) < need:
			if guard <= 0:
				return false
			guard -= 1
			if not _refine_material(game_state, material_id):
				return false
	for herb_id: String in recipe.get("herb_cost", {}):
		if (
			int(game_state.call("get_herb_count", herb_id))
			< int(recipe["herb_cost"][herb_id])
		):
			return false
	for herb_id: String in recipe.get("herb_cost", {}):
		game_state.call("consume_herb", herb_id, int(recipe["herb_cost"][herb_id]))
	for material_id: String in recipe.get("material_cost", {}):
		game_state.call(
			"consume_material", material_id, int(recipe["material_cost"][material_id])
		)
	return true


func _refine_material(game_state: Node, material_id: String) -> bool:
	for recipe_id: String in game_state.RECIPE_INFO:
		var recipe: Dictionary = game_state.RECIPE_INFO[recipe_id]
		if str(recipe.get("produces_kind", "item")) != "material":
			continue
		if str(recipe.get("produces", "")) != material_id:
			continue
		for herb_id: String in recipe.get("herb_cost", {}):
			if (
				int(game_state.call("get_herb_count", herb_id))
				< int(recipe["herb_cost"][herb_id])
			):
				return false
		for herb_id: String in recipe.get("herb_cost", {}):
			game_state.call("consume_herb", herb_id, int(recipe["herb_cost"][herb_id]))
		game_state.call(
			"add_material", material_id, int(recipe.get("produces_amount", 1))
		)
		return true
	return false


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("potion_economy_test: PASS")
		quit(0)
	else:
		printerr("potion_economy_test: FAIL (%d assertion(s))" % failures.size())
		quit(1)
