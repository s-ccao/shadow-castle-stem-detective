extends Node2D

const LIGHT_CHALLENGE_SCENE: PackedScene = preload(
	"res://scenes/ui/library_light_lab_ui.tscn"
)
const KNOWLEDGE_SHELF_SCENE: PackedScene = preload(
	"res://scenes/ui/library_knowledge_shelf_ui.tscn"
)

## Library — 图书馆/奥术档案馆（用户提供 9a790883 背景图）。
## 初始版本：出生点、返回门、占位交互点、鼠标坐标调试。

const ROOM_BACKGROUND_PATH: String = (
	"res://assets/backgrounds/library_archive.png"
)
const ROOM_WIDTH: float = 1448.0
const ROOM_HEIGHT: float = 1086.0
const ROOM_ID: String = "library"
const RETURN_SPAWN_ID: String = "library_door"

# Candles, torches and desk lamps are already painted into the archive plate.
# These are those fixtures in room space so the light they imply is actually
# cast, which is what separates a lit room from an illustrated one.
const AMBIENCE_Z: int = -90
const CANDLE_WARM: Color = Color(1.0, 0.74, 0.36, 0.52)
const TORCH_WARM: Color = Color(1.0, 0.68, 0.30, 0.58)
const DESK_LAMP_WARM: Color = Color(1.0, 0.80, 0.44, 0.50)
# Each light challenge is lit by the wavelength it teaches, so the three levels
# are told apart by colour before a single label is read.
const CHALLENGE_STATION_LIGHT: Dictionary = {
	"red": Color(1.0, 0.34, 0.28, 0.46),
	"green": Color(0.36, 1.0, 0.48, 0.44),
	"blue": Color(0.40, 0.62, 1.0, 0.46),
}
const AMBIENCE_FIXTURES: Array[Dictionary] = [
	{"position": Vector2(219.0, 124.0), "colour": CANDLE_WARM, "radius": 135.0},
	{"position": Vector2(1219.0, 124.0), "colour": CANDLE_WARM, "radius": 135.0},
	{"position": Vector2(643.0, 78.0), "colour": CANDLE_WARM, "radius": 120.0},
	{"position": Vector2(778.0, 78.0), "colour": CANDLE_WARM, "radius": 120.0},
	{"position": Vector2(1421.0, 346.0), "colour": TORCH_WARM, "radius": 160.0},
	{"position": Vector2(1393.0, 544.0), "colour": DESK_LAMP_WARM, "radius": 145.0},
	{"position": Vector2(99.0, 375.0), "colour": DESK_LAMP_WARM, "radius": 140.0},
	{"position": Vector2(750.0, 488.0), "colour": CANDLE_WARM, "radius": 130.0},
	{"position": Vector2(639.0, 964.0), "colour": TORCH_WARM, "radius": 150.0},
	{"position": Vector2(817.0, 964.0), "colour": TORCH_WARM, "radius": 150.0},
]

const PLAYER_SPAWN_POSITION: Vector2 = Vector2(724.0, 930.0)
const EXIT_POSITION: Vector2 = Vector2(724.0, 1030.0)
const EXIT_RADIUS: float = 80.0
const EXIT_RECT: Rect2 = Rect2(622.0, 962.0, 204.0, 124.0)
const INTERACTION_CONTACT_MARGIN: float = 14.0
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
const CHALLENGE_STATIONS: Dictionary = {
	"research_desk": {
		"challenge": "red",
		"filter": "red",
		"title": "Spectrum Sequencer",
		"earned_flag": "library_red_filter_earned",
		"knowledge": "spectrum",
		"knowledge_flag": "library_spectrum_knowledge_learned",
		"knowledge_shelf": "topleft_tall_case",
	},
	"writing_desk": {
		"challenge": "green",
		"filter": "green",
		"title": "Reflection Matrix",
		"earned_flag": "library_green_filter_earned",
		"knowledge": "reflection",
		"knowledge_flag": "library_reflection_knowledge_learned",
		"knowledge_shelf": "lower_storage",
	},
	"lower_globe_desk": {
		"challenge": "blue",
		"filter": "blue",
		"title": "Additive Relay",
		"earned_flag": "library_blue_filter_earned",
		"knowledge": "additive",
		"knowledge_flag": "library_additive_knowledge_learned",
		"knowledge_shelf": "storage_cabinet",
	},
}
const KNOWLEDGE_SHELVES: Dictionary = {
	"topleft_tall_case": {
		"knowledge": "spectrum",
		"flag": "library_spectrum_knowledge_learned",
		"station": "research_desk",
		"title": "Visible Spectrum & Wavelength",
		"marker": "KNOWLEDGE I · SPECTRUM",
	},
	"lower_storage": {
		"knowledge": "reflection",
		"flag": "library_reflection_knowledge_learned",
		"station": "writing_desk",
		"title": "Reflection, Absorption & Color",
		"marker": "KNOWLEDGE II · REFLECTION",
	},
	"storage_cabinet": {
		"knowledge": "additive",
		"flag": "library_additive_knowledge_learned",
		"station": "lower_globe_desk",
		"title": "Additive Color Mixing",
		"marker": "KNOWLEDGE III · ADDITIVE",
	},
}
const FILTER_SLOT_INFO: Dictionary = {
	"rgb_red_filter": {
		"filter": "red",
		"earned_flag": "library_red_filter_earned",
		"active_flag": "library_red_filter_active",
		"challenge_station": "Spectrum Sequencer at the central research desk",
	},
	"rgb_green_filter": {
		"filter": "green",
		"earned_flag": "library_green_filter_earned",
		"active_flag": "library_green_filter_active",
		"challenge_station": "Reflection Matrix at the east writing desk",
	},
	"rgb_blue_filter": {
		"filter": "blue",
		"earned_flag": "library_blue_filter_earned",
		"active_flag": "library_blue_filter_active",
		"challenge_station": "Additive Relay at the west globe desk",
	},
}

var INTERACT_ITEMS: Array[Dictionary] = [
	{
		"name": "recipe_swift_scroll",
		"label": "the bottle-scroll",
		"position": Vector2(1060.0, 320.0),
		"interaction_rect": Rect2(1020.0, 282.0, 80.0, 76.0),
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
		"interaction_rect": Rect2(260.0, 442.0, 80.0, 76.0),
		"interaction_radius": RECIPE_INTERACT_RADIUS,
		"message": (
			"A scroll hidden inside an old atlas. "
			+ "It holds the recipe for the Vision Potion."
		)
	},
	{
		"name": "research_desk",
		"label": "the Spectrum Sequencer",
		"position": Vector2(724.0, 560.0),
		"interaction_rect": Rect2(624.0, 430.0, 200.0, 176.0),
		"message": "A wavelength sequencer is embedded in the illuminated research desk."
	},
	{
		"name": "rgb_red_filter",
		"label": "the empty crimson lens slot",
		"position": Vector2(664.0, 650.0),
		"interaction_rect": Rect2(636.0, 622.0, 56.0, 56.0),
		"message": "An empty crimson lens slot waits for a filter recovered from the Spectrum Sequencer."
	},
	{
		"name": "rgb_green_filter",
		"label": "the empty verdant lens slot",
		"position": Vector2(724.0, 650.0),
		"interaction_rect": Rect2(696.0, 622.0, 56.0, 56.0),
		"message": "An empty verdant lens slot waits for a filter recovered from the Reflection Matrix."
	},
	{
		"name": "rgb_blue_filter",
		"label": "the empty cobalt lens slot",
		"position": Vector2(784.0, 650.0),
		"interaction_rect": Rect2(756.0, 622.0, 56.0, 56.0),
		"message": "An empty cobalt lens slot waits for a filter recovered from the Additive Relay."
	},
	{
		"name": "chained_cabinet",
		"label": "the chained cabinet",
		"position": Vector2(250.0, 170.0),
		"interaction_rect": Rect2(166.0, 96.0, 168.0, 148.0),
		"message": (
			"A heavy cabinet bound by a chain and a gold padlock. "
			+ "Whatever it guards, it was meant to stay sealed."
		)
	},
	{
		"name": "drawer_bank",
		"label": "the drawer bank",
		"position": Vector2(1180.0, 260.0),
		"interaction_rect": Rect2(1050.0, 186.0, 260.0, 148.0),
		"message": (
			"A tall bank of drawers with brass handles. One drawer is "
			+ "slightly open, papers peeking out."
		)
	},
	{
		"name": "storage_cabinet",
		"label": "the reinforced additive-light archive",
		"position": Vector2(1057.0, 830.0),
		"message": "An empty reinforced shelf holds a single filed volume on additive light."
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
		"label": "the Reflection Matrix",
		"position": Vector2(1310.0, 735.0),
		"message": "A brass reflection matrix overlays the east writing desk."
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
		"message": "An open shelf of dusty volumes and sealed containers."
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
		"label": "the violet reflection cabinet",
		"position": Vector2(350.0, 818.0),
		"message": (
			"A violet archive cabinet with one empty compartment. A single "
			+ "field guide on reflection and absorption is still filed here."
		)
	},
	{
		"name": "lower_globe_desk",
		"label": "the Additive Relay",
		"position": Vector2(470.0, 818.0),
		"message": "Three emitter controls have been fitted around the west globe desk."
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
		"message": "A three-tier bookcase. The top surface still holds an open book."
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
		"label": "the tall wavelength case",
		"position": Vector2(180.0, 628.0),
		"message": (
			"A narrow two-part case, almost emptied. One volume remains on "
			+ "its shelf: a field study of visible wavelengths."
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
var rgb_filter_nodes: Dictionary = {}
var rgb_filter_stand: Node2D
var rgb_filter_beams: Dictionary = {}
var rgb_neutral_core: Polygon2D
var rgb_core_scanner: Node2D
var rgb_core_outer_ring: Line2D
var rgb_core_inner_ring: Line2D
var rgb_filter_caption: Label
var rgb_effect_time := 0.0
var library_challenge_ui: LibraryLightLabUI
var library_knowledge_ui: LibraryKnowledgeShelfUI
var challenge_station_markers: Dictionary = {}
var knowledge_shelf_markers: Dictionary = {}
var archive_book_visual: Sprite2D
var _last_debug_mouse_position := Vector2(-100000, -100000)


## The archive plate already paints every candle, torch and desk lamp. This casts
## the light those fixtures imply so the room reads as lit by its own fixtures.
func _create_room_ambience() -> void:
	var ambience := Node2D.new()
	ambience.name = "LibraryRoomAmbience"
	ambience.z_index = AMBIENCE_Z
	add_child(ambience)
	for fixture: Dictionary in AMBIENCE_FIXTURES:
		OpticalFxRuntime.install_lamp(
			ambience,
			fixture["position"] as Vector2,
			fixture["colour"] as Color,
			float(fixture["radius"]),
			0.20
		)


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
		"exit_rect": EXIT_RECT,
		"interaction_contact_margin": INTERACTION_CONTACT_MARGIN,
		"legacy_contact_radius": LEGACY_CONTACT_RADIUS,
		"interaction_front_offset": INTERACTION_FRONT_OFFSET,
		"gameplay_camera_zoom": GAMEPLAY_CAMERA_ZOOM,
		"developer_camera_zoom": DEVELOPER_CAMERA_ZOOM,
		"room_size": Vector2(ROOM_WIDTH, ROOM_HEIGHT),
		"preferred_spawn": PLAYER_SPAWN_POSITION,
		"prop_front_z": PROP_FRONT_Z,
		"prop_back_z": PROP_BACK_Z,
		"occlusion_mode": "visual_anchor",
		"ui_layer_name": "LibraryRoomUI",
	})
	_migrate_legacy_rgb_progress()
	_create_room_ambience()
	_create_library_knowledge_ui()
	_create_light_challenge_ui()
	_create_knowledge_shelf_markers()
	_create_challenge_station_markers()
	_create_rgb_filter_stand()
	archive_book_visual = get_node_or_null("ArchiveBookVisual") as Sprite2D
	if archive_book_visual != null:
		archive_book_visual.visible = GameState.has_story_flag("library_archive_record_found")
	if player.has_method("set_room_visual_scale"):
		player.call("set_room_visual_scale", ROOM_ID)
	GameState.return_spawn_id = RETURN_SPAWN_ID


func _create_light_challenge_ui() -> void:
	if library_challenge_ui != null:
		return
	library_challenge_ui = LIGHT_CHALLENGE_SCENE.instantiate() as LibraryLightLabUI
	library_challenge_ui.name = "LibraryLightLabUI"
	library_challenge_ui.completed.connect(_on_light_challenge_completed)
	library_challenge_ui.closed.connect(_on_light_challenge_closed)
	add_child(library_challenge_ui)


func _create_library_knowledge_ui() -> void:
	if library_knowledge_ui != null:
		return
	library_knowledge_ui = KNOWLEDGE_SHELF_SCENE.instantiate() as LibraryKnowledgeShelfUI
	library_knowledge_ui.name = "LibraryKnowledgeShelfUI"
	library_knowledge_ui.recorded.connect(_on_library_knowledge_recorded)
	library_knowledge_ui.closed.connect(_on_library_knowledge_closed)
	add_child(library_knowledge_ui)


func _create_knowledge_shelf_markers() -> void:
	for shelf_item: String in KNOWLEDGE_SHELVES:
		var shelf_info := KNOWLEDGE_SHELVES[shelf_item] as Dictionary
		var shelf_rect := get_library_interaction_rect(shelf_item)
		if shelf_rect.size.x <= 0.0 or shelf_rect.size.y <= 0.0:
			continue
		var marker := Node2D.new()
		marker.name = "KnowledgeShelfMarker_" + str(shelf_info["knowledge"])
		marker.position = Vector2(shelf_rect.get_center().x, shelf_rect.position.y - 16.0)
		marker.z_as_relative = false
		marker.z_index = 24
		marker.set_meta("knowledge_id", str(shelf_info["knowledge"]))
		add_child(marker)
		knowledge_shelf_markers[str(shelf_info["knowledge"])] = marker

		var plate := Polygon2D.new()
		plate.name = "KnowledgeShelfPlate"
		plate.polygon = PackedVector2Array([
			Vector2(-70.0, -15.0), Vector2(70.0, -15.0),
			Vector2(76.0, -9.0), Vector2(76.0, 9.0),
			Vector2(70.0, 15.0), Vector2(-70.0, 15.0),
			Vector2(-76.0, 9.0), Vector2(-76.0, -9.0),
		])
		plate.color = Color(0.075, 0.055, 0.035, 0.97)
		marker.add_child(plate)

		var book_mark := Label.new()
		book_mark.name = "KnowledgeBookMark"
		book_mark.text = "▤"
		book_mark.position = Vector2(-65.0, -12.0)
		book_mark.size = Vector2(22.0, 24.0)
		book_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		book_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		book_mark.add_theme_font_size_override("font_size", 12)
		book_mark.add_theme_color_override("font_color", Color(0.82, 0.61, 0.28, 1.0))
		marker.add_child(book_mark)

		var label := Label.new()
		label.name = "KnowledgeShelfLabel"
		label.text = CaseLocale.line(str(shelf_info["marker"]))
		label.position = Vector2(-42.0, -11.0)
		label.size = Vector2(108.0, 22.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 7)
		label.add_theme_color_override("font_color", Color(0.88, 0.72, 0.40, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.015, 0.01, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		marker.add_child(label)
	_refresh_knowledge_shelf_markers()


func _create_challenge_station_markers() -> void:
	for station_item: String in CHALLENGE_STATIONS:
		var station_info := CHALLENGE_STATIONS[station_item] as Dictionary
		var station_rect := get_library_interaction_rect(station_item)
		if station_rect.size.x <= 0.0 or station_rect.size.y <= 0.0:
			continue
		var marker := Node2D.new()
		marker.name = "LightChallengeMarker_" + str(station_info["challenge"])
		marker.position = Vector2(station_rect.get_center().x, station_rect.position.y - 18.0)
		marker.z_as_relative = false
		marker.z_index = 24
		marker.set_meta("challenge_id", str(station_info["challenge"]))
		add_child(marker)
		challenge_station_markers[str(station_info["challenge"])] = marker

		var station_light: Color = CHALLENGE_STATION_LIGHT.get(
			str(station_info["challenge"]),
			Color(1.0, 0.82, 0.44, 0.42)
		)
		OpticalFxRuntime.install_lamp(marker, Vector2(0.0, 34.0), station_light, 96.0, 0.22)

		var plate := Polygon2D.new()
		plate.name = "BrassChallengePlate"
		plate.polygon = PackedVector2Array([
			Vector2(-53.0, -15.0), Vector2(53.0, -15.0),
			Vector2(59.0, -9.0), Vector2(59.0, 9.0),
			Vector2(53.0, 15.0), Vector2(-53.0, 15.0),
			Vector2(-59.0, 9.0), Vector2(-59.0, -9.0),
		])
		plate.color = Color(0.16, 0.105, 0.055, 0.96)
		marker.add_child(plate)

		var label := Label.new()
		label.name = "ChallengeStationLabel"
		label.text = _challenge_station_label(str(station_info["challenge"]))
		label.position = Vector2(-54.0, -11.0)
		label.size = Vector2(108.0, 22.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_color", Color(0.91, 0.75, 0.42, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.035, 0.015, 0.01, 1.0))
		label.add_theme_constant_override("outline_size", 2)
		marker.add_child(label)
	_refresh_challenge_station_markers()


func _challenge_station_label(challenge: String) -> String:
	match challenge:
		"red":
			return CaseLocale.line("I · SPECTRUM")
		"green":
			return CaseLocale.line("II · REFLECTION")
		"blue":
			return CaseLocale.line("III · ADDITIVE")
	return "LIGHT TEST"


func _refresh_challenge_station_markers() -> void:
	for challenge: String in challenge_station_markers:
		var marker := challenge_station_markers[challenge] as Node2D
		if marker == null:
			continue
		var earned := GameState.has_story_flag("library_%s_filter_earned" % challenge)
		var station_info := _challenge_station_info(challenge)
		var knowledge_ready := (
			not station_info.is_empty()
			and GameState.has_story_flag(str(station_info["knowledge_flag"]))
		)
		var plate := marker.get_node_or_null("BrassChallengePlate") as Polygon2D
		if plate != null:
			plate.color = (
				Color(0.23, 0.28, 0.15, 0.98)
				if earned
				else Color(0.17, 0.105, 0.25, 0.98)
				if knowledge_ready
				else Color(0.16, 0.105, 0.055, 0.96)
			)
		marker.set_meta("completed", earned)
		marker.set_meta("knowledge_ready", knowledge_ready)
		# The beacon is the station's progress readout: dormant, primed, or solved.
		var station_glow := marker.get_node_or_null("RoomLampGlow") as Sprite2D
		if station_glow != null:
			OpticalFxRuntime.set_lamp_energy(
				station_glow,
				1.0 if earned else (0.74 if knowledge_ready else 0.30),
				0.10 if earned else 0.32
			)


func _refresh_knowledge_shelf_markers() -> void:
	for knowledge_id: String in knowledge_shelf_markers:
		var marker := knowledge_shelf_markers[knowledge_id] as Node2D
		if marker == null:
			continue
		var learned := GameState.has_story_flag(
			"library_%s_knowledge_learned" % knowledge_id
		)
		var plate := marker.get_node_or_null("KnowledgeShelfPlate") as Polygon2D
		if plate != null:
			plate.color = Color(0.12, 0.18, 0.09, 0.98) if learned else Color(0.075, 0.055, 0.035, 0.97)
		marker.set_meta("recorded", learned)


func _process(delta: float) -> void:
	rgb_effect_time += delta
	if rgb_core_scanner != null:
		rgb_core_outer_ring.rotation = rgb_effect_time * 0.72
		rgb_core_inner_ring.rotation = -rgb_effect_time * 1.08
		var breath := 0.5 + 0.5 * sin(rgb_effect_time * 2.8)
		rgb_core_scanner.modulate.a = 0.72 + breath * 0.28
		for beam_variant: Variant in rgb_filter_beams.values():
			var beam := beam_variant as Line2D
			if beam != null and beam.visible:
				beam.width = 2.2 + breath * 1.4
	current_interaction = interaction_runtime.refresh(room_input_enabled)
	if Input.is_action_just_pressed("interact") and room_input_enabled:
		try_interact()


func _exit_tree() -> void:
	if (
		(library_challenge_ui != null and library_challenge_ui.visible)
		or (library_knowledge_ui != null and library_knowledge_ui.visible)
	):
		ArchiveUi.set_hub_entries_suppressed(false)


func _migrate_legacy_rgb_progress() -> void:
	var legacy_knowledge: Dictionary = {
		"red": "spectrum",
		"green": "reflection",
		"blue": "additive",
	}
	for color_id: String in legacy_knowledge:
		if GameState.has_story_flag("library_%s_filter_active" % color_id):
			GameState.set_story_flag("library_%s_filter_earned" % color_id)
		if GameState.has_story_flag("library_%s_filter_earned" % color_id):
			GameState.set_story_flag(
				"library_%s_knowledge_learned" % str(legacy_knowledge[color_id])
			)


func _open_library_knowledge(knowledge_id: String) -> void:
	if (
		library_knowledge_ui == null
		or library_knowledge_ui.visible
		or (library_challenge_ui != null and library_challenge_ui.visible)
	):
		return
	var flag_id := "library_%s_knowledge_learned" % knowledge_id
	room_input_enabled = false
	current_interaction = ""
	interaction_runtime.refresh(false)
	ArchiveUi.set_hub_entries_suppressed(true)
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)
	library_knowledge_ui.open_knowledge(
		knowledge_id,
		GameState.has_story_flag(flag_id)
	)


func _on_library_knowledge_recorded(knowledge_id: String) -> void:
	var flag_id := "library_%s_knowledge_learned" % knowledge_id
	if GameState.has_story_flag(flag_id):
		return
	GameState.set_story_flag(flag_id)
	_refresh_knowledge_shelf_markers()
	_refresh_challenge_station_markers()
	if NoteHud != null:
		var note_id := "library_%s_knowledge" % knowledge_id
		if not NoteHud.has_clue(note_id):
			NoteHud.add_clue(note_id, _library_knowledge_note(knowledge_id))


func _on_library_knowledge_closed() -> void:
	room_input_enabled = true
	ArchiveUi.set_hub_entries_suppressed(false)
	if player != null and not scene_transitioning:
		player.set_physics_process(true)


func _library_knowledge_note(knowledge_id: String) -> Dictionary:
	match knowledge_id:
		"spectrum":
			return {
				"title": "Visible Spectrum & Wavelength",
				"content": "Visible-light wavelength decreases from red through green toward blue. Longest to shortest: red, green, blue.",
				"category": "knowledge",
				"silent": true,
			}
		"reflection":
			return {
				"title": "Reflection, Absorption & Color",
				"content": "Seen color is reflected light. A green leaf reflects green wavelengths and absorbs much of the red and blue light.",
				"category": "knowledge",
				"silent": true,
			}
		"additive":
			return {
				"title": "Additive Color Mixing",
				"content": "Light adds: green plus blue makes cyan, red plus blue makes magenta, and red plus green plus blue makes white.",
				"category": "knowledge",
				"silent": true,
			}
	return {}


func get_library_interaction_rect(item_name: String) -> Rect2:
	for item: Dictionary in INTERACT_ITEMS:
		if str(item["name"]) != item_name:
			continue
		if interaction_runtime != null:
			return interaction_runtime.call("_get_item_visual_rect", item) as Rect2
		if item.has("interaction_rect"):
			return item["interaction_rect"] as Rect2
		var center := item.get("position", Vector2.ZERO) as Vector2
		return Rect2(center - Vector2(42.0, 34.0), Vector2(84.0, 68.0))
	return Rect2()


func _open_library_challenge(challenge: String) -> void:
	if (
		library_challenge_ui == null
		or library_challenge_ui.visible
		or (library_knowledge_ui != null and library_knowledge_ui.visible)
	):
		return
	var station_info := _challenge_station_info(challenge)
	if station_info.is_empty():
		return
	var knowledge_flag := str(station_info["knowledge_flag"])
	if not GameState.has_story_flag(knowledge_flag):
		var shelf_item := str(station_info["knowledge_shelf"])
		var shelf_info := KNOWLEDGE_SHELVES.get(shelf_item, {}) as Dictionary
		interaction_runtime.present_feedback(
			"Question terminal locked. Study and file '%s' at the marked knowledge shelf first."
			% str(shelf_info.get("title", "the missing knowledge record"))
		)
		return
	var earned_flag := "library_%s_filter_earned" % challenge
	if GameState.has_story_flag(earned_flag):
		interaction_runtime.present_feedback(
			"This challenge is complete. Carry the recovered %s filter to the central optical array."
			% challenge
		)
		return
	room_input_enabled = false
	current_interaction = ""
	interaction_runtime.refresh(false)
	ArchiveUi.set_hub_entries_suppressed(true)
	if player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
	player.set_physics_process(false)
	library_challenge_ui.open_challenge(challenge)


func _challenge_station_info(challenge: String) -> Dictionary:
	for station_info_variant: Variant in CHALLENGE_STATIONS.values():
		var station_info := station_info_variant as Dictionary
		if str(station_info.get("challenge", "")) == challenge:
			return station_info
	return {}


func _on_light_challenge_completed(challenge: String) -> void:
	var earned_flag := "library_%s_filter_earned" % challenge
	if GameState.has_story_flag(earned_flag):
		return
	GameState.set_story_flag(earned_flag)
	_refresh_challenge_station_markers()
	if NoteHud != null:
		var note_id := "library_%s_light_challenge" % challenge
		if not NoteHud.has_clue(note_id):
			NoteHud.add_clue(note_id, _light_challenge_note(challenge))


func _on_light_challenge_closed() -> void:
	room_input_enabled = true
	ArchiveUi.set_hub_entries_suppressed(false)
	if player != null and not scene_transitioning:
		player.set_physics_process(true)


func _light_challenge_note(challenge: String) -> Dictionary:
	match challenge:
		"red":
			return {
				"title": "Spectrum Sequencer",
				"content": "Visible-light wavelength decreases from red through green toward blue. The recovered crimson filter was sealed behind a longest-to-shortest spectrum lock.",
				"category": "knowledge",
				"silent": true,
			}
		"green":
			return {
				"title": "Reflection Matrix",
				"content": "A green leaf appears green because green wavelengths are reflected toward the eye while much of the red and blue light is absorbed.",
				"category": "knowledge",
				"silent": true,
			}
		"blue":
			return {
				"title": "Additive Relay",
				"content": "Colored light adds: green plus blue makes cyan, red plus blue makes magenta, and red plus green plus blue makes white light.",
				"category": "knowledge",
				"silent": true,
			}
	return {}


func _create_rgb_filter_stand() -> void:
	if not rgb_filter_visuals.is_empty():
		return
	rgb_filter_stand = Node2D.new()
	rgb_filter_stand.name = "RGBFilterStand"
	rgb_filter_stand.position = Vector2(724.0, 650.0)
	rgb_filter_stand.z_index = 4
	rgb_filter_stand.set_meta("style_family", "ashford_jewel_glass")
	add_child(rgb_filter_stand)
	rgb_filter_visuals.append(rgb_filter_stand)
	var stand := rgb_filter_stand

	var shadow := Polygon2D.new()
	shadow.name = "StandShadow"
	shadow.position = Vector2(3.0, 6.0)
	shadow.polygon = PackedVector2Array([
		Vector2(-102.0, -31.0), Vector2(102.0, -31.0),
		Vector2(112.0, -21.0), Vector2(112.0, 34.0),
		Vector2(102.0, 44.0), Vector2(-102.0, 44.0),
		Vector2(-112.0, 34.0), Vector2(-112.0, -21.0),
	])
	shadow.color = Color(0.005, 0.004, 0.008, 0.62)
	stand.add_child(shadow)

	var plinth := Polygon2D.new()
	plinth.name = "BrassOpticalPlinth"
	plinth.polygon = shadow.polygon
	plinth.color = Color(0.20, 0.14, 0.075, 0.98)
	stand.add_child(plinth)
	var plinth_inlay := Polygon2D.new()
	plinth_inlay.name = "WalnutInlay"
	plinth_inlay.polygon = PackedVector2Array([
		Vector2(-102.0, -23.0), Vector2(102.0, -23.0),
		Vector2(104.0, -18.0), Vector2(104.0, 30.0),
		Vector2(98.0, 36.0), Vector2(-98.0, 36.0),
		Vector2(-104.0, 30.0), Vector2(-104.0, -18.0),
	])
	plinth_inlay.color = Color(0.055, 0.036, 0.030, 0.98)
	stand.add_child(plinth_inlay)

	var filter_specs: Array[Dictionary] = [
		{"id": "rgb_red_filter", "node": "RedFilter", "x": -60.0, "color": Color(0.46, 0.14, 0.12, 0.48), "glyph": "R"},
		{"id": "rgb_green_filter", "node": "GreenFilter", "x": 0.0, "color": Color(0.17, 0.39, 0.23, 0.48), "glyph": "G"},
		{"id": "rgb_blue_filter", "node": "BlueFilter", "x": 60.0, "color": Color(0.16, 0.27, 0.48, 0.48), "glyph": "B"},
	]
	for spec: Dictionary in filter_specs:
		var beam := Line2D.new()
		beam.name = str(spec["node"]) + "ToArchiveCore"
		beam.points = PackedVector2Array(
			[Vector2(float(spec["x"]), 0.0), Vector2(0.0, -38.0)]
		)
		beam.width = 3.0
		var beam_color := spec["color"] as Color
		beam.default_color = Color(beam_color.r * 1.35, beam_color.g * 1.35, beam_color.b * 1.35, 0.82)
		beam.visible = false
		stand.add_child(beam)
		rgb_filter_beams[str(spec["id"])] = beam
	for spec: Dictionary in filter_specs:
		var filter_root := Node2D.new()
		filter_root.name = str(spec["node"])
		filter_root.position = Vector2(float(spec["x"]), 0.0)
		filter_root.set_meta("interaction_id", str(spec["id"]))
		filter_root.set_meta("base_color", spec["color"] as Color)
		stand.add_child(filter_root)
		rgb_filter_nodes[str(spec["id"])] = filter_root
		rgb_filter_visuals.append(filter_root)

		var active_glow := Polygon2D.new()
		active_glow.name = "ActiveGlow"
		active_glow.polygon = PackedVector2Array([
			Vector2(-30.0, -23.0), Vector2(30.0, -23.0),
			Vector2(34.0, -17.0), Vector2(34.0, 21.0),
			Vector2(28.0, 27.0), Vector2(-28.0, 27.0),
			Vector2(-34.0, 21.0), Vector2(-34.0, -17.0),
		])
		var base_color := spec["color"] as Color
		active_glow.color = Color(base_color.r, base_color.g, base_color.b, 0.18)
		active_glow.visible = false
		filter_root.add_child(active_glow)

		var frame := Polygon2D.new()
		frame.name = "BrassFrame"
		frame.polygon = PackedVector2Array([
			Vector2(-27.0, -20.0), Vector2(23.0, -20.0),
			Vector2(29.0, -14.0), Vector2(29.0, 16.0),
			Vector2(23.0, 22.0), Vector2(-23.0, 22.0),
			Vector2(-29.0, 16.0), Vector2(-29.0, -14.0),
		])
		frame.color = Color(0.43, 0.31, 0.15, 0.98)
		filter_root.add_child(frame)

		var glass := Polygon2D.new()
		glass.name = "JewelGlass"
		glass.polygon = PackedVector2Array([
			Vector2(-20.0, -14.0), Vector2(17.0, -14.0),
			Vector2(22.0, -9.0), Vector2(22.0, 11.0),
			Vector2(17.0, 16.0), Vector2(-17.0, 16.0),
			Vector2(-22.0, 11.0), Vector2(-22.0, -9.0),
		])
		glass.color = base_color
		filter_root.add_child(glass)

		var highlight := Line2D.new()
		highlight.name = "GlassHighlight"
		highlight.width = 2.0
		highlight.default_color = Color(0.92, 0.84, 0.66, 0.48)
		highlight.points = PackedVector2Array([
			Vector2(-15.0, -9.0), Vector2(12.0, -9.0), Vector2(17.0, -5.0)
		])
		filter_root.add_child(highlight)

		var glyph := Label.new()
		glyph.name = "EngravedGlyph"
		glyph.text = str(spec["glyph"])
		glyph.position = Vector2(-13.0, -10.0)
		glyph.size = Vector2(26.0, 24.0)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 11)
		glyph.add_theme_color_override("font_color", Color(0.90, 0.76, 0.43, 0.88))
		glyph.add_theme_color_override("font_outline_color", Color(0.05, 0.025, 0.02, 0.90))
		glyph.add_theme_constant_override("outline_size", 2)
		filter_root.add_child(glyph)

	rgb_core_scanner = Node2D.new()
	rgb_core_scanner.name = "ArchiveOpticalScanner"
	rgb_core_scanner.position = Vector2(0.0, -38.0)
	stand.add_child(rgb_core_scanner)
	var core_housing := Polygon2D.new()
	core_housing.name = "ArchiveScannerHousing"
	core_housing.polygon = PackedVector2Array(
		[
			Vector2(0.0, -18.0), Vector2(15.0, -9.0), Vector2(15.0, 9.0),
			Vector2(0.0, 18.0), Vector2(-15.0, 9.0), Vector2(-15.0, -9.0),
		]
	)
	core_housing.color = Color(0.35, 0.25, 0.12, 0.98)
	rgb_core_scanner.add_child(core_housing)
	var core_inlay := Polygon2D.new()
	core_inlay.name = "ArchiveScannerInlay"
	core_inlay.polygon = core_housing.polygon
	core_inlay.scale = Vector2(0.72, 0.72)
	core_inlay.color = Color(0.025, 0.035, 0.065, 1.0)
	rgb_core_scanner.add_child(core_inlay)
	rgb_core_outer_ring = Line2D.new()
	rgb_core_outer_ring.name = "ArchiveScannerOuterRing"
	rgb_core_outer_ring.points = _rgb_circle_points(22.0, 36)
	rgb_core_outer_ring.closed = true
	rgb_core_outer_ring.width = 1.7
	rgb_core_outer_ring.default_color = Color(0.65, 0.48, 0.22, 0.72)
	rgb_core_scanner.add_child(rgb_core_outer_ring)
	rgb_core_inner_ring = Line2D.new()
	rgb_core_inner_ring.name = "ArchiveScannerInnerRing"
	rgb_core_inner_ring.points = _rgb_circle_points(12.0, 28)
	rgb_core_inner_ring.closed = true
	rgb_core_inner_ring.width = 1.4
	rgb_core_inner_ring.default_color = Color(0.55, 0.42, 0.86, 0.76)
	rgb_core_scanner.add_child(rgb_core_inner_ring)
	rgb_neutral_core = Polygon2D.new()
	rgb_neutral_core.name = "CombinedNeutralLight"
	rgb_neutral_core.polygon = PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(8.0, 0.0),
		Vector2(0.0, 10.0), Vector2(-8.0, 0.0),
	])
	rgb_neutral_core.color = Color(0.88, 0.85, 0.72, 0.78)
	rgb_neutral_core.visible = false
	rgb_core_scanner.add_child(rgb_neutral_core)

	rgb_filter_caption = Label.new()
	rgb_filter_caption.name = "RGBFilterCaption"
	rgb_filter_caption.position = Vector2(-96.0, 43.0)
	rgb_filter_caption.size = Vector2(192.0, 20.0)
	rgb_filter_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rgb_filter_caption.add_theme_font_size_override("font_size", 9)
	rgb_filter_caption.add_theme_color_override("font_color", Color(0.72, 0.61, 0.40, 0.92))
	stand.add_child(rgb_filter_caption)
	rgb_filter_visuals.append(rgb_filter_caption)

	for filter_id: String in rgb_filter_nodes:
		var flag_id := _rgb_filter_flag(filter_id)
		_set_rgb_filter_active(filter_id, GameState.has_story_flag(flag_id), false)
	_set_rgb_neutral_light(GameState.has_story_flag("library_rgb_puzzle_solved"), false)


func _rgb_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(segments):
		points.append(Vector2.from_angle(TAU * float(index) / float(segments)) * radius)
	return points


func _rgb_filter_flag(item_name: String) -> String:
	match item_name:
		"rgb_red_filter":
			return "library_red_filter_active"
		"rgb_green_filter":
			return "library_green_filter_active"
		"rgb_blue_filter":
			return "library_blue_filter_active"
	return ""


func _set_rgb_filter_active(item_name: String, active: bool, animate: bool = true) -> void:
	var filter_root := rgb_filter_nodes.get(item_name) as Node2D
	if filter_root == null:
		return
	var glass := filter_root.get_node_or_null("JewelGlass") as Polygon2D
	var frame := filter_root.get_node_or_null("BrassFrame") as Polygon2D
	var glow := filter_root.get_node_or_null("ActiveGlow") as Polygon2D
	var highlight := filter_root.get_node_or_null("GlassHighlight") as Line2D
	var beam := rgb_filter_beams.get(item_name) as Line2D
	var base_color := filter_root.get_meta("base_color", Color.WHITE) as Color
	filter_root.set_meta("active", active)
	_refresh_rgb_filter_caption()
	if not active:
		if glass != null:
			glass.visible = false
			glass.modulate = Color.WHITE
			glass.scale = Vector2.ONE
		if frame != null:
			frame.color = Color(0.43, 0.31, 0.15, 0.98)
		if glow != null:
			glow.visible = false
		if highlight != null:
			highlight.visible = false
		if beam != null:
			beam.visible = false
		return
	var active_color := Color(
		base_color.r * 1.22,
		base_color.g * 1.22,
		base_color.b * 1.22,
		0.72
	)
	if glass != null:
		glass.visible = true
		glass.color = active_color
	if not animate:
		if glass != null:
			glass.modulate = Color.WHITE
			glass.scale = Vector2.ONE
		if frame != null:
			frame.color = Color(0.68, 0.50, 0.22, 1.0)
		if glow != null:
			glow.visible = true
		if highlight != null:
			highlight.visible = true
		if beam != null:
			beam.visible = true
			beam.modulate.a = 1.0
		return
	if glass != null:
		glass.modulate.a = 0.0
		glass.scale = Vector2(0.42, 0.42)
	if frame != null:
		frame.color = Color(0.43, 0.31, 0.15, 0.98)
	if glow != null:
		glow.visible = false
	if highlight != null:
		highlight.visible = false
	if beam != null:
		beam.visible = false
	OpticalFxRuntime.launch_jewel(
		self,
		rgb_filter_stand,
		filter_root.position + Vector2(0.0, -74.0),
		filter_root.position,
		active_color,
		0.38,
		_finish_rgb_filter_insertion.bind(item_name)
	)


func _finish_rgb_filter_insertion(item_name: String) -> void:
	var filter_root := rgb_filter_nodes.get(item_name) as Node2D
	if filter_root == null:
		return
	var glass := filter_root.get_node_or_null("JewelGlass") as Polygon2D
	var frame := filter_root.get_node_or_null("BrassFrame") as Polygon2D
	var glow := filter_root.get_node_or_null("ActiveGlow") as Polygon2D
	var highlight := filter_root.get_node_or_null("GlassHighlight") as Line2D
	var beam := rgb_filter_beams.get(item_name) as Line2D
	var base_color := filter_root.get_meta("base_color", Color.WHITE) as Color
	if glass != null:
		glass.visible = true
		glass.modulate.a = 0.0
		glass.scale = Vector2(0.42, 0.42)
		var jewel_tween := create_tween()
		jewel_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		jewel_tween.tween_property(glass, "scale", Vector2.ONE, 0.24)
		jewel_tween.parallel().tween_property(glass, "modulate:a", 1.0, 0.18)
	if frame != null:
		frame.color = Color(0.68, 0.50, 0.22, 1.0)
	if glow != null:
		glow.visible = true
		glow.scale = Vector2(0.45, 0.45)
		var glow_tween := create_tween()
		glow_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		glow_tween.tween_property(glow, "scale", Vector2.ONE, 0.26)
	if highlight != null:
		highlight.visible = true
		highlight.modulate.a = 0.0
		create_tween().tween_property(highlight, "modulate:a", 1.0, 0.20)
	OpticalFxRuntime.pulse_ring(
		self,
		rgb_filter_stand,
		filter_root.position,
		Color(base_color.r * 1.4, base_color.g * 1.4, base_color.b * 1.4, 0.88),
		18.0,
		1.9,
		0.34
	)
	if beam != null:
		OpticalFxRuntime.trace_beam(
			self,
			beam,
			filter_root.position,
			rgb_core_scanner.position,
			Color(base_color.r * 1.5, base_color.g * 1.5, base_color.b * 1.5, 0.92),
			3.2,
			0.30,
			0.08,
			func() -> void:
				OpticalFxRuntime.pulse_ring(
					self,
					rgb_filter_stand,
					rgb_core_scanner.position,
					Color(0.88, 0.82, 0.68, 0.88),
					13.0,
					2.1,
					0.32
				)
				if GameState.has_story_flag("library_rgb_puzzle_solved"):
					_ignite_rgb_neutral_light()
		)


func _set_rgb_neutral_light(active: bool, animate: bool = true) -> void:
	if rgb_neutral_core == null:
		return
	rgb_neutral_core.visible = active
	if not active:
		rgb_neutral_core.modulate.a = 1.0
		rgb_core_scanner.set_meta("igniting", false)
	elif animate:
		rgb_neutral_core.scale = Vector2(0.18, 0.18)
		rgb_neutral_core.modulate.a = 0.0
		rgb_core_scanner.set_meta("igniting", false)
	else:
		rgb_neutral_core.scale = Vector2.ONE
		rgb_neutral_core.modulate.a = 1.0
		rgb_core_outer_ring.default_color = Color(0.88, 0.72, 0.34, 0.92)
		rgb_core_inner_ring.default_color = Color(0.72, 0.58, 0.96, 0.92)
	_refresh_rgb_filter_caption()


func _ignite_rgb_neutral_light() -> void:
	if rgb_neutral_core == null or bool(rgb_core_scanner.get_meta("igniting", false)):
		return
	rgb_core_scanner.set_meta("igniting", true)
	rgb_neutral_core.visible = true
	rgb_neutral_core.scale = Vector2(0.18, 0.18)
	rgb_neutral_core.modulate.a = 0.0
	rgb_core_outer_ring.default_color = Color(0.95, 0.78, 0.38, 0.96)
	rgb_core_inner_ring.default_color = Color(0.72, 0.62, 1.0, 0.96)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(rgb_neutral_core, "scale", Vector2.ONE, 0.36)
	tween.parallel().tween_property(rgb_neutral_core, "modulate:a", 1.0, 0.28)
	OpticalFxRuntime.pulse_ring(
		self,
		rgb_filter_stand,
		rgb_core_scanner.position,
		Color(0.98, 0.88, 0.58, 0.94),
		16.0,
		2.8,
		0.52
	)


func _refresh_rgb_filter_caption() -> void:
	if rgb_filter_caption == null:
		return
	var active_count := 0
	for filter_root_variant: Variant in rgb_filter_nodes.values():
		var filter_root := filter_root_variant as Node2D
		if filter_root != null and bool(filter_root.get_meta("active", false)):
			active_count += 1
	rgb_filter_caption.text = (
		CaseLocale.line("ARCHIVE LIGHT STABLE")
		if active_count == 3
		else "FILTER LOCK  ·  %d / 3" % active_count
	)


func _use_rgb_filter(item_name: String) -> void:
	if GameState.has_story_flag("library_rgb_puzzle_solved"):
		interaction_runtime.present_feedback("All three recovered filters remain seated. Their combined pale light keeps the hidden archive text visible.")
		return
	var slot_info := FILTER_SLOT_INFO.get(item_name, {}) as Dictionary
	if slot_info.is_empty():
		return
	var color_name := str(slot_info["filter"]).capitalize()
	var earned_flag := str(slot_info["earned_flag"])
	var active_flag := str(slot_info["active_flag"])
	if GameState.has_story_flag(active_flag):
		interaction_runtime.present_feedback("The %s filter is already seated and active." % color_name)
		return
	if not GameState.has_story_flag(earned_flag):
		interaction_runtime.present_feedback(
			"This slot is empty. Complete the %s to recover its %s filter."
			% [str(slot_info["challenge_station"]), color_name]
		)
		return
	GameState.set_story_flag(active_flag)
	_set_rgb_filter_active(item_name, true)
	var all_active: bool = (
		GameState.has_story_flag("library_red_filter_active")
		and GameState.has_story_flag("library_green_filter_active")
		and GameState.has_story_flag("library_blue_filter_active")
	)
	if all_active:
		GameState.set_story_flag("library_rgb_puzzle_solved")
		GameState.add_evidence("library_rgb_archive_layer")
		_set_rgb_neutral_light(true)
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
	# Choosing to inspect something is a decision to stand still. A click-move
	# still running underneath the dialogue walks the detective off on its own
	# once the panel closes, which reads as the character moving by itself.
	if player != null and player.has_method("cancel_click_movement"):
		player.call("cancel_click_movement")
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
			if KNOWLEDGE_SHELVES.has(item_name):
				var shelf_info := KNOWLEDGE_SHELVES[item_name] as Dictionary
				_open_library_knowledge(str(shelf_info["knowledge"]))
				return
			if CHALLENGE_STATIONS.has(item_name):
				var station_info := CHALLENGE_STATIONS[item_name] as Dictionary
				var challenge := str(station_info["challenge"])
				var earned_flag := str(station_info["earned_flag"])
				if not GameState.has_story_flag(earned_flag):
					_open_library_challenge(challenge)
					return
				if item_name == "research_desk" and GameState.has_story_flag("library_rgb_puzzle_solved"):
					_collect_archive_record()
					return
				interaction_runtime.present_feedback(
					"%s complete. Take the recovered %s filter to the central optical array."
					% [str(station_info["title"]), str(station_info["filter"]).capitalize()]
				)
				return
			if item_name.begins_with("rgb_"):
				_use_rgb_filter(item_name)
				return
			if item_name == "upper_drawer_cabinet":
				var sealed_archive_feedback := _collect_sealed_lin_decision_archive()
				if not sealed_archive_feedback.is_empty():
					interaction_runtime.present_feedback(sealed_archive_feedback)
					return
			interaction_runtime.present_feedback(str(item["message"]))
			return


func _collect_sealed_lin_decision_archive() -> String:
	if not GameState.has_story_flag("normal_ending"):
		return ""
	if GameState.has_story_flag("sealed_archive_lin_decision_found"):
		return "The violet archive drawer is bare. Dr. Lin's private decision has already been copied."
	GameState.set_story_flag("sealed_archive_lin_decision_found")
	if NoteHud != null:
		NoteHud.add_clue("sealed_archive_lin_decision", {
			"title": "SEALED ARCHIVE III — Dr. Lin's Decision",
			"icon": "icon_book",
			"silent": true,
			"content": "[center][b]SEALED ARCHIVE III — DR. LIN'S PRIVATE DECISION[/b][/center]\n\nDr. Lin's unsigned memorandum confirms that she rejected the Mechanic's request for independent funding and access to the complete Knowledge Engine plans. She had discovered unauthorized maintenance copies, so she prepared a controlled verification at the analysis table to trace the person directing them.\n\nHer final margin note reads: [color=#4a306d]“The Butler is frightened, not secretive. If an emergency order reaches him, verify its routing mark before he acts.”[/color]\n\nDr. Lin expected a forged instruction; she did not expect its isolation field to become lethal. The person who needed her silent also needed her research recognized as his own.",
			"category": "sealed_archive",
		})
	return "One violet archive drawer yields only when you press its hidden brass catch. Inside is a private memorandum in Dr. Lin's hand."


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

	var switch_to_hall := func() -> void:
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
	ArchiveUi.play_hall_transition(switch_to_hall)


func _mg_text(english: String, chinese: String) -> String:
	if CaseLocale != null and CaseLocale.is_chinese():
		return chinese
	return english
