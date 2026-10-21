class_name HallRoutePlanner
extends RefCounted

## The tutorial trail through the Hall: the cheapest walk that keeps to the
## middle of each corridor and turns only where the corridor does.
##
## A shortest path is the wrong line to ask a player to follow. It hugs the
## stone round every bend, so the footprints read as walking into the wall,
## and on a lattice it stair-steps across open floor. Here a node costs more
## the nearer it is to stone, which pulls the search onto corridor
## centrelines; the result is then straightened into long axis-aligned legs
## that never come nearer the stone than the search itself did.
##
## The planner owns no physics. The Hall hands it the walkability lattice it
## already built for the Guardian, so the trail and the Guardian agree on
## where the body fits, and planning costs no collision queries.

## How strongly the search is pulled off the walls. A node beside stone costs
## 1 + 6 = 7x a step; the middle of a 96 px corridor (clearance 3) 1.67x; open
## hall barely more than 1x.
const CENTRE_WEIGHT: float = 6.0
## Corridors an authored walk used stay at their normal cost and every other
## node costs this much more, so a designer's recording chooses the way
## without dictating the wobble of a hand-walked line: the trail leaves the
## recorded corridors only where they are three times the walk. Penalising the
## rest instead of discounting the hint keeps every weight at least 1, which is
## what keeps the straight-line heuristic admissible.
const OFF_HINT_PENALTY: float = 3.0
const HINT_RADIUS: float = 48.0
## A straightened leg may come this many nodes nearer the stone than the
## planned walk did at the same place. One node (16 px) is what lets a leg
## ignore a half-node wobble in a corridor's centre without letting it slide
## along a wall.
const STRAIGHTEN_TOLERANCE: int = 1
## Past this clearance open floor is open floor: a leg crossing a wide hall
## does not have to stay as far from the walls as the search happened to.
const STRAIGHTEN_CLEARANCE_CAP: int = 4
## How far, in nodes, one straightened leg may reach along the planned walk.
const STRAIGHTEN_WINDOW: int = 48
## How far from the walk the clearance it kept is remembered, in nodes.
const STRAIGHTEN_BAND: int = 10
## How far an endpoint may slide to reach a node, in nodes.
const ENDPOINT_SEARCH_RADIUS: int = 4

var spacing: float = 16.0
var columns: int = 0
var rows: int = 0

var _open := PackedByteArray()
var _east := PackedByteArray()
var _south := PackedByteArray()
var _clearance := PackedInt32Array()
var _hinted := PackedByteArray()
var _has_hint := false
var _graph := AStar2D.new()


## `node_open(index: Vector2i) -> bool` says whether the body may stand on a
## lattice node; `step_open(from: Vector2i, to: Vector2i) -> bool` whether it
## may walk between two orthogonal neighbours.
func build(
	lattice_spacing: float,
	lattice_columns: int,
	lattice_rows: int,
	node_open: Callable,
	step_open: Callable
) -> void:
	spacing = lattice_spacing
	columns = lattice_columns
	rows = lattice_rows
	var count := columns * rows
	# Packed arrays are values: resizing one through a loop variable would
	# resize a copy, so each member is sized explicitly.
	_open.resize(count)
	_open.fill(0)
	_east.resize(count)
	_east.fill(0)
	_south.resize(count)
	_south.fill(0)
	_hinted.resize(count)
	_hinted.fill(0)
	_has_hint = false
	for row: int in range(rows):
		for column: int in range(columns):
			if node_open.call(Vector2i(column, row)):
				_open[row * columns + column] = 1
	for row: int in range(rows):
		for column: int in range(columns):
			var id := row * columns + column
			if _open[id] == 0:
				continue
			var here := Vector2i(column, row)
			if column + 1 < columns and _open[id + 1] == 1 and step_open.call(here, here + Vector2i(1, 0)):
				_east[id] = 1
			if row + 1 < rows and _open[id + columns] == 1 and step_open.call(here, here + Vector2i(0, 1)):
				_south[id] = 1
	_compute_clearance()
	_rebuild_graph()


func is_built() -> bool:
	return columns > 0 and rows > 0 and _open.size() == columns * rows


func is_open(index: Vector2i) -> bool:
	return _in_lattice(index) and _open[index.y * columns + index.x] == 1


func _in_lattice(index: Vector2i) -> bool:
	return index.x >= 0 and index.y >= 0 and index.x < columns and index.y < rows


## Distance from a node to the nearest node the body cannot stand on, in
## nodes (8-neighbour steps). Zero for blocked nodes.
func clearance_at(index: Vector2i) -> int:
	if not is_open(index):
		return 0
	return _clearance[index.y * columns + index.x]


func point_of(index: Vector2i) -> Vector2:
	return Vector2(index) * spacing


func index_of(position_on_floor: Vector2) -> Vector2i:
	return Vector2i(roundi(position_on_floor.x / spacing), roundi(position_on_floor.y / spacing))


## Bias the search toward the corridors an authored walk used. Segments the
## body could not walk are ignored: a hand recording can begin before the
## player was placed, and that first "step" is a teleport through the stone,
## not a corridor anyone used.
func set_corridor_hint(points: Array[Vector2], segment_open: Callable) -> void:
	_hinted.fill(0)
	_has_hint = false
	var reach := ceili(HINT_RADIUS / spacing)
	for index: int in range(points.size() - 1):
		var from_point := points[index]
		var to_point := points[index + 1]
		if from_point.is_equal_approx(to_point) or not segment_open.call(from_point, to_point):
			continue
		var low := index_of(Vector2(minf(from_point.x, to_point.x), minf(from_point.y, to_point.y)))
		var high := index_of(Vector2(maxf(from_point.x, to_point.x), maxf(from_point.y, to_point.y)))
		for row: int in range(maxi(low.y - reach, 0), mini(high.y + reach, rows - 1) + 1):
			for column: int in range(maxi(low.x - reach, 0), mini(high.x + reach, columns - 1) + 1):
				var id := row * columns + column
				if _open[id] == 0 or _hinted[id] == 1:
					continue
				var node := point_of(Vector2i(column, row))
				var closest := Geometry2D.get_closest_point_to_segment(node, from_point, to_point)
				if node.distance_to(closest) <= HINT_RADIUS:
					_hinted[id] = 1
					_has_hint = true
	_apply_weights()


func has_corridor_hint() -> bool:
	return _has_hint


## The walk from `start` to the cheapest of `goals`, as world points: the node
## the walk leaves from, every corner, then the goal node. `goal_costs` adds a
## per-goal preference in pixels. Empty when no goal can be reached.
func plan(
	start: Vector2,
	goals: Array[Vector2],
	goal_costs: Array[float],
	segment_open: Callable
) -> Array[Vector2]:
	var walk: Array[Vector2] = []
	if not is_built() or goals.is_empty():
		return walk
	var start_id := _nearest_node(start, segment_open)
	if start_id < 0:
		return walk
	var best_path := PackedInt64Array()
	var best_cost := INF
	for goal_index: int in range(goals.size()):
		var goal_node := index_of(goals[goal_index])
		if not is_open(goal_node):
			continue
		var goal_id := goal_node.y * columns + goal_node.x
		var path: PackedInt64Array = (
			PackedInt64Array([start_id]) if goal_id == start_id
			else _graph.get_id_path(start_id, goal_id)
		)
		if path.is_empty():
			continue
		var preference := goal_costs[goal_index] if goal_index < goal_costs.size() else 0.0
		var cost := _path_cost(path) + preference
		if cost < best_cost:
			best_cost = cost
			best_path = path
	if best_path.is_empty():
		return walk
	for id: int in _straighten(best_path):
		walk.append(point_of(Vector2i(id % columns, id / columns)))
	return walk


func _compute_clearance() -> void:
	var count := columns * rows
	_clearance.resize(count)
	var queue := PackedInt32Array()
	for id: int in range(count):
		if _open[id] == 0:
			_clearance[id] = 0
			queue.append(id)
		else:
			_clearance[id] = 1 << 30
	# Beyond the map edge is as solid as stone.
	for id: int in range(count):
		if _open[id] == 1 and _is_border(id):
			_clearance[id] = 1
			queue.append(id)
	var head := 0
	while head < queue.size():
		var id := queue[head]
		head += 1
		var column := id % columns
		var row := id / columns
		var next_value := _clearance[id] + 1
		for offset_y: int in range(-1, 2):
			var neighbour_row := row + offset_y
			if neighbour_row < 0 or neighbour_row >= rows:
				continue
			for offset_x: int in range(-1, 2):
				var neighbour_column := column + offset_x
				if neighbour_column < 0 or neighbour_column >= columns:
					continue
				var neighbour := neighbour_row * columns + neighbour_column
				if _clearance[neighbour] > next_value:
					_clearance[neighbour] = next_value
					queue.append(neighbour)


func _is_border(id: int) -> bool:
	var column := id % columns
	var row := id / columns
	return column == 0 or row == 0 or column == columns - 1 or row == rows - 1


func _rebuild_graph() -> void:
	_graph.clear()
	_graph.reserve_space(columns * rows)
	for id: int in range(columns * rows):
		if _open[id] == 1:
			_graph.add_point(id, point_of(Vector2i(id % columns, id / columns)), _weight(id))
	for id: int in range(columns * rows):
		if _east[id] == 1:
			_graph.connect_points(id, id + 1)
		if _south[id] == 1:
			_graph.connect_points(id, id + columns)


func _apply_weights() -> void:
	for id: int in range(columns * rows):
		if _open[id] == 1:
			_graph.set_point_weight_scale(id, _weight(id))


func _weight(id: int) -> float:
	var clearance := float(maxi(_clearance[id], 1))
	var weight := 1.0 + CENTRE_WEIGHT / (clearance * clearance)
	if _has_hint and _hinted[id] == 0:
		weight *= OFF_HINT_PENALTY
	return weight


func _path_cost(path: PackedInt64Array) -> float:
	var cost := 0.0
	for index: int in range(1, path.size()):
		cost += spacing * _weight(int(path[index]))
	return cost


## The open node nearest `position_on_floor` that the body can walk to in a
## straight line, or -1.
func _nearest_node(position_on_floor: Vector2, segment_open: Callable) -> int:
	var centre := index_of(position_on_floor)
	var candidates: Array[Vector2i] = []
	for offset_y: int in range(-ENDPOINT_SEARCH_RADIUS, ENDPOINT_SEARCH_RADIUS + 1):
		for offset_x: int in range(-ENDPOINT_SEARCH_RADIUS, ENDPOINT_SEARCH_RADIUS + 1):
			var candidate := centre + Vector2i(offset_x, offset_y)
			if is_open(candidate):
				candidates.append(candidate)
	candidates.sort_custom(func(first: Vector2i, second: Vector2i) -> bool:
		var first_distance := point_of(first).distance_squared_to(position_on_floor)
		return first_distance < point_of(second).distance_squared_to(position_on_floor)
	)
	for candidate: Vector2i in candidates:
		if segment_open.call(position_on_floor, point_of(candidate)):
			return candidate.y * columns + candidate.x
	return -1


## Collapse the walk into the fewest axis-aligned legs that keep its distance
## from the stone, scanning ahead for the furthest node a straight or
## single-corner leg can reach.
func _straighten(path: PackedInt64Array) -> PackedInt64Array:
	var corners := PackedInt64Array([path[0]])
	if path.size() < 2:
		return corners
	var required := _required_clearance(path)
	var last := path.size() - 1
	var cursor := 0
	while cursor < last:
		var chosen := cursor + 1
		var link := PackedInt64Array([path[cursor + 1]])
		for candidate: int in range(mini(last, cursor + STRAIGHTEN_WINDOW), cursor + 1, -1):
			var attempt := _orthogonal_link(int(path[cursor]), int(path[candidate]), required)
			if not attempt.is_empty():
				chosen = candidate
				link = attempt
				break
		for id: int in link:
			if corners[corners.size() - 1] != id:
				corners.append(id)
		cursor = chosen
	return _drop_collinear(corners)


## How near the stone each node near the walk may be: the clearance the walk
## kept at its nearest node, less the tolerance. Nodes further from the walk
## than the band only have to clear the cap.
func _required_clearance(path: PackedInt64Array) -> Dictionary:
	var required := {}
	var distance := {}
	var frontier: Array[int] = []
	for id: int in path:
		if required.has(id):
			continue
		required[id] = maxi(mini(_clearance[id], STRAIGHTEN_CLEARANCE_CAP) - STRAIGHTEN_TOLERANCE, 1)
		distance[id] = 0
		frontier.append(id)
	var head := 0
	while head < frontier.size():
		var id := frontier[head]
		head += 1
		var reached: int = distance[id]
		if reached >= STRAIGHTEN_BAND:
			continue
		var column := id % columns
		var row := id / columns
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var neighbour_cell := Vector2i(column, row) + offset
			if not _in_lattice(neighbour_cell):
				continue
			var neighbour := neighbour_cell.y * columns + neighbour_cell.x
			if _open[neighbour] == 0 or required.has(neighbour):
				continue
			required[neighbour] = required[id]
			distance[neighbour] = reached + 1
			frontier.append(neighbour)
	return required


## A straight leg, or two legs meeting at one corner, from one node of the walk
## to another; empty when neither keeps the clearance the walk kept.
func _orthogonal_link(from_id: int, to_id: int, required: Dictionary) -> PackedInt64Array:
	var link := PackedInt64Array()
	var from_column := from_id % columns
	var from_row := from_id / columns
	var to_column := to_id % columns
	var to_row := to_id / columns
	if from_column == to_column or from_row == to_row:
		if _run_clear(from_id, to_id, required):
			link.append(to_id)
		return link
	var best_corner := -1
	# Turn where there is more room: a corner pressed into the stone reads as the
	# trail clipping it.
	for corner: int in [from_row * columns + to_column, to_row * columns + from_column]:
		if not (_run_clear(from_id, corner, required) and _run_clear(corner, to_id, required)):
			continue
		if best_corner < 0 or _clearance[corner] > _clearance[best_corner]:
			best_corner = corner
	if best_corner >= 0:
		link.append(best_corner)
		link.append(to_id)
	return link


func _run_clear(from_id: int, to_id: int, required: Dictionary) -> bool:
	if from_id == to_id:
		return true
	var step := 0
	if from_id / columns == to_id / columns:
		step = 1 if to_id > from_id else -1
	elif from_id % columns == to_id % columns:
		step = columns if to_id > from_id else -columns
	else:
		return false
	var id := from_id
	while id != to_id:
		var next := id + step
		if not _step_open(id, next):
			return false
		if _clearance[next] < int(required.get(next, STRAIGHTEN_CLEARANCE_CAP - STRAIGHTEN_TOLERANCE)):
			return false
		id = next
	return true


func _step_open(from_id: int, to_id: int) -> bool:
	var delta := to_id - from_id
	if delta == 1:
		return _east[from_id] == 1
	if delta == -1:
		return _east[to_id] == 1
	if delta == columns:
		return _south[from_id] == 1
	if delta == -columns:
		return _south[to_id] == 1
	return false


func _drop_collinear(corners: PackedInt64Array) -> PackedInt64Array:
	if corners.size() < 3:
		return corners
	var kept := PackedInt64Array([corners[0]])
	for index: int in range(1, corners.size() - 1):
		var previous := int(kept[kept.size() - 1])
		var here := int(corners[index])
		var following := int(corners[index + 1])
		var same_row := previous / columns == here / columns and here / columns == following / columns
		var same_column := previous % columns == here % columns and here % columns == following % columns
		if not (same_row or same_column):
			kept.append(here)
	kept.append(corners[corners.size() - 1])
	return kept
