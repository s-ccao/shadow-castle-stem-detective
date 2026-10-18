class_name ChemistryCaseState
extends RefCounted

const PREFIX := "chemistry_case_"
const HYPOTHESES: Array[String] = ["blood", "dye", "reaction"]
const NOTE_ID := "chemistry_room_note"

var state: Node


func _init(game_state: Node) -> void:
	state = game_state


func has(step: String) -> bool:
	return state.has_story_flag(PREFIX + step)


func _mark(step: String) -> void:
	if not has(step):
		state.set_story_flag(PREFIX + step)


func restore_legacy() -> void:
	# The finale already consumes this evidence ID. Never revoke old progress.
	if state.has_evidence("fake_red_stain") and not has("confirmed"):
		for step: String in ["observed", "control", "reaction", "confirmed", "legacy"]:
			_mark(step)
		if hypothesis().is_empty():
			choose_hypothesis("reaction")


func observe() -> void:
	_mark("observed")


func hypothesis() -> String:
	for id: String in HYPOTHESES:
		if has("hypothesis_" + id):
			return id
	return ""


func choose_hypothesis(id: String) -> bool:
	if not has("observed") or not HYPOTHESES.has(id):
		return false
	if not hypothesis().is_empty() and hypothesis() != id:
		_mark("revised")
	for option: String in HYPOTHESES:
		state.set_story_flag(PREFIX + "hypothesis_" + option, option == id)
	return true


func can_compare() -> bool:
	return (
		has("observed") and not hypothesis().is_empty()
		and state.has_story_flag("mrs_lin_lab_note_seen")
		and state.has_story_flag("chemistry_change_sorted")
	)


func run_comparison(id: String) -> bool:
	if not can_compare() or not ["control", "reaction"].has(id):
		return false
	if id == "reaction" and not has("control"):
		return false
	_mark(id)
	return true


func results_ready() -> bool:
	return has("control") and has("reaction")


func interview_complete() -> bool:
	return state.has_story_flag("chemistry_butler_interviewed")


func confirm() -> bool:
	if not results_ready() or hypothesis() != "reaction":
		return false
	_mark("confirmed")
	state.add_evidence("fake_red_stain")
	return true


func record_statement() -> void:
	_mark("statement")
	state.set_story_flag("butler_challenge_given")


func present(evidence_id: String, statement_id: String) -> String:
	if not has("statement"):
		return "missing_statement"
	if evidence_id == "glass" and has("observed"):
		return "corroborates_glass" if statement_id == "glass" else "wrong_link"
	if evidence_id != "comparison" or not has("confirmed"):
		return "missing_report"
	if statement_id != "supplies":
		return "wrong_link"
	_mark("linked")
	return "linked"


func finish_interview() -> bool:
	if not has("confirmed") or not has("linked"):
		return false
	# This is the original reward flag, including saves made before this case.
	if not state.has_story_flag("butler_challenge_complete"):
		state.set_story_flag("butler_challenge_complete")
		state.add_reputation(10)
	state.set_story_flag("chemistry_butler_interviewed")
	return true


static func text(english: String, chinese: String, language: String = "") -> String:
	var zh := language == "zh" if not language.is_empty() else CaseLocale.is_chinese()
	return chinese if zh else english


static func hypothesis_name(id: String, language: String = "") -> String:
	match id:
		"blood":
			return text("Blood explains the red", "血液导致红色", language)
		"dye":
			return text("Spilled dye; no reaction", "染料泼洒；没有反应", language)
		"reaction":
			return text("An indicator reaction", "指示剂发生反应", language)
	return text("Not proposed yet", "尚未提出", language)


func facts(language: String = "") -> String:
	var body := text("No observations filed.", "尚未记录观察。", language)
	if has("observed"):
		body = text(
			"Red liquid by the table. White powder and broken glass nearby. A vial is among the traces. These are observations, not proof of a wound or staging.",
			"桌边有红色液体，附近有白色粉末、碎玻璃和小瓶。这些是观察，不是受伤或伪造现场的证明。", language)
	if has("control"):
		body += "\n\n" + text(
			"CONTROL: separate indicator and cleaner samples do not show the matching red.",
			"对照：分开的指示剂和清洁剂样本没有呈现相同红色。", language)
	if has("reaction"):
		body += "\n\n" + text(
			"COMPARISON: indicator + powder gives the same red response as indicator + the reference cleaner in Lin's protocol.",
			"比较：指示剂加粉末，与林女士方案中指示剂加清洁剂的红色反应一致。", language)
	if has("legacy"):
		body += "\n\n" + text("Analysis retained from your earlier case record.", "分析结果沿用之前的案件记录。", language)
	return body


func hypothesis_review(language: String = "") -> String:
	var body := hypothesis_name(hypothesis(), language)
	if has("revised"):
		body += text(" (revised)", "（已修订）", language)
	if results_ready() and has("confirmed"):
		body += "\n\n" + text(
			"Blood — NOT SUPPORTED: not needed to explain the colour; appearance is not a blood test.\nDye without reaction — CONTRADICTED: cannot explain colour appearing only after combination.\nReaction — SUPPORTED by the comparison.",
			"血液——缺乏支持：解释颜色不需要血液；观察外观并非血液检测。\n无反应的染料——与结果矛盾：无法解释混合后才出现的颜色。\n反应——得到比较实验支持。", language)
	elif results_ready():
		body += "\n\n" + text(
			"Compare the separate samples with the combinations. Does this proposal explain when the red colour appears? A colour match alone cannot identify a person or establish that blood is absent.",
			"把分开的样本与混合结果对照：这个假设能解释红色在什么时候出现吗？仅凭颜色相同，不能确定人物身份，也不能确认是否存在血液。", language)
	body += "\n\n" + text("Revise freely at the stain or comparison desk. No items or reputation are lost.", "可在红渍或比较台自由修订，不损失物品或声望。", language)
	return body


func conclusion(language: String = "") -> String:
	if not has("confirmed"):
		return text("None yet. Compare the samples, then file a supported explanation.", "暂无。先比较样本，再归档有依据的解释。", language)
	var body := text(
		"An indicator–cleaner reaction accounts for the red colour. Red alone is not proof of injury. This comparison is not a biological blood test and does not identify who spilled it or why.",
		"指示剂与清洁剂的反应可以解释红色。红色本身不能证明受伤。这不是生物血液检测，也不能确定谁泼洒了液体或其目的。", language)
	if state.has_story_flag("chemistry_butler_interviewed"):
		body += "\n\n" + text(
			"FOLLOW-UP RECORDED: the chemical report is relevant to the Butler's cleaning-supply duties. His account directs us toward the greenhouse and the Service Passage, not a verdict on guilt.",
			"已记录追问：化学报告与管家的清洁用品职责有关。他的证词指向温室和服务通道，并不构成定罪。", language)
	return body


func notebook_body(language: String) -> String:
	return (
		"[b]" + text("FACTS / OBSERVATIONS", "事实／观察", language) + "[/b]\n" + facts(language)
		+ "\n\n[b]" + text("HYPOTHESES — REVISABLE", "假设——可以修订", language) + "[/b]\n" + hypothesis_review(language)
		+ "\n\n[b]" + text("CONFIRMED CONCLUSIONS", "已确认结论", language) + "[/b]\n" + conclusion(language)
		+ ("\n\n[b]" + text("WITNESS ACCOUNT (not independently verified)", "证人陈述（尚未独立核实）", language)
			+ "[/b]\n" + text(
				"Butler: I handle cleaning supplies and part of Dining Hall service. I heard glass break in this room when the lights went out.",
				"管家：我管理清洁用品并负责部分餐厅服务。熄灯那晚，我听见这间房里玻璃破碎的声音。", language)
			if has("statement") else "")
		+ ("\n\n" + text(
			"Follow-up: he confirms his cleaning-supply duties; quick, heavy footsteps headed toward the greenhouse. The Service Passage should have been closed after service. Red service cloth is common uniform material, not his alone.",
			"追问：他确认自己管理清洁用品；急促沉重的脚步声朝温室去了。服务结束后，服务通道本应关闭。红色服务制服布料并非他独有。", language)
			if state.has_story_flag("chemistry_butler_interviewed") else "")
	)


func journal_entry() -> Dictionary:
	return {
		"title": "Red Stain Case",
		"title_zh": "红渍调查",
		"icon": "icon_note",
		"category": "investigation",
		"room_id": "chemistry_room",
		"observed_detail": "Red liquid, white powder, broken glass, and a vial.",
		"observed_detail_zh": "红色液体、白色粉末、碎玻璃和一个小瓶。",
		"silent": true,
		"content": notebook_body("en"),
		"content_zh": notebook_body("zh"),
	}
