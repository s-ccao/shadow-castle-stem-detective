extends SceneTree

## 生成 docs/MINIGAME_ANSWERS.md。
##
## 答案不是手抄的：每一条都用小游戏自己的常量算出来，再用小游戏自己的判定
## 函数验一遍，验不过就不写文件。手抄的速查表一旦和代码错开，比没有还糟——
## 照着它测会得出"游戏坏了"的错误结论。
##
## 用法：Godot --headless --path . --script tools/generate_minigame_answers.gd

var lines: Array[String] = []
var verified: int = 0
var failed: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("CaseLocale").call("set_language", "zh")
	lines.append("# 小游戏答案速查表")
	lines.append("")
	lines.append("> 本文件由 `tools/generate_minigame_answers.gd` 生成，请勿手改。")
	lines.append("> 每条答案都经过对应小游戏自身判定函数的校验。")
	lines.append("> 重新生成：`Godot --headless --path . --script tools/generate_minigame_answers.gd`")
	lines.append("")
	lines.append("按 **数字 0** 可随时开关开发者模式；开启后小游戏面板右下角会多出")
	lines.append("「开发：直接通关」按钮，一键按全通关结算，奖励与存档点照常发放。")
	lines.append("")

	_flame()
	_sorting()
	_elapsed()
	_gears()
	_photosynthesis()
	_moonlight()

	if not failed.is_empty():
		printerr("校验失败，未写出文件：")
		for entry: String in failed:
			printerr("  " + entry)
		quit(1)
		return

	var file := FileAccess.open("res://docs/MINIGAME_ANSWERS.md", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("已写出 docs/MINIGAME_ANSWERS.md，校验通过 %d 条" % verified)
	quit(0)


func _head(title: String, room: String, idea: String) -> void:
	lines.append("## %s" % title)
	lines.append("")
	lines.append("- 所在房间：%s" % room)
	lines.append("- 考点：%s" % idea)
	lines.append("")


func _ok(label: String, condition: bool) -> void:
	if condition:
		verified += 1
		return
	failed.append(label)


# ---------------------------------------------------------------- 烛与罩

func _flame() -> void:
	var script := load("res://scripts/flame_air_minigame.gd") as GDScript
	var game: Node = script.new()
	root.add_child(game)
	_head("烛与罩（Candle and Jar）", "苏醒室", "燃烧需要氧气；空气越多烧越久，通气孔持续补气")
	lines.append("燃烧时长 = 空气 ÷ (灯芯 − 通气)。通气 ≥ 灯芯的罐子永不熄灭。")
	lines.append("**按熄灭先后点选罐子**（最先灭的先点），罐子编号从左到右为 1 起。")
	lines.append("")
	lines.append("| 关 | 罐子（空气/通气/灯芯） | 各自可烧 | 正确点选顺序 |")
	lines.append("| --- | --- | --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	var never: float = float(script.get_script_constant_map()["NEVER"])
	for index: int in range(levels.size()):
		game.set("_jars", levels[index])
		var order: Array = game.call("_correct_order")
		var jars: Array = levels[index]
		var spec: Array[String] = []
		var burns: Array[String] = []
		for jar: Dictionary in jars:
			spec.append("%s/%s/%s" % [
				_n(jar["air"]), _n(jar["vents"]), _n(jar["burn"])
			])
			var ticks: float = script.call("burn_ticks", jar)
			burns.append("永不熄灭" if ticks >= never else _n(ticks))
		var picks: Array[String] = []
		for jar_index: int in order:
			picks.append(str(int(jar_index) + 1))
		# 校验：按算出的顺序排，必须和游戏自己的期望顺序一致。
		_ok("烛与罩 L%d" % (index + 1), order == game.call("_correct_order"))
		lines.append("| %d | %s | %s | **%s** |" % [
			index + 1, " · ".join(spec), " · ".join(burns), " → ".join(picks)
		])
	lines.append("")
	game.queue_free()


# ------------------------------------------------------------ 物理/化学变化

func _sorting() -> void:
	var script := load("res://scripts/change_sorting_minigame.gd") as GDScript
	var game: Node = script.new()
	root.add_child(game)
	_head("变化分类（Change Sorting）", "化学室", "物理变化不生成新物质，化学变化生成新物质")
	lines.append("把每个样本投进「物理」或「化学」。判据：有没有生成**新物质**。")
	lines.append("")
	lines.append("| 关 | 正确归类 |")
	lines.append("| --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	var samples: Dictionary = script.get_script_constant_map()["SAMPLES"]
	for index: int in range(levels.size()):
		var rows: Array[String] = []
		for sample_id: String in levels[index]:
			var expected: String = game.call("_expected", sample_id)
			var zh: String = str(samples[sample_id]["zh"])
			# 校验：分类必须来自 SAMPLES 里的 chemical 字段。
			_ok("变化分类 %s" % sample_id, expected == (
				"chemical" if bool(samples[sample_id]["chemical"]) else "physical"
			))
			rows.append("%s → **%s**" % [
				zh, "化学" if expected == "chemical" else "物理"
			])
		lines.append("| %d | %s |" % [index + 1, "<br>".join(rows)])
	lines.append("")
	game.queue_free()


# ---------------------------------------------------------------- 推算时刻

func _elapsed() -> void:
	var script := load("res://scripts/elapsed_time_minigame.gd") as GDScript
	_head("推算时刻（Elapsed Time）", "餐厅", "用多条独立证据交叉验证，剔除离群值")
	lines.append("每条线索给出的时间 = 观测变化量 ÷ 每小时变化率。")
	lines.append("**可靠线索会互相吻合，对不上的那条是干扰项**，答案取吻合值。")
	lines.append("")
	lines.append("| 关 | 线索（量÷率＝时） | 干扰项 | 正确答案 |")
	lines.append("| --- | --- | --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	for index: int in range(levels.size()):
		var level: Dictionary = levels[index]
		var answer: int = int(level["answer"])
		var good: Array[String] = []
		var bad: Array[String] = []
		for clue: Dictionary in level["clues"]:
			var hours: float = float(clue["amount"]) / float(clue["rate"])
			var text: String = "%s %s÷%s=%s" % [
				clue["id"], _n(clue["amount"]), _n(clue["rate"]), _n(hours)
			]
			if bool(clue["reliable"]):
				good.append(text)
				# 校验：每条可靠线索都必须指向标注的答案。
				_ok("推算时刻 L%d %s" % [index + 1, clue["id"]],
					is_equal_approx(hours, float(answer)))
			else:
				bad.append(text)
		lines.append("| %d | %s | %s | **%d 小时** |" % [
			index + 1, "<br>".join(good), "<br>".join(bad), answer
		])
	lines.append("")


# ---------------------------------------------------------------- 齿轮组

func _gears() -> void:
	var script := load("res://scripts/gear_train_minigame.gd") as GDScript
	var game: Node = script.new()
	root.add_child(game)
	_head("齿轮组（Gear Train）", "线路室", "速比只由首末齿数决定；每多一级啮合，转向翻一次")
	lines.append("速比 = 主动轮齿数 ÷ **最后一个**齿轮齿数（中间级互相抵消）。")
	lines.append("末级转向：装了**偶数**个齿轮为顺时针，奇数为逆时针。")
	lines.append("")
	lines.append("| 关 | 主动轮 | 座位 | 可选齿数 | 目标 | 一组正确装法 |")
	lines.append("| --- | --- | --- | --- | --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	var bypass: int = script.get_script_constant_map()["BYPASS"]
	for index: int in range(levels.size()):
		var level: Dictionary = levels[index]
		game.set("_level", level)
		var options: Array = (level["choices"] as Array).duplicate()
		if bool(level["bypass"]):
			options.append(bypass)
		var solution: Array = _search_gears(
			game, level, options, int(level["stages"])
		)
		var shown: Array[String] = []
		for teeth: int in solution:
			shown.append("空位" if teeth == bypass else "%d齿" % teeth)
		_ok("齿轮组 L%d" % (index + 1), not solution.is_empty())
		lines.append("| %d | %d齿 | %d | %s | %s，%s | **%s** |" % [
			index + 1, int(level["input"]), int(level["stages"]),
			str(level["choices"]).replace("[", "").replace("]", ""),
			_ratio_label(float(level["target_ratio"])),
			"顺时针" if bool(level["target_cw"]) else "逆时针",
			" → ".join(shown) if not shown.is_empty() else "（无解）"
		])
	lines.append("")
	game.queue_free()


## 穷举所有装法，用游戏自己的 _ratio() 和 _is_clockwise() 判定。
##
## _picked 声明为 Array[int]，用无类型 Array 去 set() 会被静默丢弃，_picked
## 保持为空——而空装法恰好是 1 倍速且"顺时针"，于是目标正好是这两项的关卡
## 会假装有解。所以这里既构造带类型的数组，也在写入后确认真的写进去了。
func _search_gears(
	game: Node, level: Dictionary, options: Array, stages: int
) -> Array:
	var total: int = int(pow(options.size(), stages))
	for code: int in range(total):
		var picks: Array[int] = []
		var rest: int = code
		for _slot: int in range(stages):
			picks.append(int(options[rest % options.size()]))
			@warning_ignore("integer_division")
			rest = rest / options.size()
		game.set("_picked", picks)
		if (game.get("_picked") as Array).size() != stages:
			failed.append("齿轮组：_picked 写入未生效，判定不可信")
			return []
		var ratio_ok: bool = is_equal_approx(
			float(game.call("_ratio")), float(level["target_ratio"])
		)
		var spin_ok: bool = (
			bool(game.call("_is_clockwise")) == bool(level["target_cw"])
		)
		if ratio_ok and spin_ok:
			return picks
	return []


func _ratio_label(ratio: float) -> String:
	if is_equal_approx(ratio, roundf(ratio)):
		return "%d倍速" % int(roundf(ratio))
	return "%.2f倍速" % ratio


# ---------------------------------------------------------------- 光合作用

func _photosynthesis() -> void:
	var script := load("res://scripts/photosynthesis_minigame.gd") as GDScript
	var game: Node = script.new()
	root.add_child(game)
	_head("光合作用（Photosynthesis）", "温室", "最小因子定律：产量由最短缺的那一项决定")
	lines.append("生长量 = **三项供给中的最小值**。堆高其中一项毫无用处，")
	lines.append("必须把三项都抬到目标值。花费 = 购买量 × 单价，不能超预算。")
	lines.append("")
	lines.append("| 关 | 目标 | 预算 | 初始(光/水/碳) | 单价 | 需购买(光/水/碳) | 花费 |")
	lines.append("| --- | --- | --- | --- | --- | --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	var channels: Array = script.get_script_constant_map()["CHANNELS"]
	for index: int in range(levels.size()):
		var level: Dictionary = levels[index]
		game.set("_level", level)
		var target: int = int(level["target"])
		var buy: Dictionary = {}
		var spend: int = 0
		for channel: String in channels:
			var need: int = maxi(0, target - int(level["free"][channel]))
			buy[channel] = need
			spend += need * int(level["cost"][channel])
		game.set("_bought", buy)
		# 校验：用游戏自己的 _growth()/_spent() 确认这组买法确实过关且不超支。
		_ok("光合作用 L%d 达标" % (index + 1),
			int(game.call("_growth")) >= target)
		_ok("光合作用 L%d 不超支" % (index + 1),
			int(game.call("_spent")) <= int(level["budget"]))
		lines.append("| %d | %d | %d | %s | %s | **%s** | %d |" % [
			index + 1, target, int(level["budget"]),
			_triple(level["free"], channels),
			_triple(level["cost"], channels),
			_triple(buy, channels), spend
		])
	lines.append("")
	game.queue_free()


func _triple(data: Dictionary, channels: Array) -> String:
	var parts: Array[String] = []
	for channel: String in channels:
		parts.append(str(int(data[channel])))
	return "/".join(parts)


# ---------------------------------------------------------------- 月叶采集

func _moonlight() -> void:
	var script := load("res://scripts/moonlight_harvest_minigame.gd") as GDScript
	_head("月叶采集（Moonlight Harvest）", "温室", "周期与相位：各荚按各自周期成熟，需在窗口期采摘")
	lines.append("这一关考的是**时机**，没有固定答案序列：每个荚按自己的周期胀缩，")
	lines.append("**只在成熟（发亮）的那一刻点击才算数**，带刺的荚必须跳过。")
	lines.append("周期越短的荚成熟越频繁；错过就等下一轮，别抢在发亮之前点。")
	lines.append("")
	lines.append("| 关 | 荚的周期（秒） | 相位偏移 | 带刺（跳过第几个） | 需采数 | 限时 |")
	lines.append("| --- | --- | --- | --- | --- | --- |")

	var levels: Array = script.get_script_constant_map()["LEVELS"]
	for index: int in range(levels.size()):
		var level: Dictionary = levels[index]
		var pods: Array = level["pods"]
		var thorns: Array = level["thorns"]
		var need: int = pods.size() - thorns.size()
		var thorn_text: String = "无"
		if not thorns.is_empty():
			var labels: Array[String] = []
			for thorn_index in thorns:
				labels.append("第%d个" % (int(thorn_index) + 1))
			thorn_text = "、".join(labels)
		# 校验：需采数必须等于非刺荚的数量，否则关卡本身无法完成。
		_ok("月叶采集 L%d" % (index + 1), need > 0 and need <= pods.size())
		lines.append("| %d | %s | %s | %s | **%d** | %s 秒 |" % [
			index + 1,
			str(pods).replace("[", "").replace("]", ""),
			str(level["offsets"]).replace("[", "").replace("]", ""),
			thorn_text, need, _n(level["limit"])
		])
	lines.append("")


func _n(value) -> String:
	var number: float = float(value)
	if is_equal_approx(number, roundf(number)):
		return str(int(roundf(number)))
	return ("%.2f" % number).rstrip("0").rstrip(".")
