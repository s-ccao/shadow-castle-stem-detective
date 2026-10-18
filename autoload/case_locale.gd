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
		"en": "Move — WASD or click the floor\nInvestigate — E\nEvidence — B   ·   Notes — K   ·   Objectives — O\nHubs — Tab bag   ·   I keys   ·   U map\nClose a panel · Settings — Esc",
		"zh": "移动 — WASD 或点击地面\n调查 — E\n证物 — B   ·   笔记 — K   ·   目标 — O\n工具栏 — Tab 背包   ·   I 钥匙   ·   U 地图\n关闭面板 · 设置 — Esc",
	},
	"menu.guidance_on": {"en": "FIELD PROMPTS: ON", "zh": "引导提示：开启"},
	"menu.guidance_off": {"en": "FIELD PROMPTS: OFF", "zh": "引导提示：关闭"},
	"menu.mute_on": {"en": "MUTE: ON", "zh": "静音：开启"},
	"menu.mute_off": {"en": "MUTE: OFF", "zh": "静音：关闭"},
	"pause.music": {"en": "MUSIC", "zh": "音乐"},
	"pause.effects": {"en": "EFFECTS", "zh": "音效"},
	"pause.kicker": {"en": "CASE PAUSED  ·  {room}", "zh": "案件已暂停  ·  {room}"},
	"pause.kicker_plain": {"en": "CASE PAUSED", "zh": "案件已暂停"},
	"pause.resume": {"en": "RESUME", "zh": "继续游戏"},
	"pause.main_menu": {"en": "MAIN MENU", "zh": "返回主界面"},
	"pause.quit": {"en": "QUIT GAME", "zh": "退出游戏"},
	"pause.resume_hint": {"en": "Esc  ·  resume", "zh": "Esc  ·  继续游戏"},
	"pause.sound": {"en": "SOUND", "zh": "声音"},
	"pause.guidance": {"en": "GUIDANCE", "zh": "引导"},
	"pause.controls": {"en": "CONTROLS", "zh": "操作"},
	"pause.menu_title": {"en": "RETURN TO MAIN MENU?", "zh": "返回主界面？"},
	"pause.menu_body": {
		"en": "Your case is saved automatically. Continue resumes at the {room} entrance.",
		"zh": "调查进度已自动保存。之后选择「继续案件」，会从{room}入口继续。",
	},
	"pause.menu_body_plain": {"en": "Your investigation is saved automatically.", "zh": "调查进度已自动保存。"},
	"pause.menu_confirm": {"en": "RETURN", "zh": "确认返回"},
	"pause.quit_title": {"en": "QUIT THE GAME?", "zh": "退出游戏？"},
	"pause.quit_body": {
		"en": "Your case is saved automatically. Next time, Continue resumes at the {room} entrance.",
		"zh": "调查进度已自动保存。下次选择「继续案件」，会从{room}入口继续。",
	},
	"pause.quit_body_plain": {
		"en": "Your investigation is saved automatically. Choose Continue next time to resume.",
		"zh": "调查进度已自动保存。下次选择「继续案件」即可接着调查。",
	},
	"pause.quit_confirm": {"en": "QUIT", "zh": "确认退出"},
	"pause.cancel": {"en": "CANCEL", "zh": "取消"},
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
		"en": "Follow the violet footprints to the brass core. Stop, inspect it and file its knowledge; then the next trail leads to Chemistry.",
		"zh": "沿紫色脚印找到黄铜核心。停下调查并收录知识后，下一段脚印才会指向化学室。",
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
	"guide.wake_first_door_title": {"en": "FIRST LEAD  ·  1 / 3", "zh": "第一条线索  ·  1 / 3"},
	"guide.wake_first_door_body": {
		"en": "Find a way out of this room.",
		"zh": "找到离开这个房间的办法。",
	},
	"guide.wake_search_title": {"en": "FIRST LEAD  ·  2 / 3", "zh": "第一条线索  ·  2 / 3"},
	"guide.wake_search_body": {
		"en": "The door needs a key, and it will ask you a question. Search the room for both.",
		"zh": "门需要一把钥匙，还会问你一个问题。在房间里把两样都找出来。",
	},
	"guide.wake_answer_title": {"en": "FIRST LEAD  ·  3 / 3", "zh": "第一条线索  ·  3 / 3"},
	"guide.wake_answer_body": {
		"en": "Return to the door and answer what it asks.",
		"zh": "回到门前，回答它的问题。",
	},
	"guide.wake_exit_title": {"en": "THE HALL AWAITS", "zh": "大厅在等着你"},
	"guide.wake_exit_body": {
		"en": "The lock is open. Go through when you are ready.",
		"zh": "锁已经开了。准备好就出发。",
	},
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
	"guide.chem_stain_title": {"en": "CHEMISTRY ROOM  ·  1 / 3", "zh": "化学室  ·  1 / 3"},
	"guide.chem_stain_body": {
		"en": "Investigate the red stain on the floor, then record what the powder and indicator reveal.",
		"zh": "调查地面上的红色污渍，并记录白色粉末与指示剂说明的真相。",
	},
	"guide.chem_butler_title": {"en": "CHEMISTRY ROOM  ·  2 / 3", "zh": "化学室  ·  2 / 3"},
	"guide.chem_butler_body": {
		"en": "Tell the Butler the stain was staged, then answer his question to clear him.",
		"zh": "把污渍是伪造的结论告诉管家，并回答他的问题来洗清他的嫌疑。",
	},
	"guide.chem_exit_title": {"en": "CHEMISTRY ROOM  ·  3 / 3", "zh": "化学室  ·  3 / 3"},
	"guide.chem_exit_body": {
		"en": "The room is solved. Return to Castle Hall — the Guardian is still hunting out there.",
		"zh": "本房间已经查清。返回城堡大厅 —— 守卫仍在外面搜捕。",
	},
	"coach.move": {
		"en": "Move with these keys — or click anywhere on the floor.",
		"zh": "用这几个键移动 —— 也可以直接点地面。",
	},
	"coach.interact": {
		"en": "Something is within reach. Press this to look at it.",
		"zh": "面前有东西可以查看。按这个键。",
	},
	"guide.rule_title": {
		"en": "HOW EVERY DOOR IN THIS CASTLE WORKS",
		"zh": "这座城堡里每一道门的规则",
	},
	"guide.rule_body": {
		"en": (
			"That door had two locks. A key, and a question.\n\n"
			+ "The key was in this room. The answer was not — you learned it from "
			+ "the flame and the book. Every locked door from here on is the same: "
			+ "find the key nearby, and find the answer somewhere you have already "
			+ "been.\n\n"
			+ "Your notebook keeps everything you learn. When a door asks you "
			+ "something, the answer is already in there."
		),
		"zh": (
			"那道门上着两把锁：一把钥匙，一道问题。\n\n"
			+ "钥匙在这个房间里，答案却不在 —— 你是从火焰和书本里学到的。"
			+ "从这里开始，每一道锁着的门都是这样：钥匙在附近找，"
			+ "答案要去你已经去过的地方找。\n\n"
			+ "你的笔记本会记下你学到的一切。当一道门向你提问时，"
			+ "答案早就在里面了。"
		),
	},
	"guide.rule_continue": {"en": "I UNDERSTAND", "zh": "我明白了"},
	"hall.guided_return": {
		"en": "Its lantern sweeps over you. You duck back onto the tracks.",
		"zh": "它的灯光扫过你。你缩回那串脚印上。",
	},
	"hall.route_spotted_warning": {
		"en": "The Guardian's head turns. Off the tracks, you are in the open.",
		"zh": "守卫回过头来。离开脚印，你就暴露在外面了。",
	},
	"hall.route_revealed": {
		"en": "The vial slips and bursts. Where the vapour settles, footprints "
			+ "glow — someone crossed this hall before you, and was not caught.",
		"zh": "药瓶脱手摔碎。药雾落处浮出一串脚印 —— 你之前有人穿过这座大厅，"
			+ "而且没有被抓住。",
	},
	"hall.route_rule": {
		"en": "Stay near the footprints for protection. Leave them and the Guardian can catch you. Read the core before continuing.",
		"zh": "脚印附近有引导保护。离开这片范围，守卫就能抓住你。先靠近核心阅读知识，再继续前进。",
	},
	"hall.guided_shove": {
		"en": "The Guardian's shoulder throws you aside — it stumbles, and you keep moving.",
		"zh": "守卫的肩膀把你撞开 —— 它踉跄了一下，你趁机继续跑。",
	},
	"hall.near_miss_title": {"en": "ALMOST CAUGHT", "zh": "差一点被抓住"},
	"cg.chemistry_kicker": {"en": "ASHFORD CASTLE · THE CHEMISTRY THRESHOLD", "zh": "阿什福德城堡 · 化学室门前"},
	"cg.approach": {"en": "The lock yields. Heavy footsteps close behind you.", "zh": "门锁松开了。沉重的脚步正在身后逼近。"},
	"cg.reach": {"en": "It lunges. You slip through the narrowing doorway.", "zh": "它猛地扑来。你抢先闪进门缝。"},
	"cg.door": {"en": "Its hand closes on empty air.", "zh": "它的手在身后合拢，却抓了个空。"},
	"cg.skip": {"en": "SKIP SCENE", "zh": "跳过演出"},
	"door.chemistry_title": {"en": "CHEMISTRY · KNOWLEDGE LOCK", "zh": "化学室 · 知识门锁"},
	"door.chemistry_hint": {"en": "Use the principle you filed. Choose the example that forms a new substance.", "zh": "运用刚收录的原理：找出会产生新物质的变化。"},
	"door.chemistry_wrong": {"en": "That example changes appearance or state, not the substance. The lock is still sealed; try another answer.", "zh": "这个例子改变的是形态或状态，并没有产生新物质。门锁仍未打开，可以重新选择。"},
	"door.correct": {"en": "Correct: a new substance forms. The knowledge lock is released. Enter when you are ready.", "zh": "回答正确：这种变化产生了新物质。知识门锁已解除，准备好后推门进入。"},
	"door.leave": {"en": "LEAVE THE LOCK", "zh": "暂时离开"},
	"hall.near_miss_body": {
		"en": "Its hand closes on the air behind your collar.",
		"zh": "它的手在你的衣领后合拢，抓了个空。",
	},
	"hall.near_miss_escape": {
		"en": "The Chemistry door swings shut between you. For now.",
		"zh": "化学室的门在你们之间合上了。暂时。",
	},
	"hall.arrival_body": {
		"en": "The brass lock shuts behind you. Castle Hall lies silent beneath violet glass.\n\nThe vial you were holding is gone from your hand, and the floor is glowing where it fell.",
		"zh": "黄铜锁在你身后合拢。紫色玻璃下，城堡大厅一片寂静。\n\n你手里的药瓶没了，地上它摔碎的地方正在发光。",
	},
	"hall.arrival_continue": {"en": "FOLLOW THE FOOTPRINTS", "zh": "跟着脚印走"},
	"hall.route_step_1_title": {"en": "HALL ROUTE  ·  1 / 3", "zh": "大厅路线  ·  1 / 3"},
	"hall.route_step_1_body": {
		"en": "Follow the footprints to the brass core. Learn the rule before approaching the Chemistry lock.",
		"zh": "沿脚印前往黄铜核心知识点。先收录门锁所需的知识，再去化学室。",
	},
	"hall.route_step_2_title": {"en": "HALL ROUTE  ·  2 / 3", "zh": "大厅路线  ·  2 / 3"},
	"hall.route_step_2_body": {
		"en": "Stop here. Inspect the highlighted core, then choose FILE KNOWLEDGE to continue.",
		"zh": "先停在这里。调查高亮的黄铜核心，并点击「收录知识」后才能继续。",
	},
	"hall.route_step_3_title": {"en": "HALL ROUTE  ·  3 / 3", "zh": "大厅路线  ·  3 / 3"},
	"hall.route_step_3_body": {
		"en": "Knowledge filed. Follow the new footprints to the Chemistry Room lock.",
		"zh": "知识已收录。沿新出现的脚印前往化学室门锁。",
	},
	"hall.route_study_action": {"en": "E / CLICK CORE · INSPECT", "zh": "按 E / 点击核心 · 调查"},
	"knowledge.kicker": {"en": "FIELD KNOWLEDGE", "zh": "知识档案"},
	"knowledge.SpecimenHeading": {"en": "PRINCIPLE ILLUSTRATION", "zh": "原理示意"},
	"knowledge.ObservationHeading": {"en": "01  ·  WHAT TO NOTICE", "zh": "01  ·  观察什么"},
	"knowledge.PrincipleHeading": {"en": "02  ·  THE SCIENCE", "zh": "02  ·  科学原理"},
	"knowledge.ExamplesHeading": {"en": "03  ·  MAKE THE CONNECTION", "zh": "03  ·  举例理解"},
	"knowledge.unfiled": {"en": "NOT YET FILED", "zh": "尚未收录"},
	"knowledge.recorded": {"en": "FILED · OPEN FOR REVIEW", "zh": "已收录 · 可以复习"},
	"knowledge.footer": {"en": "Read the idea, then file it in your notebook. You can return to review it.", "zh": "理解原理后再收录到笔记。以后仍可回来打开这页复习。"},
	"knowledge.file": {"en": "FILE KNOWLEDGE & CONTINUE", "zh": "收录知识并继续"},
	"knowledge.return": {"en": "RETURN TO INVESTIGATION", "zh": "返回调查"},
	"knowledge.inspect_prompt": {"en": "E · Read {title}", "zh": "按 E · 了解{title}"},
	"knowledge.review_prompt": {"en": "E · Review {title}", "zh": "按 E · 复习{title}"},
	"knowledge.chemistry.title": {"en": "When matter becomes something new", "zh": "物质什么时候变成了新物质？"},
	"knowledge.chemistry.principle": {"en": "A chemical change creates new substances. Burning paper is chemical, while melting ice, breaking glass and dissolving sugar are physical changes. The important distinction is whether a new substance forms, not simply whether the appearance changes.", "zh": "化学变化会产生新的物质。例如，纸张燃烧后形成灰烬和气体。冰融化、玻璃破碎和糖溶解属于物理变化：状态、形状或分布改变了，但没有因此形成新物质。判断的关键不是外观变没变，而是有没有新物质产生。"},
	"knowledge.chemistry.observation": {"en": "The brass core is warm. Heat is a clue, but the important question is whether a new substance forms.", "zh": "黄铜核心仍有余温。发热是一条线索，但关键问题是：有没有产生新的物质？"},
	"knowledge.chemistry.example_0": {"en": "CHEMICAL CHANGE\nBurning paper forms ash and gases: new substances.", "zh": "化学变化\n纸张燃烧后形成灰烬和气体，产生了新物质。"},
	"knowledge.chemistry.example_1": {"en": "PHYSICAL CHANGE\nIce melts into water. Its state changes, not the substance.", "zh": "物理变化\n冰融化成水，改变的是状态，物质仍然是水。"},
	"knowledge.circuit.title": {"en": "A complete path for current", "zh": "电流需要一条完整的路"},
	"knowledge.circuit.principle": {"en": "Current needs a closed conducting path. Metals usually conduct better than rubber, dry wood or glass. A broken connection stops the current even when every remaining piece is conductive. Trace the whole circuit, not just one component.", "zh": "电流需要一条闭合的导电通路。金属通常比橡胶、干木头或玻璃更容易导电。但仅有导电材料还不够：如果连接断开，电流仍无法持续通过。因此检查电路时，既要判断材料，也要沿着整条通路检查连接是否完整。"},
	"knowledge.circuit.observation": {"en": "Trace the connection between the gauges. Conductive material is useful only when the path is closed.", "zh": "观察仪表之间的连接。材料能导电还不够，电路也必须闭合。"},
	"knowledge.circuit.example_0": {"en": "CLOSED CIRCUIT\nA continuous metal connection lets current flow.", "zh": "闭合电路\n连续的金属连接为电流提供通路。"},
	"knowledge.circuit.example_1": {"en": "OPEN CIRCUIT\nA gap or insulating link interrupts the current.", "zh": "断开电路\n空隙或绝缘材料会中断电流。"},
	"knowledge.greenhouse.title": {"en": "How a plant makes its food", "zh": "植物怎样制造自己的食物？"},
	"knowledge.greenhouse.principle": {"en": "During photosynthesis, a plant uses light energy, water and carbon dioxide to make food, releasing oxygen. Carbon dioxide is an input; oxygen is a product. Changing one input can limit the process even when the other conditions are available.", "zh": "光合作用中，植物利用光能，把水和空气中的二氧化碳转化为食物，并释放氧气。二氧化碳是参与反应的原料，氧气是产生的结果。即使其他条件充足，缺少某一种必要条件也可能限制光合作用，因此实验时需要分别比较各个条件。"},
	"knowledge.greenhouse.observation": {"en": "The living panels imitate a leaf. Consider the inputs it needs and the products it releases.", "zh": "这些活体面板在模拟叶片。留意它需要什么，以及它会释放什么。"},
	"knowledge.greenhouse.example_0": {"en": "INPUTS\nLight supplies energy; water and carbon dioxide are used.", "zh": "需要的条件\n光提供能量，水和二氧化碳参与反应。"},
	"knowledge.greenhouse.example_1": {"en": "PRODUCTS\nThe plant makes food and releases oxygen.", "zh": "产生的结果\n植物制造食物，并释放氧气。"},
	"knowledge.time.title": {"en": "Estimating time from change", "zh": "从变化推测经过的时间"},
	"knowledge.time.principle": {"en": "When a process changes at a reasonably steady rate, the amount of change can help estimate elapsed time. The estimate depends on that rate staying similar. Compare several independent indicators before treating a timeline as reliable.", "zh": "如果某个过程以较稳定的速率变化，测量变化了多少，就能帮助估算经过的时间。这个估算依赖于速率没有明显改变。单独一个时钟或一个观察往往不足以证明时间线；把几个相互独立的指标放在一起核对，结论才更可靠。"},
	"knowledge.time.observation": {"en": "A clock gives one account of time. Compare it with other processes instead of trusting a single indicator.", "zh": "时钟提供了一种时间线索。还要与其他变化对照，不要只相信一个指标。"},
	"knowledge.time.example_0": {"en": "MEASURE A CHANGE\nA steady process can provide an approximate elapsed time.", "zh": "测量变化\n如果变化速率较稳定，可以估算经过了多久。"},
	"knowledge.time.example_1": {"en": "CROSS-CHECK\nIndependent indicators make an estimate more reliable.", "zh": "交叉核对\n用彼此独立的线索核对，结论才更可靠。"},
	"knowledge.light.title": {"en": "Mixing light is not mixing paint", "zh": "混合光，不等于混合颜料"},
	"knowledge.light.principle": {"en": "Red, green and blue are the primary colors used for additive light mixing. Combining light adds energy and can make a brighter result. Pigments work differently: they absorb parts of the light. Do not apply paint-mixing rules to this light console.", "zh": "红、绿、蓝是光的加色混合所使用的三种原色。把光叠加在一起会增加光能，使结果更亮。颜料混合则不同：颜料会吸收部分光线。所以在这个混光控制台上，应当判断各光源叠加的结果，不能直接套用混合颜料的经验。"},
	"knowledge.light.observation": {"en": "The console combines light sources. Adding light makes the result brighter, unlike adding pigments.", "zh": "控制台叠加的是光源。光越叠加越亮，这与混合颜料不同。"},
	"knowledge.light.example_0": {"en": "TWO LIGHTS\nRed + green = yellow.\nGreen + blue = cyan.", "zh": "两种光\n红光 + 绿光 = 黄光\n绿光 + 蓝光 = 青光"},
	"knowledge.light.example_1": {"en": "THREE LIGHTS\nSimilar red, green and blue light together approach white.", "zh": "三种光\n强度接近的红、绿、蓝光叠加，接近白光。"},
	"hall.route_exposed": {"en": "OUTSIDE THE GUIDE · THE GUARDIAN CAN CATCH YOU", "zh": "已离开引导范围 · 守卫可以抓住你"},
	"hall.route_warning": {"en": "RETURN TO THE FOOTPRINTS · YOU ARE EXPOSED", "zh": "回到脚印附近 · 你正在暴露"},
	"hall.recording_requires_dev": {"en": "Enable developer mode with 0 before recording a route.", "zh": "先按 0 开启开发模式，再录制路线。"},
	"hall.recording_started": {"en": "Recording Hall route. Shift+0 cancels; reaching Chemistry saves.", "zh": "正在录制大厅路线。Shift+0 取消，到达化学室门前保存。"},
	"hall.recording_cancelled": {"en": "Recording cancelled. The staged tutorial is active again.", "zh": "已取消录制，恢复分阶段新手引导。"},
	"hall.route_compass": {"en": "GLOWING FOOTPRINTS  ·  {direction}", "zh": "发光的脚印  ·  {direction}"},
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
		"en": "The brass core is warm: its reaction creates a new substance.\n\nA chemical change creates new substances. Burning paper is chemical; melting ice, breaking glass and dissolving sugar are physical changes.\n\nChoose FILE KNOWLEDGE to record this rule in your notebook and reveal the path to Chemistry.",
		"zh": "黄铜核心仍有余温：内部的反应正在产生新的物质。\n\n化学变化会产生新物质。燃烧纸张是化学变化；冰融化、玻璃破碎和糖溶解是物理变化。\n\n点击「收录知识」，将这条规则记入笔记，并开启通往化学室的引导。",
	},
	"hall.chemistry_core_continue": {"en": "FILE KNOWLEDGE", "zh": "收录知识"},
	"hall.chemistry_enter": {"en": "ENTER THE CHEMISTRY ROOM", "zh": "进入化学室"},
	"transition.hall_title": {"en": "CASTLE HALL", "zh": "城堡大厅"},
	"transition.hall_detail": {"en": "NORTH WING SIGNAL DETECTED", "zh": "已侦测到北翼讯号"},
	"transition.hall_alert_detail": {
		"en": "GUARDIAN ALERT · MOVE BEFORE IT CLOSES THE DISTANCE",
		"zh": "守卫已经警觉 · 趁它逼近前立刻行动",
	},
	"transition.wake_room_detail": {
		"en": "SOUTH CHAMBER · RETURN ROUTE",
		"zh": "南侧房间 · 返回苏醒现场",
	},
	"transition.chemistry_room_detail": {
		"en": "WEST LABORATORY · MATERIAL ANALYSIS",
		"zh": "西侧实验室 · 物质分析",
	},
	"transition.greenhouse_room_detail": {
		"en": "EAST WING · LIVING EVIDENCE",
		"zh": "东侧区域 · 活体证据",
	},
	"transition.circuit_room_detail": {
		"en": "NORTH-WEST WING · POWER SYSTEMS",
		"zh": "西北区域 · 电力系统",
	},
	"transition.library_detail": {
		"en": "NORTH-EAST WING · RESTRICTED RECORDS",
		"zh": "东北区域 · 限制档案",
	},
	"transition.dining_hall_detail": {
		"en": "WEST WING · SERVICE TRAIL",
		"zh": "西侧区域 · 仆役通道线索",
	},
	"transition.final_deduction_room_detail": {
		"en": "NORTH VAULT · DEDUCTION PROTOCOL",
		"zh": "北侧密库 · 启动推理程序",
	},
	"transition.retry_title": {"en": "REOPENING THE TRAIL", "zh": "重新追踪线索"},
	"transition.retry_detail": {
		"en": "EVIDENCE SECURED · RESTORING THIS ROOM",
		"zh": "证物已保留 · 正在恢复当前房间",
	},
	"transition.checkpoint_title": {"en": "RETURNING TO CHECKPOINT", "zh": "返回检查点"},
	"transition.checkpoint_detail": {
		"en": "CASE NOTES INTACT · RESTORING LAST ENTRY",
		"zh": "案件笔记完好 · 正在恢复上次入口",
	},
	"transition.menu_title": {"en": "CASE ARCHIVE", "zh": "案件档案库"},
	"transition.menu_detail": {
		"en": "SECURING FIELD NOTES · RETURNING TO INTAKE",
		"zh": "正在保存现场笔记 · 返回案件接收处",
	},
	"update.kicker": {"en": "CASE ARCHIVE  /  SYSTEM NOTICE", "zh": "案件档案库  /  系统通告"},
	"update.title": {"en": "A NEW GAME UPDATE IS READY", "zh": "游戏更新已经准备完成"},
	"update.body": {
		"en": "The latest fixes and improvements have finished downloading.\n\nRestart now to use the new build, or continue this session and restart later. Your current checkpoint will be saved before restarting.",
		"zh": "最新修复与改进已经下载完成。\n\n你可以立即重启以使用新版本，也可以继续本次游戏、稍后再重启。立即重启前会先保存当前检查点。",
	},
	"update.restart": {"en": "RESTART NOW", "zh": "立即重启"},
	"update.later": {"en": "REMIND ME LATER", "zh": "稍后再说"},
	"update.restarting": {"en": "SAVING CASE · APPLYING UPDATE…", "zh": "正在保存案件 · 应用更新…"},
	"update.save_failed": {
		"en": "The current checkpoint could not be saved. The update was not applied.",
		"zh": "当前检查点无法保存，因此尚未应用更新。",
	},
	"update.activate_failed": {
		"en": "The update could not restart yet. Continue playing and try again later.",
		"zh": "暂时无法重启更新。请继续游戏，稍后再试。",
	},
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
