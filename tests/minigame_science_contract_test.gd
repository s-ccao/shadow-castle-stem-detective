extends SceneTree

## 四个新小游戏的科学契约。
##
## 这些小游戏的画面都由数据驱动，而数据一旦和它要教的规律脱节，画面就会理直
## 气壮地教错东西——而且不会崩、不会报错，只会静静地骗人。所以这里断言的不是
## 代码跑不跑得起来，而是**每份数据仍然说着它该说的话**：
##
##   · 变化分拣的"颜色即物质"编码，必须能反推出作者标注的化学/物理；
##   · 光合平衡的每一关，必须真的存在一种买得起的分配方式；
##   · 齿轮传动的速比，必须只由首末两个齿轮决定；
##   · 时间推演的可靠线索必须一致，而说谎的那条必须落在选项里；
##   · 烛火关内不能出现并列时长，否则失败提示里"它先灭"会变成不严格的说法。
##
## 全部是纯数据断言，不建场景、不碰 UI，所以跑得快也不会因为布局改动而假红。

const FLAME := preload("res://scripts/flame_air_minigame.gd")
const PHOTO := preload("res://scripts/photosynthesis_minigame.gd")
const SORTING := preload("res://scripts/change_sorting_minigame.gd")
const GEARS := preload("res://scripts/gear_train_minigame.gd")
const TIMELINE := preload("res://scripts/elapsed_time_minigame.gd")
const DISH := preload("res://scripts/sample_dish_view.gd")

## 样本皿视图画得出来的纹理。数据里出现别的纹理不会报错，只会画不出东西，
## 所以必须在这里挡住。
const DRAWABLE_TEXTURES: Array[String] = [
	"liquid", "solid", "grains", "dissolved", "cling",
	"pieces", "fibre", "coil", "bar", "gas", "glow",
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_sorting()
	_check_photosynthesis()
	_check_gears()
	_check_timeline()
	_check_flame()
	_finish()


## 变化分拣：编码就是判据。
##
## "封盘之后有没有出现新颜色"必须逐条等价于作者标注的 chemical。这一条塌了，
## 亮起来的色标就会指着物理变化说它是化学变化——而那枚色标是玩家唯一的依据。
func _check_sorting() -> void:
	var samples: Dictionary = SORTING.SAMPLES
	var palette: Dictionary = DISH.SUBSTANCE
	for id: String in samples:
		var sample: Dictionary = samples[id]
		_expect(
			sample.has("before") and sample.has("after"),
			"sorting sample %s carries a before and an after" % id
		)
		if not (sample.has("before") and sample.has("after")):
			continue
		var before: Array = sample["before"]
		var after: Array = sample["after"]
		_expect(
			not before.is_empty() and not after.is_empty(),
			"sorting sample %s draws something in both states" % id
		)
		for entry: String in (before + after):
			var key: String = entry.get_slice(":", 0)
			var texture: String = entry.get_slice(":", 1)
			_expect(
				palette.has(key),
				"sorting sample %s uses substance '%s', which the palette defines" % [id, key]
			)
			_expect(
				DRAWABLE_TEXTURES.has(texture),
				"sorting sample %s uses texture '%s', which the dish can draw" % [id, texture]
			)
		# glow 是反应的现象不是产物，不算新物质——热不是被造出来的东西。
		var had := {}
		for entry: String in before:
			had[entry.get_slice(":", 0)] = true
		var produced_new: bool = false
		for entry: String in after:
			if entry.get_slice(":", 1) == "glow":
				continue
			if not had.has(entry.get_slice(":", 0)):
				produced_new = true
		_expect(
			produced_new == bool(sample["chemical"]),
			"sorting sample %s: a new colour appears exactly when a new substance does" % id
		)

	for level: int in range(SORTING.LEVELS.size()):
		var ids: Array = SORTING.LEVELS[level]
		var chemical: int = 0
		for id: String in ids:
			_expect(
				samples.has(id),
				"sorting stage %d lists a sample that exists (%s)" % [level + 1, id]
			)
			if samples.has(id) and bool(samples[id]["chemical"]):
				chemical += 1
		# 一整盘同类的话，不用理解也能全选一边过关。
		_expect(
			chemical > 0 and chemical < ids.size(),
			"sorting stage %d mixes both categories" % (level + 1)
		)


## 光合平衡：每一关都得真的解得开。
##
## 生长值等于三项供给里最小的那一项，所以关卡是不是可解不能靠眼看，得把预算
## 内的所有分配都试一遍。
func _check_photosynthesis() -> void:
	var channels: Array = PHOTO.CHANNELS
	for level_index: int in range(PHOTO.LEVELS.size()):
		var level: Dictionary = PHOTO.LEVELS[level_index]
		var budget: int = int(level["budget"])
		var target: int = int(level["target"])
		var solvable: bool = false
		var caps: Array[int] = []
		for channel: String in channels:
			caps.append(int(level["cap"][channel]) - int(level["free"][channel]))
		for a: int in range(maxi(caps[0], 0) + 1):
			for b: int in range(maxi(caps[1], 0) + 1):
				for c: int in range(maxi(caps[2], 0) + 1):
					var buy: Array[int] = [a, b, c]
					var spent: int = 0
					var lowest: int = 99999
					for slot: int in range(3):
						spent += buy[slot] * int(level["cost"][channels[slot]])
						lowest = mini(
							lowest, int(level["free"][channels[slot]]) + buy[slot]
						)
					if spent <= budget and lowest >= target:
						solvable = true
		_expect(
			solvable,
			"photosynthesis stage %d can reach its target inside the ration" % (level_index + 1)
		)


## 齿轮传动：速比只由首末两个齿轮决定。
##
## 这一关的全部考点就是"中间加一个惰轮不改变速比"。如果链式相乘算出来的结果
## 和 N₀/N_last 对不上，那画面演的和题目教的就是两回事。
func _check_gears() -> void:
	for level_index: int in range(GEARS.LEVELS.size()):
		var level: Dictionary = GEARS.LEVELS[level_index]
		var input_teeth: int = int(level["input"])
		var seats: int = int(level["stages"])
		var options: Array = (level["choices"] as Array).duplicate()
		if bool(level.get("bypass", false)):
			options.append(GEARS.BYPASS)
		var solvable: bool = false
		for combo: Array in _combinations(options, seats):
			var driver: float = float(input_teeth)
			var ratio: float = 1.0
			var meshed: int = 0
			var last: int = input_teeth
			for teeth: int in combo:
				if teeth == GEARS.BYPASS:
					continue
				meshed += 1
				ratio *= driver / float(teeth)
				driver = float(teeth)
				last = teeth
			if meshed == 0:
				continue
			# 链式相乘必须望远镜式地塌成 N₀/N_last。
			_expect(
				is_equal_approx(ratio, float(input_teeth) / float(last)),
				"gear stage %d: only the first and last gear set the ratio" % (level_index + 1)
			)
			if (
				is_equal_approx(ratio, float(level["target_ratio"]))
				and (meshed % 2 == 0) == bool(level["target_cw"])
			):
				solvable = true
		_expect(
			solvable,
			"gear stage %d has a train the judge accepts" % (level_index + 1)
		)


## 时间推演：可靠线索必须一致，说谎的那条必须够得着。
##
## 干扰项只放整数小时。说谎那条如果算出小数，它的值就进不了选项，玩家根本
## 没机会掉进陷阱——那一关唯一的考点就空了。
func _check_timeline() -> void:
	for level_index: int in range(TIMELINE.LEVELS.size()):
		var level: Dictionary = TIMELINE.LEVELS[level_index]
		var answer: int = int(level["answer"])
		var liars: int = 0
		for clue: Dictionary in level["clues"]:
			var rate: float = float(clue["rate"])
			_expect(
				not is_zero_approx(rate),
				"timeline stage %d: every clue changes at some rate" % (level_index + 1)
			)
			if is_zero_approx(rate):
				continue
			var hours: float = float(clue["amount"]) / rate
			if bool(clue["reliable"]):
				_expect(
					is_equal_approx(hours, float(answer)),
					"timeline stage %d: reliable clue %s agrees with the answer"
						% [level_index + 1, str(clue["id"])]
				)
				continue
			liars += 1
			_expect(
				is_equal_approx(hours, roundf(hours)) and roundf(hours) > 0.0,
				"timeline stage %d: the liar reads a whole number of hours"
					% (level_index + 1)
			)
			_expect(
				not is_equal_approx(hours, float(answer)),
				"timeline stage %d: the liar disagrees with the answer" % (level_index + 1)
			)
		_expect(
			liars >= 1,
			"timeline stage %d contains a clue to reject" % (level_index + 1)
		)


## 烛火：关内不能有并列的燃烧时长。
##
## 失败提示会指名"这一位该是那只，它只能烧 X，你放的那只能烧 Y"。两只时长
## 相等的话这句话就不成立了，而且正确顺序也不再唯一。
func _check_flame() -> void:
	for level_index: int in range(FLAME.LEVELS.size()):
		var jars: Array = FLAME.LEVELS[level_index]
		var seen: Array[float] = []
		for jar: Dictionary in jars:
			var ticks: float = FLAME.burn_ticks(jar)
			for other: float in seen:
				_expect(
					not is_equal_approx(ticks, other),
					"flame stage %d: no two jars burn for the same time"
						% (level_index + 1)
				)
			seen.append(ticks)


## seats 个座位、每位从 options 里选一个的全部组合。
func _combinations(options: Array, seats: int) -> Array:
	var built: Array = [[]]
	for seat: int in range(seats):
		var grown: Array = []
		for partial: Array in built:
			for option: Variant in options:
				var next: Array = partial.duplicate()
				next.append(int(option))
				grown.append(next)
		built = grown
	return built


func _expect(condition: bool, description: String) -> void:
	if condition:
		return
	if failures.has(description):
		return
	failures.append(description)
	printerr("FAIL: " + description)


func _finish() -> void:
	if failures.is_empty():
		print("minigame_science_contract_test: PASS")
		quit(0)
		return
	printerr(
		"minigame_science_contract_test: FAIL (%d assertion(s))" % failures.size()
	)
	quit(1)
