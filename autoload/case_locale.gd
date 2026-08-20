extends Node

## CaseLocale keeps the player-facing language choice separate from a case save.
## The small Interface is intentionally limited to text lookup and preference changes;
## individual screens refresh themselves when locale_changed is emitted.

signal locale_changed(language: String)

const PREFERENCE_PATH := "user://shadow_castle_preferences.cfg"
const ENGLISH := "en"
const CHINESE := "zh"

var _language := ENGLISH

const TEXT: Dictionary = {
	"menu.new_case": {"en": "New Case", "zh": "新建案件"},
	"menu.continue": {"en": "Continue", "zh": "继续案件"},
	"menu.settings": {"en": "Settings", "zh": "设置"},
	"menu.language": {"en": "Language", "zh": "语言"},
	"menu.quit": {"en": "Quit", "zh": "退出"},
	"menu.close": {"en": "Close", "zh": "关闭"},
	"menu.settings_title": {"en": "SETTINGS", "zh": "设置"},
	"menu.settings_body": {
		"en": "Move — WASD or click the floor\nInvestigate — E\nEvidence — B   ·   Notes — K   ·   Objectives — O\nHubs — Tab bag   ·   I keys   ·   U map\nClose a panel — Esc",
		"zh": "移动 — WASD 或点击地面\n调查 — E\n证物 — B   ·   笔记 — K   ·   目标 — O\n工具栏 — Tab 背包   ·   I 钥匙   ·   U 地图\n关闭面板 — Esc",
	},
	"menu.guidance_on": {"en": "FIELD PROMPTS: ON", "zh": "字段提示：开启"},
	"menu.guidance_off": {"en": "FIELD PROMPTS: OFF", "zh": "字段提示：关闭"},
	"menu.language_title": {"en": "CASE LANGUAGE", "zh": "案件语言"},
	"menu.language_body": {
		"en": "Choose the language used by the case files, interface, and dialogue.",
		"zh": "选择案件档案、界面与对话所使用的语言。",
	},
	"menu.case_opened": {"en": "CASE FILE OPENED", "zh": "案件档案已开启"},
	"menu.case_opened_detail": {
		"en": "The archive is waiting.",
		"zh": "档案室正在等候。",
	},
	"intro.page_count": {"en": "{current} / {total}", "zh": "{current} / {total}"},
	"intro.skip": {"en": "SKIP", "zh": "跳过"},
	"intro.continue": {"en": "CONTINUE", "zh": "继续"},
	"intro.begin": {"en": "ENTER THE WAKE ROOM", "zh": "进入苏醒室"},
	"intro.advance_hint": {
		"en": "Click / E / Space to advance · the story continues automatically.",
		"zh": "点击、按 E 或空格可推进 · 剧情也会自动继续。",
	},
	"intro.advance_hint_final": {
		"en": "Click / E / Space when you are ready to investigate.",
		"zh": "准备开始调查时，点击、按 E 或空格。",
	},
	"intro.invitation_kicker": {
		"en": "PROLOGUE  /  THREE NIGHTS EARLIER",
		"zh": "序章  /  三天前",
	},
	"intro.invitation_title": {
		"en": "THE INVITATION",
		"zh": "那封邀请函",
	},
	"intro.invitation_body": {
		"en": "Dr. Lin asked you to investigate the failures spreading through Ashford Castle — and the orders someone has been sending in her name.",
		"zh": "林博士邀请你调查阿什福德城堡里不断扩大的实验故障，以及有人冒用她的名字发出的命令。",
	},
	"intro.invitation_detail_title": {"en": "YOUR APPOINTMENT", "zh": "你的约见"},
	"intro.invitation_detail": {
		"en": "Meet Dr. Lin at the north gate before the storm closes the hill road.",
		"zh": "在暴风雨封住山路前，于北门与林博士会面。",
	},
	"intro.signal_kicker": {
		"en": "ASHFORD OBSERVATORY  /  23:17",
		"zh": "阿什福德观测室  /  23:17",
	},
	"intro.signal_title": {
		"en": "THE SIGNAL GOES DARK",
		"zh": "讯号忽然中断",
	},
	"intro.signal_body": {
		"en": "At the gate, Dr. Lin's message reaches you through the storm: “Do not trust the emergency order.” Then every lamp in the estate dies.",
		"zh": "在城堡大门前，林博士的讯息穿过暴雨传来：“不要相信那道紧急命令。” 随后，庄园里的灯火全部熄灭。",
	},
	"intro.signal_detail_title": {"en": "LAST CONFIRMED FACT", "zh": "最后确认的信息"},
	"intro.signal_detail": {
		"en": "Dr. Lin is still somewhere inside the castle.",
		"zh": "林博士仍在城堡的某处。",
	},
	"intro.interruption_kicker": {
		"en": "ASHFORD GRAND HALL  /  MOMENTS LATER",
		"zh": "阿什福德大厅  /  片刻之后",
	},
	"intro.interruption_title": {
		"en": "THE MISSING MINUTES",
		"zh": "消失的几分钟",
	},
	"intro.interruption_body": {
		"en": "You follow the open gate. A violet flash. The locks turn by themselves. When footsteps answer from the hall, your memory breaks apart.",
		"zh": "你穿过敞开的铁门。紫光一闪，锁扣自行转动。走廊深处传来脚步声时，你的记忆忽然断裂。",
	},
	"intro.interruption_detail_title": {"en": "UNANSWERED", "zh": "尚未解开的疑问"},
	"intro.interruption_detail": {
		"en": "Who locked the castle — and what did they take from you?",
		"zh": "是谁封锁了城堡？又从你身上带走了什么？",
	},
	"intro.wake_kicker": {
		"en": "FIRST ROOM  /  THE WAKE ROOM",
		"zh": "第一间房  /  苏醒室",
	},
	"intro.wake_title": {
		"en": "THE FIRST LEAD",
		"zh": "第一条线索",
	},
	"intro.wake_body": {
		"en": "You wake in a locked room with Dr. Lin missing. Her letter and the objects marked in brass are the only trail left for you to follow.",
		"zh": "你在一间锁住的房里醒来，林博士已经失踪。她留下的信，以及带黄铜标记的物体，是你仅剩的追踪线索。",
	},
	"intro.wake_detail_title": {"en": "FIRST LEAD", "zh": "首条线索"},
	"intro.wake_detail": {
		"en": "Find Dr. Lin. Read the evidence. Solve each room's lock.",
		"zh": "找到林博士，阅读证据，并解开每一间房的锁。",
	},
	"guide.field_title": {"en": "FIELD ORIENTATION", "zh": "现场方位确认"},
	"guide.field_kicker": {"en": "INVESTIGATOR'S FIELD CARD", "zh": "调查员现场卡"},
	"guide.field_intro": {
		"en": "Only two actions matter before your first lead.",
		"zh": "找到第一条线索前，只需记住两项操作。",
	},
	"guide.move_detail": {"en": "MOVE\n—or click ground", "zh": "移动\n或点击地面"},
	"guide.inspect_detail": {
		"en": "INSPECT a highlighted object",
		"zh": "调查被标记的物体",
	},
	"guide.first_lead": {
		"en": "Start with the candle note or any object marked by a brass corner.",
		"zh": "先调查烛光便签，或任何带黄铜角标的物体。",
	},
	"guide.first_lead_kicker": {"en": "FIRST LEAD", "zh": "首条线索"},
	"guide.begin": {"en": "BEGIN SEARCH", "zh": "开始搜查"},
	"guide.hall_kicker": {"en": "HALL SURVIVAL CARD", "zh": "大厅生存卡"},
	"guide.hall_title": {"en": "THE GUARDIAN IS HUNTING", "zh": "守卫已经开始追捕"},
	"guide.hall_intro": {
		"en": "It follows sight and sound. A room door is shelter.",
		"zh": "它会追随视线与声响。进入房间就是脱险。",
	},
	"guide.hall_move_detail": {
		"en": "RUN\n—or click a clear route",
		"zh": "奔跑\n或点击空地寻路",
	},
	"guide.hall_inspect_detail": {
		"en": "USE a marked door or exhibit",
		"zh": "使用标记的门或知识展品",
	},
	"guide.hall_lead_kicker": {"en": "READ THE DANGER", "zh": "看懂危险信号"},
	"guide.hall_lead": {
		"en": "Follow the blue route to Chemistry. As the bar warms, the music tightens and the image breaks up: reach a room.",
		"zh": "沿蓝色路线前往化学室。进度条越热、音乐越急、画面越不稳定，守卫就越近——立刻进房间。",
	},
	"guide.hall_begin": {"en": "BEGIN THE ESCAPE", "zh": "开始逃脱"},
	"guide.first_lead_step_1_title": {"en": "FIRST LEAD  ·  1 / 3", "zh": "第一条线索  ·  1 / 3"},
	"guide.first_lead_step_1_body": {
		"en": "Read the candle note beside the bed.",
		"zh": "阅读床边的烛光便签。",
	},
	"guide.first_lead_step_2_title": {"en": "FIRST LEAD  ·  2 / 3", "zh": "第一条线索  ·  2 / 3"},
	"guide.first_lead_step_2_body": {
		"en": "Follow the brass mark on the locked door.",
		"zh": "跟随锁门上的黄铜标记。",
	},
	"guide.first_lead_step_3_title": {"en": "FIRST LEAD  ·  3 / 3", "zh": "第一条线索  ·  3 / 3"},
	"guide.first_lead_step_3_body": {
		"en": "Open the brass-marked door to the castle hall.",
		"zh": "打开带黄铜标记的门，前往城堡大厅。",
	},
	"guide.wake_desk_title": {"en": "WAKE ROOM  ·  START HERE", "zh": "苏醒室  ·  从这里开始"},
	"guide.wake_desk_body": {
		"en": "Inspect the study desk for Dr. Lin's note on castle locks.",
		"zh": "调查书桌，阅读林博士留下的城堡门锁说明。",
	},
	"guide.wake_key_title": {"en": "WAKE ROOM  ·  FIND THE KEY", "zh": "苏醒室  ·  寻找钥匙"},
	"note.knowledge.chemistry.title": {"en": "Chemistry Room Knowledge", "zh": "化学室知识"},
	"note.knowledge.chemistry.body": {
		"en": "A chemical change creates new substances: burning paper is chemical, while melting ice, breaking glass and dissolving sugar are physical changes.",
		"zh": "化学变化会生成新物质：纸张燃烧属于化学变化，而冰融化、玻璃破碎、糖溶解都是物理变化。",
	},
	"note.knowledge.greenhouse.title": {"en": "Greenhouse Room Knowledge", "zh": "温室知识"},
	"note.knowledge.greenhouse.body": {
		"en": "Plants absorb carbon dioxide and use light and water to make food. Oxygen is released as a product.",
		"zh": "植物吸收二氧化碳，利用光和水制造养分，并释放氧气作为产物。",
	},
	"note.knowledge.circuit.title": {"en": "Circuit Room Knowledge", "zh": "线路室知识"},
	"note.knowledge.circuit.body": {
		"en": "A conductor lets charge move through a circuit. Metal is usually a better conductor than rubber, dry wood or glass; a broken circuit cannot carry current.",
		"zh": "导体让电荷在电路中流动。金属通常比橡胶、干木或玻璃更导电；断路无法通过电流。",
	},
	"note.knowledge.dining.title": {"en": "Dining Hall Knowledge", "zh": "餐厅知识"},
	"note.knowledge.dining.body": {
		"en": "Measure a reasonably steady change and compare several independent indicators before estimating elapsed time.",
		"zh": "先测量一个足够稳定的变化量，并比对多个独立线索，再据此推算经过的时间。",
	},
	"note.knowledge.library.title": {"en": "Library Knowledge", "zh": "图书馆知识"},
	"note.knowledge.library.body": {
		"en": "The primary colors of light are red, green and blue. Combining light adds energy and produces brighter colors.",
		"zh": "光的三原色是红、绿、蓝。光的叠加会增加能量，混合后得到更明亮的颜色。",
	},
	"wake.unclaimed.body": {
		"en": "The door will open — but you are not finished in here.\n\nGo back for what this room still holds. You will not be able to return once the hall takes you:",
		"zh": "门可以开了 —— 但你在这间屋子里还没做完。\n\n回去取走这间屋子还留着的东西。一旦踏入大厅，就没那么容易回头了：",
	},
	"wake.unclaimed.button": {"en": "Search the room again", "zh": "再搜一遍房间"},
	"wake.unclaimed.wake_key": {"en": "the Wake Room key, beneath the bed pillow", "zh": "苏醒室钥匙（床枕下）"},
	"wake.unclaimed.chemistry_key": {
		"en": "the Chemistry Room key, behind the books on the shelf",
		"zh": "化学室钥匙（书架书本后）",
	},
	"wake.unclaimed.desk_note": {"en": "Mrs. Lin's note on the study desk", "zh": "书桌上林夫人的字条"},
	"wake.unclaimed.candle_note": {"en": "the candle note beside the bed", "zh": "床边的蜡烛笔记"},
	"guide.wake_key_body": {
		"en": "The Wake Room key is hidden beneath the bed pillow.",
		"zh": "苏醒室的钥匙藏在床枕下。",
	},
	"guide.wake_answer_title": {"en": "WAKE ROOM  ·  FIND THE ANSWER", "zh": "苏醒室  ·  寻找答案"},
	"guide.wake_answer_body": {
		"en": "Read the bookshelf's science volume before answering the door.",
		"zh": "在回答门锁前，阅读书架上的科学书籍。",
	},
	"guide.wake_door_title": {"en": "WAKE ROOM  ·  TEST THE LOCK", "zh": "苏醒室  ·  测试门锁"},
	"guide.wake_door_body": {
		"en": "Return to the door. Use the key, then answer its question.",
		"zh": "回到大门前：使用钥匙，然后回答门上的问题。",
	},
	"hall.arrival_body": {
		"en": "The brass lock shuts behind you. Castle Hall lies silent beneath violet glass.\n\nA blue signal pulses in the north wing. Follow it.",
		"zh": "黄铜锁在你身后合拢。紫色玻璃下，城堡大厅一片寂静。\n\n北翼传来一道蓝色脉冲。跟上它。",
	},
	"hall.arrival_continue": {"en": "FOLLOW THE BLUE SIGNAL", "zh": "跟随蓝色讯号"},
	"hall.route_step_1_title": {"en": "HALL ROUTE  ·  1 / 3", "zh": "大厅路线  ·  1 / 3"},
	"hall.route_step_1_body": {
		"en": "Reach the Chemistry Room door in the north wing.",
		"zh": "前往北翼的化学室门。",
	},
	"hall.route_step_2_title": {"en": "HALL ROUTE  ·  2 / 3", "zh": "大厅路线  ·  2 / 3"},
	"hall.route_step_2_body": {
		"en": "Study the active brass core beside the route.",
		"zh": "调查路线旁仍在运作的黄铜核心。",
	},
	"hall.route_step_3_title": {"en": "HALL ROUTE  ·  3 / 3", "zh": "大厅路线  ·  3 / 3"},
	"hall.route_step_3_body": {
		"en": "Return to the Chemistry Room and answer its lock.",
		"zh": "返回化学室，回答门锁提出的问题。",
	},
	"hall.route_compass": {"en": "BLUE FLOOR MARKERS  ·  {direction}", "zh": "蓝色地面路标  ·  {direction}"},
	"hall.direction_north": {"en": "NORTH", "zh": "北方"},
	"hall.direction_south": {"en": "SOUTH", "zh": "南方"},
	"hall.direction_east": {"en": "EAST", "zh": "东方"},
	"hall.direction_west": {"en": "WEST", "zh": "西方"},
	"hall.direction_north_east": {"en": "NORTH-EAST", "zh": "东北"},
	"hall.direction_north_west": {"en": "NORTH-WEST", "zh": "西北"},
	"hall.direction_south_east": {"en": "SOUTH-EAST", "zh": "东南"},
	"hall.direction_south_west": {"en": "SOUTH-WEST", "zh": "西南"},
	"hall.chemistry_door_locked": {
		"en": "The laboratory key turns, but a second ring stays dark. Its blue pulse answers the brass core nearby — the lock wants an observation, not a guess.",
		"zh": "实验室钥匙转动了，但第二道锁环仍然黯淡。它的蓝光回应着附近的黄铜核心——门锁需要的是观察，而不是猜测。",
	},
	"hall.chemistry_core_body": {
		"en": "The brass core is warm. Inside its chamber, matter is changing into something new. The same mark flares on the Chemistry Room lock.\n\nThe observation is recorded in your notebook. Return to the door.",
		"zh": "黄铜核心仍有余温。它的腔室里，物质正转变为新的物质；同样的标记在化学室门锁上亮起。\n\n观察结果已记录进笔记。回到门前吧。",
	},
	"hall.chemistry_core_continue": {"en": "RETURN TO THE LOCK", "zh": "返回门锁"},
	"hall.chemistry_enter": {"en": "ENTER THE CHEMISTRY ROOM", "zh": "进入化学室"},
	"transition.hall_title": {"en": "CASTLE HALL", "zh": "城堡大厅"},
	"transition.hall_detail": {"en": "NORTH WING SIGNAL DETECTED", "zh": "已侦测到北翼讯号"},
	"menu.intake_kicker": {"en": "CASE INTAKE  /  ASHFORD ESTATE", "zh": "案件接收  /  阿什福德庄园"},
	"menu.intake_title": {"en": "OPEN A CASE FILE", "zh": "开启案件档案"},
	"menu.intake_detail": {
		"en": "Begin a new investigation, or reopen an archived case.",
		"zh": "开始新的调查，或继续一份已归档的案件。",
	},
	"save.none": {"en": "AUTOSAVE · No active case", "zh": "自动存档 · 尚无进行中的案件"},
	"save.resume": {"en": "AUTOSAVE · Resume: {room}", "zh": "自动存档 · 从这里继续：{room}"},
	"room.wake_room": {"en": "Wake Room", "zh": "苏醒室"},
	"room.floor_1_hub": {"en": "Castle Hall", "zh": "城堡大厅"},
	"room.chemistry_room": {"en": "Chemistry Room", "zh": "化学室"},
	"room.greenhouse_room": {"en": "Greenhouse", "zh": "温室"},
	"room.circuit_room": {"en": "Circuit Room", "zh": "电路室"},
	"room.library": {"en": "Library", "zh": "图书馆"},
	"room.dining_hall": {"en": "Dining Hall", "zh": "餐厅"},
	"room.final_deduction_room": {"en": "Final Archive", "zh": "终局档案室"},
	"death.reason_title": {"en": "OBSERVATION LOST", "zh": "调查中断"},
	"death.reason_body": {
		"en": "The Guardian forced you from the trail. Your notes and evidence are safe.",
		"zh": "守卫迫使你离开现场。你的笔记与证物已被保留。",
	},
	"capture.title": {"en": "CAUGHT", "zh": "你被抓住了"},
	"capture.seized": {
		"en": "The Guardian closes its hand around your arm.",
		"zh": "守卫的手扣住了你的手臂。",
	},
	"capture.escorted": {
		"en": "It marches you back out of the wing. The trail goes cold.",
		"zh": "它押着你退出这片区域。线索就此中断。",
	},
	"death.kicker": {"en": "CASE FILE  /  INTERRUPTION REPORT", "zh": "案件档案  /  中断记录"},
	"death.retention": {"en": "EVIDENCE RETAINED  ·  CHECKPOINT READY", "zh": "证物已保留  ·  检查点已就绪"},
	"death.retention_ready": {
		"en": "EVIDENCE RETAINED  ·  CHECKPOINT: {room}",
		"zh": "证物已保留  ·  检查点：{room}",
	},
	"death.retention_missing": {
		"en": "EVIDENCE RETAINED  ·  RETRY THIS ROOM",
		"zh": "证物已保留  ·  请重试当前房间",
	},
	"death.retry_room": {"en": "RETRY ROOM", "zh": "重试当前房间"},
	"death.retry_checkpoint": {"en": "RETURN TO CHECKPOINT", "zh": "从检查点继续"},
	"death.main_menu": {"en": "RETURN TO ARCHIVE", "zh": "返回档案室"},
	"ending.kicker_ordinary": {"en": "CASE RECORD  /  PARTIAL CLOSURE", "zh": "案件记录  /  阶段结案"},
	"ending.title_ordinary": {"en": "THE EXECUTOR IS IDENTIFIED", "zh": "执行者已确认"},
	"ending.summary_ordinary": {
		"en": "The Butler operated the apparatus. The author of the emergency order is still absent from the record.",
		"zh": "管家执行了装置操作；紧急指令的真正发起者尚未出现在档案中。",
	},
	"ending.status_ordinary": {"en": "SEALED REVIEW AVAILABLE", "zh": "可进入密封复查"},
	"ending.kicker_true": {"en": "CASE RECORD  /  COMPLETE CLOSURE", "zh": "案件记录  /  完整结案"},
	"ending.title_true": {"en": "THE FORGED ORDER IS EXPOSED", "zh": "伪造指令已揭露"},
	"ending.summary_true": {
		"en": "The Mechanic forged the order, used the maintenance route, and silenced Dr. Lin to seize her work.",
		"zh": "机械师伪造指令、利用维修路线，并令林博士沉默以夺取她的研究成果。",
	},
	"ending.status_true": {"en": "TRUE RECORD SEALED", "zh": "真相记录已封存"},
	"ending.continue": {"en": "OPEN SEALED REVIEW", "zh": "进入密封复查"},
	"ending.review": {"en": "REVIEW CASE CHAIN", "zh": "复查案件链"},
	"ending.ordinary_record": {
		"en": "ORDINARY CASE RECORD\nThe Butler operated the apparatus — but who authored the order?",
		"zh": "普通案件记录\n管家操作了装置——但命令究竟来自谁？",
	},
	"ending.true_continue": {"en": "RETURN TO SEALED REVIEW", "zh": "返回密封复查"},
	"ending.true_review": {"en": "REVIEW CASE CHAIN", "zh": "复查案件链"},
	"ending.true_record": {
		"en": "TRUE CASE RECORD\nThe Mechanic forged the command, silenced Dr. Lin, and tried to claim her work.",
		"zh": "真相案件记录\n机械师伪造命令、令林博士沉默，并企图夺取她的成果。",
	},
	"ending.main_menu": {"en": "RETURN TO ARCHIVE", "zh": "返回档案室"},
	"language.english": {"en": "English", "zh": "English"},
	"language.chinese": {"en": "中文", "zh": "中文"},
	# 知识锁：这是整个游戏的 STEM 教学核心，题干与选项跟着数据表走
	# （game_world.gd 的 DOOR_QUESTIONS / FINAL_SYNTHESIS_QUESTIONS），
	# 这里只放围绕它们的界面文字。
	"knowledge.lock_title": {"en": "Knowledge Lock:", "zh": "知识锁："},
	"knowledge.locked_title": {
		"en": "The key fits, but the knowledge lock is still sealed.",
		"zh": "钥匙对上了，但知识锁仍然紧闭。",
	},
	"knowledge.locked_body": {
		"en": (
			"Study the {room} exhibit in Castle Hall and save it to "
			+ "NoteHub before answering this question."
		),
		"zh": "请先在城堡大厅研究「{room}」展品并存入侦探笔记，再来回答这道题。",
	},
	"knowledge.correct": {
		"en": "Correct.\n\nThe knowledge lock accepts your answer.\n\nDoor opened.",
		"zh": "回答正确。\n\n知识锁接受了你的答案。\n\n门开了。",
	},
	"knowledge.wrong": {
		"en": (
			"Not quite.\n\nThe lock remains sealed. Think about the science "
			+ "behind the question and try again."
		),
		"zh": "还差一点。\n\n锁仍然没开。想一想题目背后的科学原理，再试一次。",
	},
	"knowledge.retry": {"en": "Try Again", "zh": "再试一次"},
	"knowledge.leave": {"en": "Leave the lock", "zh": "先离开这道锁"},
	"knowledge.continue": {"en": "Continue", "zh": "继续"},
	"knowledge.study_prompt": {
		"en": "Press E to study {target}",
		"zh": "按 E 研究{target}",
	},
	"knowledge.saved_to_notehub": {
		"en": "This knowledge has been added to NoteHub.",
		"zh": "这条知识已存入侦探笔记。",
	},
	"knowledge.synthesis_header": {
		"en": "Final Synthesis Lock — Question {index}/{total}:",
		"zh": "终局综合锁 —— 第 {index}/{total} 题：",
	},
	"knowledge.synthesis_wrong": {
		"en": (
			"That answer does not fit the evidence you have learned.\n\n"
			+ "Review the corresponding room Knowledge note and try again."
		),
		"zh": "这个答案跟你掌握的证据对不上。\n\n回去复习对应房间的知识笔记，再试一次。",
	},
	# 药水状态角标空间很窄，用短名而不是 POTION_INFO 里的完整名字。
	"potion.swift_short": {"en": "SWIFT", "zh": "迅捷"},
	"potion.vision_short": {"en": "VISION", "zh": "洞察"},
	"potion.mire_short": {"en": "MIRE", "zh": "毒沼"},
	"potion.shroud_short": {"en": "SHROUD", "zh": "隐身"},
	"potion.daze_short": {"en": "DAZE", "zh": "眩晕"},
	"potion.reveal_short": {"en": "REVEAL", "zh": "现形"},
	# 音量行空间很窄，用短标签。
	"audio.music": {"en": "Music", "zh": "音乐"},
	"audio.sfx": {"en": "Sound", "zh": "音效"},
	"audio.ui": {"en": "Interface", "zh": "界面音"},
	"audio.mute": {"en": "Mute", "zh": "静音"},
	"audio.unmute": {"en": "Unmute", "zh": "取消静音"},
}


func _ready() -> void:
	_language = _load_preference()


func language() -> String:
	return _language


func is_chinese() -> bool:
	return _language == CHINESE


func set_language(language_code: String) -> void:
	var normalized := _normalize(language_code)
	if normalized == _language:
		return
	_language = normalized
	_save_preference()
	locale_changed.emit(_language)


func toggle_language() -> void:
	set_language(CHINESE if _language == ENGLISH else ENGLISH)


func text(key: String, replacements: Dictionary = {}) -> String:
	var entry: Dictionary = TEXT.get(key, {})
	var value := str(entry.get(_language, entry.get(ENGLISH, key)))
	for replacement_key: Variant in replacements:
		value = value.replace(
			"{" + str(replacement_key) + "}",
			str(replacements[replacement_key])
		)
	return value


func room_name(room_id: String) -> String:
	return text("room." + room_id)


## 房间正文的翻译入口。键就是英文原句本身（见 CaseScriptZh），所以房间脚本
## 里的调用点不用改；查不到就原样返回英文，缺译只是没翻译，不会显示成键名。
##
## 这个函数由文本的出口函数调用（present_feedback / show_message /
## set_dialogue_text / NoteHud.add_clue），而不是散在几百个调用点上——
## 后者每漏一处就是一句永远翻不到的英文。
func line(english: String) -> String:
	if _language != CHINESE:
		return english
	var translated: Variant = CaseScriptZh.LINES.get(english)
	if translated == null:
		return english
	return str(translated)


func _load_preference() -> String:
	var config := ConfigFile.new()
	if config.load(PREFERENCE_PATH) != OK:
		return _system_language()
	# 文件存在不等于玩家选过语言：GameAudio 只写 [audio] 段就会把文件
	# 创建出来。这时必须继续按系统语言判断，否则中文系统的玩家只要调过
	# 一次音量，下次启动就被静默切回英文。
	var stored: String = str(config.get_value("display", "language", ""))
	if stored.is_empty():
		return _system_language()
	return _normalize(stored)


func _save_preference() -> void:
	# 音量设置也写在同一个文件里（GameAudio 的 [audio] 段），
	# 不先读回来就写会把它整段抹掉——切一次语言，音量就全被重置。
	var config := ConfigFile.new()
	# PlayerPreferences and GameAudio share this file. Load before writing
	# so changing language never clears another section's settings.
	config.load(PREFERENCE_PATH)
	config.set_value("display", "language", _language)
	config.save(PREFERENCE_PATH)


func _system_language() -> String:
	var locale := OS.get_locale().to_lower()
	return CHINESE if locale.begins_with("zh") else ENGLISH


func _normalize(language_code: String) -> String:
	return CHINESE if language_code.to_lower().begins_with("zh") else ENGLISH
