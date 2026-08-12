extends Node2D

## Library — 图书馆/奥术档案馆（用户提供 9a790883 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/library_archive.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "library"
const RETURN_SPAWN_ID: String = "library_door"

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const INTERACTION_CONTACT_MARGIN: float = 4.0
const LEGACY_CONTACT_RADIUS: float = 20.0
const RECIPE_INTERACT_RADIUS: float = 80.0
const INTERACTION_FRONT_OFFSET: Vector2 = Vector2(0.0, 28.0)
const PROP_NODE_PATHS: Dictionary = {
	"storage_cabinet": NodePath("Worldsort/StorageCabinet"),
	"tall_cabinet_a": NodePath("Worldsort/TallCabinetA"),
	"tall_cabinet_b": NodePath("Worldsort/TallCabinetB"),
	"chest_cabinet": NodePath("Worldsort/ChestCabinet"),
	"writing_desk": NodePath("Worldsort/WritingDesk"),
	"upper_panel_cabinet": NodePath("Worldsort/UpperPanelCabinet"),
	"upper_shelf_cabinet": NodePath("Worldsort/UpperShelfCabinet"),
	"upper_chest_cabinet": NodePath("Worldsort/UpperChestCabinet"),
	"upper_drawer_cabinet": NodePath("Worldsort/UpperDrawerCabinet"),
	"upper_apothecary_cabinet": NodePath("Worldsort/UpperApothecaryCabinet"),
	"lower_panel_a": NodePath("Worldsort/LowerPanelA"),
	"lower_panel_b": NodePath("Worldsort/LowerPanelB"),
	"lower_storage": NodePath("Worldsort/LowerStorage"),
	"lower_globe_desk": NodePath("Worldsort/LowerGlobeDesk"),
	"lower_study_table": NodePath("Worldsort/LowerStudyTable"),
	"topleft_chest_a": NodePath("Worldsort/TopLeftChestA"),
	"topleft_cabinet_b": NodePath("Worldsort/TopLeftCabinetB"),
	"topleft_cabinet_c": NodePath("Worldsort/TopLeftCabinetC"),
	"topleft_cabinet_d": NodePath("Worldsort/TopLeftCabinetD"),
	"topleft_tall_case": NodePath("Worldsort/TopLeftTallCase")
}
const PROP_OCCLUSION_PATHS: Array[NodePath] = [
	NodePath("Worldsort/StorageCabinet"),
	NodePath("Worldsort/TallCabinetA"),
	NodePath("Worldsort/TallCabinetB"),
	NodePath("Worldsort/ChestCabinet"),
	NodePath("Worldsort/WritingDesk"),
	NodePath("Worldsort/UpperPanelCabinet"),
	NodePath("Worldsort/UpperShelfCabinet"),
	NodePath("Worldsort/UpperChestCabinet"),
	NodePath("Worldsort/UpperDrawerCabinet"),
	NodePath("Worldsort/UpperApothecaryCabinet"),
	NodePath("Worldsort/LowerPanelA"),
	NodePath("Worldsort/LowerPanelB"),
	NodePath("Worldsort/LowerStorage"),
	NodePath("Worldsort/LowerGlobeDesk"),
	NodePath("Worldsort/LowerStudyTable"),
	NodePath("Worldsort/TopLeftChestA"),
	NodePath("Worldsort/TopLeftCabinetB"),
	NodePath("Worldsort/TopLeftCabinetC"),
	NodePath("Worldsort/TopLeftCabinetD"),
	NodePath("Worldsort/TopLeftTallCase")
]
const PROP_FRONT_Z: int = -20
const PROP_BACK_Z: int = 20

const GAMEPLAY_CAMERA_ZOOM: Vector2 = Vector2(1.35, 1.35)
const DEVELOPER_CAMERA_ZOOM: Vector2 = Vector2(0.90, 0.90)

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "recipe_swift_scroll",
		"label": "the bottle-scroll",
		"position": Vector2(1060.0, 320.0),
		"interaction_radius": RECIPE_INTERACT_RADIUS,
		"message": (
			"A rolled scroll tucked between alchemical volumes. "
			+ "It holds the recipe for the Swiftness Potion."
		)
	},
	{
		"name": "recipe_vision_scroll",
		"label": "the lens-scroll",
		"position": Vector2(300.0, 480.0),
		"interaction_radius": RECIPE_INTERACT_RADIUS,
		"message": (
			"A scroll hidden inside an old atlas. "
			+ "It holds the recipe for the Vision Potion."
		)
	},
	{
		"name": "research_desk",
		"label": "the research desk",
		"position": Vector2(724.0, 560.0),
		"message": (
			"An open illuminated book lies on the desk beside a magnifying "
			+ "glass. The pages are dense with notes and diagrams."
		)
	},
	{
		"name": "rgb_red_filter",
		"label": "the red filter",
		"position": Vector2(664.0, 650.0),
		"message": "A red filter rests in the small optical stand. The Library Knowledge note says the three light colors must be applied in sequence."
	},
	{
		"name": "rgb_green_filter",
		"label": "the green filter",
		"position": Vector2(724.0, 650.0),
		"message": "A green filter rests in the small optical stand."
	},
	{
		"name": "rgb_blue_filter",
		"label": "the blue filter",
		"position": Vector2(784.0, 650.0),
		"message": "A blue filter rests in the small optical stand."
	},
	{
		"name": "chained_cabinet",
		"label": "the chained cabinet",
		"position": Vector2(250.0, 170.0),
		"message": (
			"A heavy cabinet bound by a chain and a gold padlock. "
			+ "Whatever it guards, it was meant to stay sealed."
		)
	},
	{
		"name": "drawer_bank",
		"label": "the drawer bank",
		"position": Vector2(1180.0, 260.0),
		"message": (
			"A tall bank of drawers with brass handles. One drawer is "
			+ "slightly open, papers peeking out."
		)
	},
	{
		"name": "storage_cabinet",
		"label": "the reinforced cabinet",
		"position": Vector2(1057.0, 830.0),
		"message": (
			"A reinforced storage cabinet. Its shelves hold rolled scrolls "
			+ "and odd brass instruments."
		)
	},
	{
		"name": "tall_cabinet_a",
		"label": "the compass cabinet",
		"position": Vector2(1165.0, 980.0),
		"message": (
			"A tall cabinet of dark wood, marked with a compass-like "
			+ "emblem. Its door will not budge."
		)
	},
	{
		"name": "tall_cabinet_b",
		"label": "the hourglass cabinet",
		"position": Vector2(889.0, 1010.0),
		"message": (
			"A narrow cabinet. A circular lock with an hourglass mark "
			+ "guards whatever lies within."
		)
	},
	{
		"name": "chest_cabinet",
		"label": "the chest of books",
		"position": Vector2(1323.0, 1015.0),
		"message": (
			"A broad chest-cabinet packed with books and bundled scrolls. "
			+ "The bindings are worn with age."
		)
	},
	{
		"name": "writing_desk",
		"label": "the writing desk",
		"position": Vector2(1310.0, 735.0),
		"message": (
			"A writing desk. An open book, pinned parchment and an inkwell "
			+ "rest on its worn surface."
		)
	},
	{
		"name": "upper_panel_cabinet",
		"label": "the ring-marked cabinet",
		"position": Vector2(980.0, 348.0),
		"message": (
			"A tall ring-marked cabinet. Its lower emblem is scratched "
			+ "with a symbol that matches no library catalogue."
		)
	},
	{
		"name": "upper_shelf_cabinet",
		"label": "the upper book shelf",
		"position": Vector2(1060.0, 248.0),
		"message": (
			"An open shelf of dusty volumes and sealed containers. "
			+ "Several spines have been deliberately turned around."
		)
	},
	{
		"name": "upper_chest_cabinet",
		"label": "the chained book chest",
		"position": Vector2(1100.0, 418.0),
		"message": (
			"A chained chest-cabinet. The lock is intact, but the books "
			+ "inside have been disturbed recently."
		)
	},
	{
		"name": "upper_drawer_cabinet",
		"label": "the archive drawers",
		"position": Vector2(1015.0, 568.0),
		"message": (
			"Rows of archive drawers filled with brittle notes, labels "
			+ "and fragments of old casework."
		)
	},
	{
		"name": "upper_apothecary_cabinet",
		"label": "the apothecary cabinet",
		"position": Vector2(1160.0, 568.0),
		"message": (
			"A cabinet of bottles, powders and sealed jars. The dust "
			+ "around one vial has been recently disturbed."
		)
	},
	{
		"name": "lower_panel_a",
		"label": "the wheel-marked panel",
		"position": Vector2(320.0, 678.0),
		"message": (
			"A tall wooden panel with a wheel-like mechanism. Its symbols "
			+ "look designed to be turned in a precise order."
		)
	},
	{
		"name": "lower_panel_b",
		"label": "the ring-lock cabinet",
		"position": Vector2(460.0, 678.0),
		"message": (
			"A narrow cabinet with two ring handles and a heavy lower clasp. "
			+ "The lock has been opened and closed many times."
		)
	},
	{
		"name": "lower_storage",
		"label": "the purple archive cabinet",
		"position": Vector2(350.0, 818.0),
		"message": (
			"A storage cabinet packed with dark violet volumes and sealed "
			+ "drawers. One compartment is empty."
		)
	},
	{
		"name": "lower_globe_desk",
		"label": "the globe desk",
		"position": Vector2(470.0, 818.0),
		"message": (
			"A desk with an antique globe, an oil lamp and an open book. "
			+ "The lamp is still warm."
		)
	},
	{
		"name": "lower_study_table",
		"label": "the detective table",
		"position": Vector2(350.0, 958.0),
		"message": (
			"A detective's work table covered in papers, candles and a "
			+ "magnifying glass. The notes point toward the lower hall."
		)
	},
	{
		"name": "topleft_chest_a",
		"label": "the divided storage chest",
		"position": Vector2(200.0, 268.0),
		"message": (
			"A divided storage chest filled with banded books, scrolls and "
			+ "small sealed bundles."
		)
	},
	{
		"name": "topleft_cabinet_b",
		"label": "the three-tier bookcase",
		"position": Vector2(300.0, 408.0),
		"message": (
			"A three-tier bookcase. The top surface still holds an open "
			+ "book and several small cases."
		)
	},
	{
		"name": "topleft_cabinet_c",
		"label": "the reinforced archive cabinet",
		"position": Vector2(300.0, 548.0),
		"message": (
			"A reinforced archive cabinet with deep shelves and brass "
			+ "fasteners. Its contents are carefully sorted."
		)
	},
	{
		"name": "topleft_cabinet_d",
		"label": "the emblem cabinet",
		"position": Vector2(440.0, 458.0),
		"message": (
			"A dark cabinet bearing a circular crossed emblem. The lower "
			+ "handle is polished from frequent use."
		)
	},
	{
		"name": "topleft_tall_case",
		"label": "the tall ring case",
		"position": Vector2(180.0, 628.0),
		"message": (
			"A narrow two-part case with ring handles and reinforced "
			+ "straps. Something rattles behind the lower panel."
		)
	}
]

@export var debug_print_click_position := false

var player: Node2D
var scene_transitioning := false
var room_input_enabled := true
var current_interaction := ""
var interaction_runtime: RoomInteractionRuntime
var rgb_filter_visuals: Array[Node] = []
var archive_book_visual: Sprite2D
var _last_debug_mouse_position := Vector2(-100000, -100000)


func _ready() -> void:
	# 单独调试（未从主菜单开始）时解锁所有 Hub。
	if not GameState.is_game_started():
		GameState.unlock_all_hubs()
	GameState.current_room_id = ROOM_ID
	GameState.set_room_visited(ROOM_ID)
	player = $Worldsort/player
	player.position = PLAYER_SPAWN_POSITION
	player.set_physics_process(true)
	interaction_runtime = RoomInteractionRuntime.new()
	add_child(interaction_runtime)
	interaction_runtime.configure(self, player, {
		"items": INTERACT_ITEMS,
		"prop_node_paths": PROP_NODE_PATHS,
		"prop_occlusion_paths": PROP_OCCLUSION_PATHS,
		"room_display_name": "Library",
		"exit_position": EXIT_POSITION,
		"exit_radius": EXIT_RADIUS,
		"interaction_contact_margin": INTERACTION_CONTACT_MARGIN,
		"legacy_contact_radius": LEGACY_CONTACT_RADIUS,
		"interaction_front_offset": INTERACTION_FRONT_OFFSET,
		"gameplay_camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"developer_camera_zoom": DEVELOPER_CAMERA_ZOOM,
		"room_size": Vector2(ROOM_WIDTH, ROOM_HEIGHT),
		"prop_front_z": PROP_FRONT_Z,
		"prop_back_z": PROP_BACK_Z,
		"occlusion_mode": "visual_anchor",
		"ui_layer_name": "LibraryRoomUI",
	})
	_create_rgb_filter_stand()
	archive_book_visual = get_node_or_null("ArchiveBookVisual") as Sprite2D
	if archive_book_visual != null:
		archive_book_visual.visible = GameState.has_story_flag("library_archive_record_found")
	if player.has_method("set_visual_scale"):
		player.call("set_visual_scale", 1.0)
	GameState.return_spawn_id = RETURN_SPAWN_ID


func _process(_delta: float) -> void:
	current_interaction = interaction_runtime.refresh(room_input_enabled)
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


func _create_rgb_filter_stand() -> void:
	if not rgb_filter_visuals.is_empty():
		return
	var stand: Node2D = Node2D.new()
	stand.name = "RGBFilterStand"
	stand.position = Vector2(724.0, 650.0)
	stand.z_index = 8
	add_child(stand)
	rgb_filter_visuals.append(stand)
	var colors: Array[Color] = [
		Color(0.82, 0.10, 0.10, 0.88),
		Color(0.18, 0.72, 0.24, 0.88),
		Color(0.16, 0.38, 0.92, 0.88),
	]
	for index: int in range(colors.size()):
		var filter: Polygon2D = Polygon2D.new()
		filter.name = ["RedFilter", "GreenFilter", "BlueFilter"][index]
		var x: float = -78.0 + float(index) * 60.0
		filter.polygon = PackedVector2Array([
			Vector2(x, -24.0),
			Vector2(x + 48.0, -24.0),
			Vector2(x + 48.0, 24.0),
			Vector2(x, 24.0),
		])
		filter.color = colors[index]
		stand.add_child(filter)
		rgb_filter_visuals.append(filter)
	var caption: Label = Label.new()
	caption.name = "RGBFilterCaption"
	caption.text = "R   G   B"
	caption.position = Vector2(-40.0, 32.0)
	caption.size = Vector2(80.0, 24.0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58, 0.95))
	stand.add_child(caption)
	rgb_filter_visuals.append(caption)


func _use_rgb_filter(item_name: String) -> void:
	if GameState.has_story_flag("library_rgb_puzzle_solved"):
		interaction_runtime.present_feedback("The red, green and blue filters remain active. Their combined pale light keeps the hidden archive text visible.")
		return
	var flag_id: String = ""
	var color_name: String = ""
	match item_name:
		"rgb_red_filter":
			flag_id = "library_red_filter_active"
			color_name = "Red"
		"rgb_green_filter":
			flag_id = "library_green_filter_active"
			color_name = "Green"
		"rgb_blue_filter":
			flag_id = "library_blue_filter_active"
			color_name = "Blue"
		_:
			return
	if GameState.has_story_flag(flag_id):
		interaction_runtime.present_feedback("%s light is already active in the optical stand." % color_name)
		return
	GameState.set_story_flag(flag_id)
	var all_active: bool = (
		GameState.has_story_flag("library_red_filter_active")
		and GameState.has_story_flag("library_green_filter_active")
		and GameState.has_story_flag("library_blue_filter_active")
	)
	if all_active:
		GameState.set_story_flag("library_rgb_puzzle_solved")
		GameState.add_evidence("library_rgb_archive_layer")
		if NoteHud != null and not NoteHud.has_clue("library_rgb_archive_layer"):
			NoteHud.add_clue("library_rgb_archive_layer", {
				"title": "RGB Archive Filter",
				"content": "Red, green and blue light are all active in the optical stand. Their additive combination becomes a pale neutral light, revealing the layered diagram and the route to the Ashford Archive Record.",
				"category": "investigation",
			})
		interaction_runtime.present_feedback("Red, green and blue combine into pale neutral light. The additive color key reveals the hidden archive text.")
	else:
		interaction_runtime.present_feedback("%s light is active. Activate the other two filters in any order; the archive will appear when all three colors overlap." % color_name)


func try_interact() -> void:
	if current_interaction == "exit":
		return_to_castle_hall()
		return

	for item: Dictionary in INTERACT_ITEMS:
		if current_interaction == str(item["name"]):
			# 图纸拾取：加入配方并记录到侦探笔记。
			var item_name: String = str(item["name"])
			if item_name.begins_with("recipe_"):
				_collect_recipe(item_name)
				return
			if item_name.begins_with("rgb_"):
				_use_rgb_filter(item_name)
				return
			if item_name == "research_desk":
				_collect_archive_record()
				return
			interaction_runtime.present_feedback(str(item["message"]))
			return


func _collect_archive_record() -> void:
	if not GameState.has_story_flag("library_rgb_puzzle_solved") and not GameState.developer_mode:
		interaction_runtime.present_feedback("The archive text is split into three color layers. Use the red, green and blue filters before copying the record.")
		return
	if GameState.has_story_flag("library_archive_record_found"):
		if archive_book_visual != null:
			archive_book_visual.visible = true
		interaction_runtime.present_feedback("You already copied the Ashford archive record into your notes.")
		return
	GameState.set_story_flag("library_archive_record_found")
	GameState.set_story_flag("perfect_ending_library_ready")
	if archive_book_visual != null:
		archive_book_visual.visible = true
	GameState.add_evidence("ashford_archive_record")
	if NoteHud != null:
		NoteHud.add_clue("ashford_archive_record", {
			"title": "Ashford Archive Record",
			"content": (
				"A restricted archive card describes the Knowledge Engine and the castle's security network. "
				+ "Lord Ashford restricted the complete Knowledge Engine plans to the Master Archive. "
				+ "Several maintenance copies of Ashford engineering diagrams were produced without authorization, "
				+ "and the archive access records contain irregular maintenance-level requests. "
				+ "The archive route is hidden behind the final vault, and the security system can be redirected "
				+ "through the maintenance circuit. Whoever made those requests needed technical access, "
				+ "a route through the service systems, and a reason to create a blackout."
			),
			"category": "lore",
		})
	interaction_runtime.present_feedback("Archive record copied. It links the Knowledge Engine to the maintenance circuit and the hidden service route.")


func _collect_recipe(recipe_id: String) -> void:
	## 把图书馆图纸加入配方表（recipe_id -> recipe_xxx）。
	var recipe_key: String = ""
	if recipe_id == "recipe_swift_scroll":
		recipe_key = "recipe_swift"
	elif recipe_id == "recipe_vision_scroll":
		recipe_key = "recipe_vision"
	if recipe_key.is_empty():
		return
	if GameState.has_recipe(recipe_key):
		interaction_runtime.present_feedback("You already copied this recipe into your notes.")
		return
	GameState.add_recipe(recipe_key)
	var rinfo: Dictionary = GameState.RECIPE_INFO.get(recipe_key, {})
	interaction_runtime.present_feedback("Recipe learned: %s" % str(rinfo.get("name", recipe_key)))
	if NoteHud != null:
		NoteHud.add_clue(recipe_key, {
			"title": str(rinfo.get("name", recipe_key)),
			"content": str(rinfo.get("description", "")),
			"category": "recipe",
		})


func return_to_castle_hall() -> void:
	if scene_transitioning:
		return
	scene_transitioning = true
	room_input_enabled = false

	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)

	GameState.prepare_return_to_hub(RETURN_SPAWN_ID)

	var change_error: Error = get_tree().change_scene_to_file(
		GameState.return_scene_path
	)
	if change_error != OK:
		scene_transitioning = false
		room_input_enabled = true
		player.set_physics_process(true)
		push_error(
			"Failed to return to Castle Hall. Error: "
			+ str(change_error)
		)
