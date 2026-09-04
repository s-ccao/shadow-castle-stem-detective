class_name HallRouteStore
extends RefCounted

## 大厅新手教程路线的存档：一条**人工走出来**的路。
##
## 原来这条路是运行时用 A* 从玩家出生点算到化学室门的。A* 只保证"能走到"，
## 不保证"走得像话"：它会贴着墙角切、绕开看不见的碰撞体、在空旷处走对角线，
## 于是路标指的方向和玩家眼睛看到的通路对不上——这就是方位全错的原因。
##
## 现在改成：开发者模式下亲自走一遍，把走过的点存成这个文件；游戏优先用它。
## 文件不存在时仍然回落到 A*，所以没录制过也不会开天窗。
##
## 存成 JSON 而不是 .tres，是为了这条路能在 diff 里被人眼读懂——它是设计
## 决策，不是二进制资产，改错了要看得出来。

const ROUTE_PATH: String = "res://data/hall_tutorial_route.json"


static func has_route() -> bool:
	return FileAccess.file_exists(ROUTE_PATH)


## 读出这条路。任何一步不对就返回空数组，让调用方回落到 A*——
## 半条路比没有路更糟：玩家会被引到一半然后卡住。
static func load_route() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not FileAccess.file_exists(ROUTE_PATH):
		return points
	var file := FileAccess.open(ROUTE_PATH, FileAccess.READ)
	if file == null:
		return points
	var raw: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("Hall route file is not an object: " + ROUTE_PATH)
		return points
	var listed: Variant = (parsed as Dictionary).get("points", [])
	if not (listed is Array):
		push_warning("Hall route file has no points array: " + ROUTE_PATH)
		return points
	for entry: Variant in listed as Array:
		if not (entry is Array) or (entry as Array).size() != 2:
			push_warning("Hall route point is malformed, ignoring the file")
			return []
		points.append(Vector2(
			float((entry as Array)[0]), float((entry as Array)[1])
		))
	if points.size() < 2:
		return []
	return points


static func save_route(points: Array[Vector2]) -> bool:
	if points.size() < 2:
		return false
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(ROUTE_PATH).get_base_dir()
	)
	var listed: Array = []
	for point: Vector2 in points:
		# 存整数：半个像素的精度对一条脚下的路没有意义，而整数在 diff 里
		# 读起来是坐标，不是浮点噪声。
		listed.append([roundi(point.x), roundi(point.y)])
	var payload: Dictionary = {
		"comment": "Authored in developer mode by walking the Hall. "
			+ "Regenerate with the in-game route recorder, not by hand.",
		"points": listed,
	}
	var file := FileAccess.open(ROUTE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the Hall route to: " + ROUTE_PATH)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


static func clear_route() -> void:
	if FileAccess.file_exists(ROUTE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROUTE_PATH))
