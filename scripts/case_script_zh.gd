class_name CaseScriptZh

## 房间正文的中文译本。
##
## 键是**英文原句本身**，取代另起一套 id：房间脚本里的英文字面量既是原文
## 也是查找键，所以接入翻译时一个调用点都不用改，也不会出现"改了英文忘了
## 改 id"这种断链。查不到就原样返回英文，缺译只是没翻译，不会变成乱码或
## 空白。
##
## Mrs. Lin 的语气基调：**老师对着自己最器重的学生**。
## 具体就是——
##   · 相信对方能想明白，所以把话说清楚，而不是说简单；
##   · 答错时指出思路岔在哪，不说"没关系呀"这类哄小孩的话；
##   · 答对时自然地往下推一层，不夸张地捧；
##   · 用"你"，不用"小朋友"；专业名词照实说，必要时补一句解释。
## 玩家自述（"You"）则是侦探笔记式的短句：观察在前，判断在后。

const LINES: Dictionary = {
	# ---------- 温室 ----------
	"The great stone planter hums faintly. The flowers seem to turn toward you.":
		"石花坛在低低地嗡鸣。那些花，似乎正朝你的方向转过来。",
	"A gardener's workbench. Tools, pots and an open handbook are spread across it.":
		"园丁的工作台。工具、花盆，还有一本摊开的手册，铺了一整张桌子。",
	"A cluster of flower pots. Blue blossoms peek from between the leaves.":
		"一丛花盆挤在一起。蓝铃花从叶片之间探出头来。",
	"A heavy leafy plant, with small blue flowers scattered through its stems.":
		"一株厚叶植物，茎秆间零星缀着几朵蓝色小花。",
	"The greenhouse gate. Engraved emblems flank the arch.":
		"温室的大门。拱顶两侧刻着纹章。",
	"A long raised bed of blue blossom. The supply valves for light, water and air all feed into it.":
		"一条长长的抬高花坛，种满蓝铃花。光照、水分和空气的供给阀，全都接到这里。",
	"A long raised bed of moonleaf. The silver pods open and close, each on its own slow rhythm.":
		"一条长长的抬高花坛，种着月叶。银色的花苞一开一合，每一株都按自己的节奏来。",
	"Red, green and blue combine into pale neutral light. The additive color key reveals the hidden archive text.":
		"红、绿、蓝叠加成了近乎中性的淡白光。加色这把钥匙，把档案里藏着的字迹显了出来。",

	"[center][b]A Torn Note Page[/b][/center]\n\nHalf a page of handwriting, torn across the middle:\n\n\"...the gardener swears the greenhouse was locked. Yet [color=#7a2e2e]dark pollen[/color] — the deep-room kind, not from any plant here — clings to the tool handles. It does not prove the gardener used the route; it only proves that maintenance equipment entered the deep room.\n\nIf that pollen came from outside, someone entered the greenhouse through the maintenance tunnel.\n\nThe gardener is the obvious suspect. Obvious is not the same as proven. You know how often I say that.\"":
		"[center][b]撕下的半页笔记[/b][/center]\n\n半页手写字，从中间被撕开：\n\n「……园丁一口咬定温室当时是锁着的。可是工具把手上沾着[color=#7a2e2e]深色花粉[/color]——深室那一种，这里任何一株植物都产不出来。这不能证明园丁走过那条路，它只能证明：维修器具进过深室。\n\n如果那些花粉来自外面，就有人是从维修隧道进的温室。\n\n园丁是最显眼的嫌疑人。显而易见，不等于已被证明。我这句话说过多少遍，你是知道的。」",

	# ---------- 线路房 ----------
	"Wrong sequence. The circuit resets. Follow the repair map from step 1.":
		"顺序不对，电路复位了。照着维修图，从第 1 步重新来。",

	# ---------- 餐厅 ----------
	"The Last Dinner Timeline":
		"最后一顿晚餐的时间线",
	"A Clock Stopped at Midnight":
		"停在午夜的钟",

	# ---------- 化学室 ----------
	"Mrs. Lin's Lab Notebook":
		"林女士的实验笔记",
	"You are already working this out.":
		"你正在推算这件事。",
	"The sample tray is already open.":
		"样本盘已经打开了。",

	# ---------- 大厅知识展品（存入侦探笔记的版本） ----------
	"Chemistry Room Knowledge": "化学室知识",
	"Circuit Room Knowledge": "电路室知识",
	"Dining Hall Knowledge": "餐厅知识",
	"Greenhouse Room Knowledge": "温室知识",
	"Library Knowledge": "图书馆知识",

	# ---------- 侦探笔记：早期线索 ----------
	"A Broken Key": "半截钥匙",
	"The Candle Note": "烛火笔记",
	"The Master's Door Riddle": "主人的门谜",
	"The Master's Journal": "主人的日志",
	"The Science of Flame": "火焰背后的道理",
	"[center][b]A Broken Key[/b][/center]\n\nA rusted key fragment found near the [color=#7a2e2e]laboratory door[/color]. It seems to belong to a [color=#4a306d]much larger key[/color]...":
		"[center][b]半截钥匙[/b][/center]\n\n在[color=#7a2e2e]实验室门[/color]附近捡到的一段锈蚀钥匙。看形制，它原本属于一把[color=#4a306d]大得多的钥匙[/color]……",
	"[center][b]The Candle Note[/b][/center]\n\nA flame cannot keep burning without [color=#7a2e2e]oxygen[/color] from the air. If the air supply is blocked, the flame weakens and dies.":
		"[center][b]烛火笔记[/b][/center]\n\n火焰离开空气里的[color=#7a2e2e]氧气[/color]就烧不下去。一旦断了供气，火苗会先变弱，然后熄灭。",
	"[center][b]The Master's Door Riddle[/b][/center]\n\nTo whoever finds this —\n\nThe master of this castle [color=#4a306d]loved knowledge[/color]. They say every door in this castle holds a [color=#7a2e2e]single question[/color].\n\nAnswer it correctly, and even without a key, the door will open.\n\nIf you are reading this... I may already be gone.\n\n[color=#4a306d]— Mrs. Lin[/color]":
		"[center][b]主人的门谜[/b][/center]\n\n致捡到这张纸的人——\n\n这座城堡的主人[color=#4a306d]珍视知识[/color]。据说堡里的每一扇门，都守着[color=#7a2e2e]一个问题[/color]。\n\n把它答对，纵使手里没有钥匙，门也会开。\n\n如果你正在读这段话……我大概已经不在了。\n\n[color=#4a306d]—— 林[/color]",
	"[center][b]The Master's Journal[/b][/center]\n\nA worn leather journal. Its pages speak of [color=#4a306d]ancient knowledge locks[/color] and a [color=#7a2e2e]single key of understanding[/color]...":
		"[center][b]主人的日志[/b][/center]\n\n一本磨损的皮面日志。字里行间反复提到[color=#4a306d]古老的知识锁[/color]，以及那把[color=#7a2e2e]唯一的、名为「理解」的钥匙[/color]……",
	"[center][b]The Science of Flame[/b][/center]\n\nA flame cannot keep burning without [color=#7a2e2e]oxygen[/color] from the air. If the air supply is blocked, the flame weakens and dies.\n\n[color=#4a306d]This answers the knowledge lock on the door: what does a flame need from the air to keep burning?[/color]":
		"[center][b]火焰背后的道理[/b][/center]\n\n火焰离开空气里的[color=#7a2e2e]氧气[/color]就烧不下去。一旦断了供气，火苗会先变弱，然后熄灭。\n\n[color=#4a306d]门上那道知识锁问的正是这个：火焰要持续燃烧，需要从空气里得到什么？[/color]",

	# ---------- 拾取弹窗：钥匙与道具 ----------
	"Wake Room Key": "苏醒室钥匙",
	"Chemistry Room Key": "化学室钥匙",
	"Greenhouse Room Key": "温室钥匙",
	"Circuit Room Key": "电路室钥匙",
	"Dining Hall Key": "餐厅钥匙",
	"Library Room Key": "图书馆钥匙",
	"Service Corridor Key": "服务通道钥匙",
	"Final Room Key": "终局档案室钥匙",
	"Final Room Key Fragment (%d/3)": "终局钥匙碎片（%d/3）",
	"Circuit Repair Map": "线路维修图",

	# ---------- 拾取弹窗：证物 ----------
	"Evidence: Fake Red Stain": "证物：伪造的红色污渍",
	"Evidence: Greenhouse Pollen": "证物：温室花粉",
	"Evidence: Deliberate Short Circuit": "证物：人为制造的短路",
	"Evidence: Clock Stopped by Hand": "证物：被人为停住的钟",
	"Evidence: The Last Dinner Timeline": "证物：最后一顿晚餐的时间线",
	"Evidence: Torn Service Cloth": "证物：撕破的侍应布",
	"Evidence: Violet Conductive Fiber": "证物：紫色导电纤维",
	"Evidence: Violet Fiber in Mrs. Lin's Hand": "证物：林女士手中的紫色纤维",
	"Evidence: Violet Grit in the Drag Trail": "证物：拖行痕迹里的紫色颗粒",
	"Evidence: Torn Maintenance Glove Fragment": "证物：维修手套的残片",
	"Evidence: Mechanic's Missing Right Glove": "证物：机械师失踪的右手手套",
	"Evidence: Hidden Dial Symbols": "证物：刻度盘上的隐藏符号",
	"Evidence: Final Archive Document": "证物：终局档案文件",

	# ---------- 温室 ----------
	"Greenhouse Herbs": "温室草药",
	"Greenhouse Irrigation Record": "温室灌溉记录",
	"Mrs. Lin's Greenhouse Notes": "林女士的温室笔记",
	"Gathered %d %s from the bed.": "从这条花坛采到了 %d 份%s。",
	"You step back from the bed without gathering anything.":
		"你从花坛边退开，什么也没采到。",
	"This plant has already been harvested. The other pot may still have Blue Blossom ready.":
		"这一株已经采过了。另一盆或许还有蓝铃花可以摘。",
	"Blue Blossom can be gathered here and used at the Chemistry Room alchemy table to brew potions.":
		"这里可以采到蓝铃花，拿去化学室的炼金台就能配药。",
	"The Gardener's irrigation pump shares part of the castle maintenance circuit. The circuit_repair_map was a legitimate copy kept for pump and water-control repairs. It explains why the map was on the workbench, but not the pollen on maintenance equipment.":
		"园丁的灌溉泵与城堡维修线路共用一段电路。那张线路维修图是为检修水泵和水控留的正当副本——它解释了图为什么会在工作台上，但解释不了维修器具上的花粉。",
	"I have tended these rooms long enough to know what belongs here. That dark pollen does not.\n\nThe irrigation pump shares a maintenance circuit with the lower halls. That explains the repair map on my bench, but it does not explain who carried deep-room traces into my greenhouse.":
		"这些屋子我照料了这么多年，什么东西该在这儿、什么不该，我心里有数。那种深色花粉，不该在这儿。\n\n灌溉泵和下层厅堂共用一段维修电路，这能解释我台子上那张维修图。但它解释不了——是谁把深室的痕迹带进了我的温室。",
	"The greenhouse gate clicks open just enough to reveal a hidden brass hook. A dark metal key threaded with violet current hangs from it.\n\nThe Circuit Room Key. The next room is waiting beyond the greenhouse trail.":
		"温室的门「咔」地松开一道缝，露出里面一枚暗藏的黄铜挂钩。钩上垂着一把深色金属钥匙，纹路里游着紫色的电流。\n\n电路室钥匙。穿过温室这条路，下一个房间正等着你。",
	# ---------- 线路房 ----------
	"A cluttered workbench. Tools, coils and an open journal cover the surface. The last entry is cut off mid-sentence.":
		"一张堆满东西的工作台。工具、线圈、一本摊开的日志铺满台面。最后一条记录写到一半就断了。",
	"A massive arcane generator. Blue arcs crackle behind its glass chamber. The mechanism still hums.":
		"一台巨大的秘能发电机。玻璃腔体后面蓝色电弧噼啪作响，机构仍在低鸣。",
	"A reinforced equipment cabinet. Its padlock is firmly shut, but the keyhole glints as if recently used.":
		"一只加固过的器材柜。挂锁扣得很牢，但锁孔泛着光——像是最近才被人开过。",
	"A left-side power switch. Its purpose is unclear.":
		"左侧的一个电闸。作用不明。",
	"A right-side power switch. Its purpose is unclear.":
		"右侧的一个电闸。作用不明。",
	"A large master power switch. Its purpose is unclear.":
		"一个大号总闸。作用不明。",
	"The switch clicks into position. Continue to the next numbered switch.":
		"电闸咔一声推到位。按编号继续下一个。",
	"A Stained Note Page": "沾污的笔记页",
	"Violet Insulating Weave": "紫色绝缘编织物",
	"Mechanic's Maintenance Glove Record": "机械师的维修手套登记",
	"SEALED ARCHIVE II — The Forged Instruction": "密封档案 II —— 被伪造的命令",
	"The castle's electrical maintenance gloves and cable wraps use a distinctive violet insulating weave. It is a maintenance material, not proof that one particular worker committed a crime.":
		"城堡的电气维修手套和线缆包覆，用的都是一种很好认的紫色绝缘编织物。这是一种维修材料——它本身并不能证明某一个人犯了案。",
	"One pair of maintenance gloves was assigned to the Mechanic. The right glove had previously been repaired with a distinctive copper-thread cross-stitch. The right glove is now missing after the blackout. The same access log records the Mechanic's statement that he was checking the west-side electrical system during the blackout; the Dining timeline will test whether that account is possible.":
		"有一副维修手套登记在机械师名下。其中右手那只曾用铜线十字缝补过，针脚很好认。停电之后，这只右手手套不见了。同一份出入记录里还有机械师本人的说法：停电期间他在检查西侧电力系统——这个说法成不成立，餐厅那条时间线会替你检验。",
	"The false-bottom cabinet has nothing more to give. The damaged instruction slip is already in your notes.":
		"那只带假底的柜子再没有别的东西了。破损的命令便条已经在你的笔记里。",
	"Mechanic: The blackout did not start here. Someone used the workshop's maintenance route, then left the generators to take the blame.":
		"机械师：停电不是从这儿开始的。有人走了工坊的维修通道，然后把锅甩给发电机。",

	# ---------- 餐厅 ----------
	"The long banquet table still bears the remnants of a feast. Wine stains and scattered cutlery tell a hurried story.":
		"长餐桌上还留着宴席的残迹。酒渍和散落的刀叉，讲的是一个仓促收场的故事。",
	"The clock has stopped at midnight. Its pendulum hangs motionless.":
		"钟停在午夜。钟摆一动不动地垂着。",
	"The hearth crackles warmly. Embers glow beneath the worn mantel.":
		"壁炉噼啪作响，暖意未散。磨旧的炉台下面，余烬还亮着。",
	"The fire is warm, but no log has burned evenly. Ash marks continue behind the hearth toward the barred wall door.":
		"火还是热的，但没有一根柴是均匀烧过的。灰痕从炉膛后面一路延伸，指向那扇被闩住的墙门。",
	"A heavy sideboard laden with dishes and silver. A torn red cloth hangs over its front edge.":
		"一张沉重的餐边柜，摆满盘碟和银器。前沿垂着一块撕破的红布。",
	"A tall storage cabinet. Cookware and jugs crowd its dark shelves.":
		"一只高身储物柜。炊具和陶罐把暗处的隔板塞得满满当当。",
	"A heavy wooden door set in the stone wall. It is barred from the other side.":
		"石墙里嵌着一扇厚重的木门。门闩在另一侧。",
	"A strip of red fabric is caught on the silver drawer. Its threads match the service uniforms, not the table decorations.":
		"银器抽屉上挂着一条红布。它的织线对得上侍应制服，而不是桌面装饰。",
	"A folded kitchen record names the service passage as the only route that bypasses the main corridor. The last entry is signed just before midnight.":
		"一份折起来的厨房记录写明：服务通道是唯一能绕开主走廊的路线。最后一条签名，就落在午夜之前。",
	"The pendulum was stopped by hand. The minute hand is bent toward twelve, as if someone wanted the room to remember a false time.":
		"钟摆是被人用手按停的。分针被掰向十二点——像是有人要让这间屋子记住一个假的时刻。",
	"The pendulum was stopped by hand. The minute hand is bent toward twelve, as if someone wanted the room to remember a false time. Every other indicator in this room disagrees with it, and they all agree with each other.":
		"钟摆是被人用手按停的。分针被掰向十二点——像是有人要让这间屋子记住一个假的时刻。这屋里其余每一条线索都与它相左，而它们彼此之间却完全吻合。",
	"The plates were cleared at 11:40. The clock stopped at midnight, but the fireplace ash is fresh. Someone moved through the hall during the missing twenty minutes.":
		"餐盘是 11:40 撤下的。钟停在午夜，可壁炉的灰是新的。在这消失的二十分钟里，有人穿过了这个厅。",
	"You reconstructed %d of the timings before stepping back from the clock.":
		"你在离开钟前推算出了 %d 个时刻。",
	"The Service Corridor Key fits the hidden lock. The passage lies behind the hall's east wall — the way back is marked in the Castle Hall.":
		"服务通道钥匙对上了那把暗锁。通道就在大厅东墙后面——回去的路已经标在城堡大厅里了。",
	"A Torn Red Cloth": "撕破的红布",
	"The Last Twenty Minutes": "消失的二十分钟",
	"The Service Passage Record": "服务通道记录",
	"Mrs. Lin's Last Dining Note": "林女士在餐厅留下的最后一条笔记",
	"SEALED ARCHIVE I — The Butler's Pressure": "密封档案 I —— 管家的处境",
	"The narrow compartment behind the service ledger is empty. Its private archive has already been copied.":
		"服务台账后面那道窄格已经空了。里面的私人档案早被誊抄走了。",

	# ---------- 大厅：短句与标题 ----------
	"A Hidden Library Key":
		"藏起来的图书馆钥匙",
	"Corridor Fragments":
		"走廊纸片",
	"Maintenance Route":
		"维修路线",
	"Three Ashford Seal Stations":
		"阿什福德三处封印台",
	"Violet Fiber on the Pipe":
		"管道上的紫色纤维",
	"The Trail Behind the Banquet":
		"宴席之后的拖痕",
	"Ashford Verification Relay System":
		"阿什福德验证中继系统",
	"I think I know.":
		"我大概想明白了。",
	"A. Real blood exposed to oxygen":
		"A. 真血接触氧气后的颜色",
	"B. Indicator solution reacting with a basic cleaner":
		"B. 指示剂与碱性清洁剂发生的反应",
	"Fragment %d/%d:\n\n%s":
		"第 %d/%d 块碎片：\n\n%s",
	"Not yet. We still need enough evidence before making a final accusation.\n\n":
		"还不到时候。证据不够，就还不能下最终结论。\n\n",
	"\n\nThis room is not developed yet.":
		"\n\n这个房间还没有做完。",
	"This lock uses an electrical rule, but we have not confirmed the rule yet.\n\nLook nearby for a maintenance note or circuit clue before forcing an answer.":
		"这道锁用的是一条电学规则，但我们还没把它确认下来。\n\n先在附近找找维修笔记或电路线索，别急着硬答。",
	"The lock is dormant — a physical key is required before the question will appear.\n\nSearch the rooms you have already explored.":
		"锁还睡着——得先有实体钥匙，问题才会浮现。\n\n回你已经走过的房间里找找。",
	"The fourth fragment locks into place. The Final Room Key is complete.":
		"第四块碎片扣了进去。终局档案室钥匙，完整了。",
	"The dark trail contains violet grit and a chemical smell. Something heavy was dragged from the workshop through the service passage.":
		"那道暗痕里混着紫色颗粒，还带着化学品的气味。有重物被人从工坊一路拖过服务通道。",

	# ---------- 大厅：三段调查问答 ----------
	"This red liquid looks like blood at first glance, but a good detective never relies on color alone.\n\nWhat do you think caused the red color?":
		"这摊红色液体乍看像血，可一个好侦探从不只凭颜色下判断。\n\n你觉得，这个红是怎么来的？",
	"Question:\nWhat most likely caused the red color?\n\nUse what you observed. A good detective does not rely on color alone.":
		"问题：\n这个红色最可能是什么造成的？\n\n用你亲眼观察到的东西。好侦探不会只看颜色。",
	"Correct.\n\nExcellent reasoning. The red color is likely caused by an indicator reacting with a basic cleaning substance. This means the stain may have been staged, not left by the victim.\n\nEvidence added: Fake Red Stain":
		"答对了。\n\n推得很漂亮。这个红多半是指示剂遇上碱性清洁物质产生的。也就是说，这摊污渍可能是被人做出来的，而不是死者留下的。\n\n已加入证物：伪造的红色污渍",
	"Not quite.\n\nThe important clue is not just the color. If an indicator solution mixes with a basic cleaner, it can turn red or pink. This stain may be fake.\n\nEvidence added: Fake Red Stain":
		"还差一点。\n\n关键的线索不只是颜色。指示剂溶液一旦混进碱性清洁剂，就会变红或变粉。这摊污渍很可能是假的。\n\n已加入证物：伪造的红色污渍",
	"That's okay. A good detective knows when to ask for help.\n\nThe red color may come from an indicator solution reacting with a basic cleaner. So this does not prove it is blood. Someone may have staged the crime scene.\n\nEvidence added: Fake Red Stain":
		"没问题。知道什么时候该开口求助，本身就是好侦探的一部分。\n\n这个红可能来自指示剂与碱性清洁剂的反应——所以它证明不了那是血。有人可能布置过这个现场。\n\n已加入证物：伪造的红色污渍",
	"There is yellow pollen on the door handle. That may not look important, but pollen can connect a person to a specific place.\n\nWhat do you think this clue tells us?":
		"门把手上有黄色花粉。这东西看着不起眼，但花粉能把一个人和一个特定的地方连起来。\n\n你觉得这条线索说明了什么？",
	"Question:\nWhat is the best scientific use of this pollen evidence?\n\nThink about how small traces can connect a suspect to a specific place.":
		"问题：\n这份花粉证据，科学上最好的用法是什么？\n\n想一想：微量痕迹是怎么把嫌疑人和某个具体地点联系起来的。",
	"Correct.\n\nGood reasoning. Pollen grains can help identify where someone has been, especially if the pollen matches a plant from a specific room such as the greenhouse.\n\nEvidence added: Greenhouse Pollen":
		"答对了。\n\n思路很对。花粉粒能帮我们判断一个人去过哪里——尤其当这些花粉能对上某个特定房间（比如温室）里的植物时。\n\n已加入证物：温室花粉",
	"Not quite.\n\nPollen can act like biological trace evidence. If it matches a plant from the greenhouse, it may show that someone recently came from there.\n\nEvidence added: Greenhouse Pollen":
		"还差一点。\n\n花粉可以充当生物微量物证。如果它能对上温室里的某种植物，就可能说明有人刚从那边过来。\n\n已加入证物：温室花粉",
	"That's okay. Pollen is useful because different plants can produce different pollen patterns. If we match this pollen to the greenhouse, it can connect a suspect to that location.\n\nEvidence added: Greenhouse Pollen":
		"没关系。花粉之所以有用，是因为不同植物产出的花粉形态各不相同。只要把这份花粉和温室对上，就能把嫌疑人和那个地点连起来。\n\n已加入证物：温室花粉",
	"The wall panel has burn marks, and the lights went out right before the chase began.\n\nThis may not be an accident. What do you think caused the blackout?":
		"墙板上有灼烧痕迹，而灯正是在追逐开始前一刻灭的。\n\n这未必是意外。你觉得停电是什么造成的？",
	"Question:\nWhat is the best explanation for the burned circuit panel?\n\nUse the burn marks and blackout as evidence.":
		"问题：\n烧焦的电路板，最合理的解释是什么？\n\n把灼痕和停电这两件事当作证据一起用。",
	"Correct.\n\nExactly. A short circuit can allow too much current to flow, producing heat and burn marks. This suggests the blackout may have been caused deliberately.\n\nEvidence added: Deliberate Short Circuit":
		"答对了。\n\n正是如此。短路会让过大的电流通过，从而产生热量和灼痕。这说明停电很可能是人为造成的。\n\n已加入证物：人为制造的短路",
	"Not quite.\n\nThe burn marks suggest excess current and heat. A short circuit could explain the sudden blackout, which means someone may have caused it on purpose.\n\nEvidence added: Deliberate Short Circuit":
		"还差一点。\n\n灼痕说明电流过大、温度过高。短路可以解释这场突然的停电——也就意味着，可能有人是故意的。\n\n已加入证物：人为制造的短路",
	"A short circuit creates a path with very low resistance. That can cause a large current, heat, and burn marks.\n\nSo the blackout may not be accidental. Someone may have used the circuit panel to create confusion.\n\nEvidence added: Deliberate Short Circuit":
		"短路会形成一条电阻极低的通路，因而可能产生很大的电流、热量和灼痕。\n\n所以这场停电未必是意外。有人可能借着电路板制造了混乱。\n\n已加入证物：人为制造的短路",

	# ---------- 大厅：叙事与关键节点 ----------
	"Detective, you are inside Shadow Castle.\n\nThis castle once belonged to Lord Ashford, a scholar who believed knowledge was the only true key.\n\nHe designed many doors as knowledge locks. They do not open with ordinary keys. They open when someone understands the question written on them.":
		"侦探，你现在就在影堡里。\n\n这座城堡曾属于阿什福德勋爵——一位学者，他坚信知识是唯一真正的钥匙。\n\n他把许多扇门设计成了知识锁。它们不认普通钥匙，只认「有人真的弄懂了」这件事。",
	"Tonight, a crime scene has been staged inside Shadow Castle, and the murderer is still moving through the halls.\n\nThis castle is not a normal building. Lord Ashford, the former owner, believed that knowledge was the only true key. He designed many doors as knowledge locks. They do not open with ordinary keys. They open only when someone understands the question written on them.\n\nThat means you should not guess randomly. Look around first. Read notes, inspect strange objects, talk to suspects, and pay attention to scientific clues. The answer to a locked door is usually hidden somewhere nearby.\n\nYour investigation has three goals:\n\n1. Explore the castle safely.\n2. Learn from clues and use STEM knowledge to open locked paths.\n3. Collect evidence, question suspects, and identify the real culprit.\n\nUse the Evidence Board to review evidence. Use the Knowledge Journal to review concepts you have learned. Use Mission Objectives when you are unsure what to do next.\n\nControls:\nWASD - Move\nE - Interact\nB - Evidence Board\nK - Knowledge Journal\nO - Mission Objectives\nR - Restart\nM - Main Menu":
		"今夜，影堡里有人布置了一处犯罪现场，而凶手仍在厅堂之间走动。\n\n这不是一座寻常的建筑。前主人阿什福德勋爵相信，知识是唯一真正的钥匙。他把许多扇门做成了知识锁：它们不认普通钥匙，只有当有人真的读懂了门上那个问题，它们才会开。\n\n所以，不要瞎猜。先四处看看：读笔记，检查那些不对劲的东西，找嫌疑人谈话，留意科学线索。一扇锁着的门，答案通常就藏在离它不远的地方。\n\n你这次调查有三个目标：\n\n1. 安全地探索这座城堡。\n2. 从线索里学到东西，用 STEM 知识打开被锁住的路。\n3. 收集证据、询问嫌疑人，找出真正的凶手。\n\n用证物板复查证据，用知识日志复习学过的概念；不确定下一步做什么时，看任务目标。\n\n操作：\nWASD - 移动\nE - 交互\nB - 证物板\nK - 知识日志\nO - 任务目标\nR - 重新开始\nM - 主菜单",
	"We have three major pieces of evidence now:\n\n1. The red stain may have been staged.\n2. The pollen links someone to the greenhouse area.\n3. The blackout was likely caused by a deliberate short circuit.\n\nWho do you accuse?":
		"现在我们手上有三条主要证据：\n\n1. 那摊红色污渍可能是布置出来的。\n2. 花粉把某个人和温室一带联系了起来。\n3. 停电很可能是人为短路造成的。\n\n你要指认谁？",
	"The final lock accepts the chain of knowledge.\n\nMatter, life, energy, and the passage of time all point to one connected investigation.\n\nThe Final Room door is open.":
		"最后一道锁，认下了这一整条知识链。\n\n物质、生命、能量，还有时间的流逝——它们指向的是同一桩案子。\n\n终局档案室的门开了。",
	"The Service Corridor Key fits the hidden lock. The wall panel slides back, revealing a narrow passage behind the hall.\n\nThe chase has gone quiet, but the silence feels worse than the footsteps. Whatever happened in this castle passed through here.":
		"服务通道钥匙对上了那把暗锁。墙板向后滑开，露出大厅背后一条狭窄的通道。\n\n追逐声安静下来了，但这份安静比脚步声更让人不安。这座城堡里发生过的事，都从这里经过。",
	"A slim brass key stamped with the library's spiral archive seal, hidden among the jars of the storage rack in the hall's south-east corner. The archive is optional — but it may hold information others wanted buried.":
		"一把细长的黄铜钥匙，压着图书馆的螺旋档案印，藏在大厅东南角储物架的罐子中间。那间档案室不是必去的——但里面可能存着某些人希望被埋掉的东西。",
	"A violet thread is caught on the copper pipe.\n\nIt matches the distinctive insulating weave identified on the Circuit Room maintenance gloves and cable wraps. A short strand of copper-colored repair thread is caught in the same material. It may have come from previously repaired maintenance gear, but it does not identify one worker by itself. The person who used this passage carried equipment from the workshop.":
		"铜管上挂着一根紫色细线。\n\n它和线路房维修手套、线缆包覆上那种很好认的绝缘编织物是同一种。同一处还缠着一小段铜色的修补线。它可能来自被修补过的维修装备，但仅凭这一点，还不足以指认具体某个人。",
	"A violet thread caught on the pipe matches the Circuit Room maintenance weave. A short copper-colored repair thread is caught in the same material; it may come from repaired maintenance gear, but it is not enough to identify one worker by itself.":
		"管道上挂着的紫色细线，与线路房的维修编织物一致。同一材料上还缠着一小段铜色修补线；它可能来自修补过的维修装备，但单凭它本身，不足以认定某一个人。",
	"A dark trail begins at the passage door and ends beside the maintenance panel.\n\nIt is not a pool of blood: the edges contain violet grit and a sharp chemical smell. Something heavy was dragged through here after the blackout — equipment from the workshop.":
		"一道暗痕从通道门口起，一直延伸到维修面板旁边。\n\n那不是血泊：边缘有紫色颗粒，还有一股刺鼻的化学气味。停电之后，有重物被从这里拖过去——是工坊里的器材。",
	"Behind the panel is a hand-drawn route: Dining Hall → service passage → Final Room. One line is circled twice: the gate will not open without the reassembled key.\n\nA fourth machine fragment is wedged behind the panel — the physical Access / Route seal, the final piece of the Final Room Key.":
		"面板后面是一条手绘路线：餐厅 → 服务通道 → 终局档案室。有一行被圈了两遍：钥匙不拼齐，那道门就不会开。\n\n面板后面还卡着第四块机件碎片——也就是「通路 / 路线」那枚实体封印。",
	"The three fragments fit together:\n\n\"He uses the service corridor behind the west wall. The route ends at the Final Room door.\"\n\nThe last page adds: the Final Room Key was split into three pieces and hidden inside the machines scattered across the hall.":
		"三张碎片拼上了：\n\n「他走的是西墙后面的服务通道。那条路的尽头，就是终局档案室的门。」\n\n最后一页补了一句：终局档案室钥匙被拆成三块，藏进了散落在大厅各处的机器里。",
	"Mrs. Lin's torn pages: someone uses the service corridor behind the east wall, and the route ends at the Final Room door. The complete Final Room Key is split into four seals: three in the hall stations and one behind the Service Corridor maintenance panel.":
		"林女士被撕下的那几页：有人在走东墙背后的服务通道，路线终点是终局档案室的门。完整的终局钥匙被拆成四枚封印——三枚在大厅的验证台里，一枚在服务通道的维修面板后面。",
	"The three hall stations each held one Final Room Key seal. They are now empty, but the key is still incomplete. Matter, Life and Energy have been verified. Mrs. Lin's route points to the Service Corridor maintenance panel for the fourth Access / Route seal.":
		"大厅这三处验证台，各自存着一枚终局钥匙封印。现在它们空了，可钥匙还不完整。物质、生命、能量都已验证。按林女士的路线，第四枚「通路 / 路线」封印在服务通道的维修面板后面。",
	"Lord Ashford wired the main research wings to mechanical and electrical verification relays in the Castle Hall. Chemistry verifies Matter / Transformation, Greenhouse verifies Life / Nature, and Circuit verifies Energy / Engineering. The Service Area supplies the physical Access / Route fragment; no magic is involved. Each completed investigation sends a verification signal to its station.":
		"阿什福德勋爵把几个主要研究区，都接到了城堡大厅的机械与电气验证中继上。化学室验证「物质 / 变化」，温室验证「生命 / 自然」，线路房验证「能量 / 工程」，而服务区提供的是「通路 / 路线」。",
	"Dining Hall → service passage → Final Room. The gate will not open without the reassembled key. The fourth fragment is the physical Access / Route seal, completing the Matter, Life, Energy and Access set.":
		"餐厅 → 服务通道 → 终局档案室。钥匙不拼齐，那道门就不会开。第四块碎片是「通路 / 路线」实体封印——补齐之后，物质、生命、能量、通路才算集全。",

	# ---------- 化学室：短句与按钮 ----------
	"Answer the test":
		"回答他的考题",
	"Back to Crafting":
		"返回配药",
	"Examine the stain":
		"检查那摊污渍",
	"Talk to the Butler":
		"找管家谈",
	"The Hidden Compartment":
		"暗格",
	"Chemistry Room Investigation Note":
		"化学室调查笔记",
	"Select a recipe before synthesizing.":
		"先选一张配方，再开始合成。",
	"Not enough %s. Gather more in the greenhouse.":
		"%s不够。回温室再采一些。",
	"Not enough %s. Find the missing material in another room or corridor.":
		"%s不够。去别的房间或走廊里找找缺的那份材料。",
	"You don't have a potion recipe yet. Find a recipe sheet before crafting.":
		"你还没有任何配方。先找到配方纸，再来配药。",
	"You need the matching recipe sheet before you can craft this potion.":
		"配这瓶药之前，得先拿到对应的配方纸。",
	"You filed %d trays before setting the samples down.":
		"你在放下样本之前归档了 %d 盘。",
	"I already examined this stain.\n\nIt is not blood — the colour comes from an indicator reacting with a basic cleaner.":
		"这摊污渍我已经查过了。\n\n那不是血——红色来自指示剂与碱性清洁剂的反应。",
	"I have what I need. The Butler asked me to look at this stain — time to tell him what it really is.":
		"该拿到的我都拿到了。管家让我看这摊污渍——是时候告诉他，它到底是什么。",
	"Lost your nerve? The stain is still there. Observe the powder, the bottle, and the controlled test — then tell me what it truly is.":
		"怂了？污渍还在那儿。去看那些粉末、那只碎瓶，还有那次对照实验——然后回来告诉我它究竟是什么。",
	"Still here? The stain is by the alchemy table. Look at it — smell it, even. Then come back and tell me what it is.":
		"还在这儿？污渍就在炼金台旁边。去看它——闻也行。看完回来告诉我那是什么。",
	"Every sample filed. The red stain belongs with the chemical changes — a new substance formed when the indicator met the cleaning powder. It was never blood.":
		"每一份样本都归好了类。那摊红色污渍属于化学变化——指示剂遇上清洁粉末时生成了新物质。它从来就不是血。",

	# ---------- 化学室：叙事与笔记 ----------
	"A detective? You? I have served this castle for twenty years, and I have never seen you before in my life.\n\nVery well — prove it. There is a red stain by the alchemy table. Go and look at it. Tell me what it really is, and then we can talk.":
		"侦探？你？我在这座城堡当了二十年差，可从没见过你这号人。\n\n行啊——那就证明给我看。炼金台旁边有一摊红渍。去看看它，回来告诉我那到底是什么，我们再谈。",
	"...Hmph. You really are a detective.\n\nThat stain is cleaning powder and indicator mixed to bleed red for show. I have served this castle long enough to know its tricks.\n\nNow listen: the night the lights went out, I heard glass break in this room, and footsteps heading toward the greenhouse wing. I handle cleaning supplies and part of the Dining Hall service; the Service Passage should have been closed after service. That red service cloth is common uniform material, not a personal mark.\n\nReputation +10":
		"……哼。你还真是个侦探。\n\n那摊东西是清洁粉末掺了指示剂，专门调出来做样子的红。这城堡的把戏，我伺候得够久了。\n\n那你听好：灯灭的那一夜，我听见这屋里有玻璃碎的声音，还有往温室那侧去的脚步。清洁用品归我管，餐厅一部分侍应事务也归我；服务通道在收工之后本该是关着的。那块红色的侍应布是通用制服料子，不是谁的私人记号。\n\n声望 +10",
	"You were right. That stain is a mixture of cleaning powder and indicator — it bleeds red for show.\n\nThen I will tell you what I know. That night, the master's study was already dark when the power failed. I heard glass break in this room, and footsteps — quick, heavy ones — heading toward the greenhouse wing.\n\nWhoever staged this knew the castle's cleaning supplies. I handle those supplies and supervise part of the Dining Hall service. The Service Passage should have been closed after service ended. The red cloth you may find there is common service uniform material, not mine alone. That is all I can say.":
		"你说对了。那摊污渍是清洁粉末和指示剂混出来的——红得只是为了做样子。\n\n那我把知道的告诉你。那一夜，电还没断，主人的书房就已经黑着了。我听见这屋里玻璃碎了，还有脚步声——很快，很重——朝温室那侧去了。\n\n布置这一切的人，熟悉城堡的清洁用品。那些东西归我管，餐厅的一部分侍应也归我照看。服务通道在收工之后本该关上。你在那边可能捡到的红布，是通用的侍应制服料子，不是只有我有。我能说的就这些。",
	"I kneel beside the stain and inspect the edge with a clean swab.\n\nThe smell is rusty and metallic, but underneath it there is something sharp and chemical, like the cleaning solution used to scrub this room.\n\nI will compare the powder, broken bottle, and indicator under controlled conditions. Do not taste unknown residue.":
		"我在污渍边蹲下，用干净的棉签蘸了蘸边缘。\n\n气味发锈、带金属感，但底下还压着一股刺鼻的化学味——像是擦洗这间屋子用的清洁液。\n\n我会把粉末、碎瓶和指示剂放在受控条件下比对。不要去尝任何来路不明的残留物。",
	"Beside the stain lie white powder and a broken bottle — the cleaner's residue.\n\nPowder plus an indicator... the red colour is a reaction, not a wound. Someone staged this stain to look like blood.":
		"污渍旁边散着白色粉末和一只碎瓶——清洁剂的残留。\n\n粉末，加上指示剂……这个红是一场反应，不是一道伤口。有人把这摊污渍布置成了血的样子。",
	"The alchemy table is covered in broken glass, crystal residue, and spilled reagents.\n\nThe damage is concentrated around the central vessel. Something happened here before the blood-like spill reached the floor.":
		"炼金台上满是碎玻璃、晶体残渣和泼洒的试剂。\n\n破坏集中在中央那只容器周围。在那摊像血的东西流到地上之前，这里先发生过别的事。",
	"This potion cabinet holds dozens of bottles, vials, and reagent flasks. Most are sealed, but a few have fresh fingerprints on the glass.\n\nThe colourful liquids look like ordinary alchemy supplies. Nothing here matches the red stain by the table — the cabinet was probably not the source of that spill.":
		"这只药柜里放着几十个瓶子、小管和试剂烧瓶。大多数封着口，少数几个玻璃上留有新鲜指纹。\n\n那些彩色液体看着就是寻常的炼金用品。没有一样能对上台边那摊红渍——这泼洒物的来源，多半不是这只柜子。",
	"As you shift the reagent racks, a hidden compartment slides open inside the cabinet.\n\nA green-stained key marked with a leaf-shaped crest rests inside — the Greenhouse Room Key. It has been added to your Key Hub.\n\nSomeone hid the greenhouse key here, far from the greenhouse itself. Whoever did this did not want that room visited.":
		"你挪开试剂架时，柜子内侧滑开了一个暗格。\n\n里面躺着一把染绿的钥匙，压着叶形纹章——温室钥匙。它已被收进你的钥匙栏。\n\n有人把温室的钥匙藏在这里，离温室远得很。做这件事的人，不想让那间屋子被人进去。",
	"One sealed Swiftness Potion rests among the broken glass. It has been placed in your bag.\n\nIt increases movement speed. A second vial beside Mrs. Lin's notes is not stable enough to carry — examine the note to see what happens.":
		"碎玻璃堆里躺着一瓶封好的迅捷药水。它已被放进你的背包。\n\n它能提升移动速度。林女士笔记旁边还有第二只小瓶，稳定性不足以携带——去看那张笔记，就知道会发生什么。",
	"You reach for the small blue vial beside Mrs. Lin's notes.\n\nThe loose stopper slips free. The sample spills across the workbench, and a pale-blue vapor flashes through the room.\n\nFor a few seconds, faint markings that were invisible before appear along the glass and stone. Vision Potion. The unstable sample is completely consumed. A stable Swiftness Potion has been placed in your bag.":
		"你伸手去拿林女士笔记旁边那只蓝色小瓶。\n\n松动的瓶塞滑脱了。样本泼洒在工作台上，一阵淡蓝色的蒸汽掠过整个房间。\n\n有那么几秒钟，玻璃和石面上浮出了原本看不见的淡淡刻痕。洞察药水。这份不稳定的样本被彻底消耗掉了。一瓶稳定的迅捷药水已放进你的背包。",
	"[center][b]Chemistry Room Investigation Note[/b][/center]\n\nMrs. Lin's note, written mid-investigation:\n\nThe [color=#7a2e2e]red stain[/color] by the alchemy table is not blood. The colour matches an indicator reacting with a [color=#4a306d]basic cleaning substance[/color] — a staged stain.\n\nThe shattered glass and scattered reagents suggest someone [color=#7a2e2e]deliberately destroyed the experiment[/color] to make the room look like the scene of a violent crime.\n\nWho would want this room to look like a murder scene?":
		"[center][b]化学室调查笔记[/b][/center]\n\n林女士在调查中途写下的笔记：\n\n炼金台旁那摊[color=#7a2e2e]红色污渍[/color]不是血。这个颜色对得上指示剂与[color=#4a306d]碱性清洁物质[/color]的反应——是被布置出来的。\n\n碎裂的玻璃和散落的试剂说明，有人[color=#7a2e2e]刻意毁掉了这场实验[/color]，好让这间屋子看起来像一桩暴力案件的现场。\n\n谁会希望这间屋子看起来像凶案现场？",
	"[center][b]Mrs. Lin's Lab Notebook[/b][/center]\n\n\"Red liquid test — not blood. Smell: rusty, metallic, with a sharp chemical undertone — cleaning powder. Do not taste unknown residue. Use a controlled indicator comparison: the white powder and cleaning agent produce the same red response under this test.\n\nConclusion: the stain was [color=#7a2e2e]staged[/color] to look like a murder scene.\n\nI almost called it blood when I first saw it. You would have corrected me for jumping to conclusions. Perhaps I taught you something after all.\"":
		"[center][b]林女士的实验笔记[/b][/center]\n\n「红色液体检验——不是血。气味：发锈、带金属感，底下压着一股刺鼻的化学味——清洁粉末。不要去尝来路不明的残留物。做一次受控的指示剂对照：在这个检验下，白色粉末与清洁剂会给出同样的红色反应。\n\n结论：这摊污渍是[color=#7a2e2e]被布置出来的[/color]，为了看起来像凶案现场。\n\n第一眼看见它时，我差点就说那是血。你会纠正我的——纠正我太早下结论。看来我总算还是教会了你一点东西。」",
	"[center][b]The Hidden Compartment[/b][/center]\n\nBehind the reagent racks in the potion cabinet, a hidden compartment slides open.\n\nInside rests a [color=#4a306d]green-stained key[/color] marked with a leaf-shaped crest — the Greenhouse Room Key.\n\nSomeone hid the greenhouse key here, far away from the greenhouse itself. Whoever did this did not want the greenhouse visited.":
		"[center][b]暗格[/b][/center]\n\n药柜里的试剂架后面，滑开了一个暗格。\n\n里面躺着一把[color=#4a306d]染绿的钥匙[/color]，压着叶形纹章——温室钥匙。\n\n有人把温室的钥匙藏在这里，离温室远得很。做这件事的人，不想让温室被人进去。",

	# ---------- 追问、封存档案与最后的字条 ----------
	"[center][b]A Stained Note Page[/b][/center]\n\nA page smudged with oil and ash, tucked inside the workbench journal:\n\n\"...I checked the junction box myself. The burn pattern is [color=#7a2e2e]not accidental[/color].\n\nA deliberate [color=#7a2e2e]short circuit[/color] cut the power exactly when the castle went dark. Someone wanted the blackout...\"":
		"[center][b]沾污的笔记页[/b][/center]\n\n一页沾着油污和灰烬的纸，夹在工作台的日志里：\n\n「……接线盒是我亲自查的。那个灼烧形态[color=#7a2e2e]不是意外[/color]。\n\n一次蓄意的[color=#7a2e2e]短路[/color]，在城堡陷入黑暗的那一刻切断了电源。有人是要这场停电……」",
	"[center][b]SEALED ARCHIVE II — EMERGENCY ISOLATION ORDER[/b][/center]\n\nThe cabinet's false bottom holds a carbon-copy instruction: “Move Dr. Lin to the analysis table. Engage the isolation field. Do not interrupt the calibration.”\n\nIts safety code belongs to the Mechanical Office, but the handwritten routing mark was added after the document was filed. The pressure seal has been scraped away; beneath it, a violet graphite trace matches the Mechanic's workshop pencil.\n\nThe Butler received an order that looked official. Someone with maintenance authority forged the command chain.":
		"[center][b]密封档案 II —— 紧急隔离令[/b][/center]\n\n柜子的假底里压着一份复写指令：「将林博士移至分析台。启动隔离力场。不得中断校准。」\n\n它的安全编码属于机械办公室，但那个手写的转递标记，是文件归档之后才补上去的。压印封条被刮掉了；底下留着一道紫色石墨痕，与机械师工坊里的铅笔吻合。\n\n管家收到的是一份看起来完全正规的命令。有维修权限的人，伪造了整条指挥链。",
	"The dining hall evidence reconstructs the missing interval: the meal ended, the clock was stopped by hand, the fire was disturbed, and someone used the service route after the blackout. Mrs. Lin's final note warns that the event was not an accident.":
		"餐厅的证据把那段消失的时间重建了出来：晚餐结束、钟被人用手按停、火被翻动过，而且停电之后有人走了服务通道。林女士最后那条笔记警告说——这不是一场意外。",
	"[center][b]SEALED ARCHIVE I — PRIVATE SERVICE ADDENDUM[/b][/center]\n\nA letter hidden beneath the service ledger records the Butler's demotion after a safety incident years ago. The Mechanical Office offered a way to restore his standing: carry out one emergency isolation order exactly, without asking questions.\n\nThe order promised that Dr. Lin would be kept safe behind the Ashford table's field. The Butler's later note ends with a trembling line: [color=#4a306d]“I operated the apparatus. I believed I was protecting her.”[/color]\n\nThis explains his pressure and his action. It does not identify the author of the order.":
		"[center][b]密封档案 I —— 私人侍应附录[/b][/center]\n\n服务台账下面藏着一封信，记录了管家多年前因一起安全事故被降职的事。机械办公室给了他一条恢复身份的路：一字不差地执行一次紧急隔离令，不许多问。\n\n那道命令承诺，林博士会被安全地护在阿什福德分析台的力场之后。管家后来写下的字条，末尾是颤抖的一行：[color=#4a306d]「装置是我操作的。我以为我在保护她。」[/color]\n\n这解释了他承受的压力和他做过的事。但它没有指出——命令是谁写的。",
	"\"The clock is a distraction. Follow the heat, the ash, and the service route. If the lights fail, do not trust the first person who claims to have been trapped. Someone knows I am following the route now. I can hear movement behind the wall. If you find this note, do not follow just because I did. Of course, you probably will.\"":
		"「钟是用来分散注意力的。跟着热度、跟着灰烬、跟着服务通道走。如果灯灭了，别去相信第一个声称自己被困住的人。有人已经察觉我在走这条路了，我能听见墙后有动静。如果你找到这张纸条，别只因为我走过就跟着走。——当然，你多半还是会走的。」",
	"\"The circuit lock overheats when current becomes too high. Increase resistance to reduce current flow. Never bypass the resistor.\"\n\nMrs. Lin:\nThis note gives us the rule we need. If current is too high, increasing resistance can reduce it.\n\nConcept learned: Current decreases when resistance increases.":
		"「电流一大，这道电路锁就会过热。提高电阻可以把电流降下来。绝对不要跳过电阻器。」\n\n林女士：\n这张纸条给了我们要的规则。电流太大时，加大电阻就能把它压下来。\n\n已掌握概念：电阻增大，电流减小。",
	"A short circuit? I maintain the castle wiring, but anyone could have damaged that panel.\n\nMrs. Lin:\nMaybe. But the burn pattern suggests the blackout was triggered intentionally. Someone who understands circuits would know exactly where to interfere.":
		"短路？城堡的线路是我在维护，可那块板子谁都可能弄坏。\n\n林女士：\n也许吧。但那个灼烧形态说明停电是被人触发的。懂电路的人，才知道该往哪儿下手。",
	"I already told you, I only cleaned the hallway. That red stain has nothing to do with me.\n\nMrs. Lin:\nInteresting. The stain may involve a basic cleaning substance. Someone with access to cleaning supplies could explain part of this clue.":
		"我说过了，我只擦了走廊。那摊红渍跟我没关系。\n\n林女士：\n有意思。那摊污渍可能牵涉到碱性清洁物质。能拿到清洁用品的人，正好能解释这条线索的一部分。",
	"I was only cleaning the hallway. This castle has always been strange. Lord Ashford built those knowledge locks everywhere. Doors, cabinets, even old storage rooms.\n\nMrs. Lin:\nThat explains why many paths require scientific reasoning. We should collect physical evidence before making any accusation.":
		"我只是在擦走廊。这座城堡一向古怪。阿什福德勋爵到处都装了那种知识锁——门上、柜子上，连旧储藏间都有。\n\n林女士：\n这就解释了为什么很多路都要靠科学推理才走得通。在指认任何人之前，我们得先拿到实物证据。",
	"I was working near the greenhouse earlier. I did not enter the locked rooms.\n\nWe should look for biological trace evidence before deciding whether that is true.":
		"我先前在温室附近干活。上锁的房间我没进过。\n\n在断定这话真假之前，我们该先去找生物微量物证。",
	"Pollen? Of course there is pollen in a castle with a greenhouse. That does not prove I did anything.\n\nMrs. Lin:\nHe is right that pollen alone is not proof. But if it appears on a locked door handle, it may show that someone from the greenhouse touched it recently.":
		"花粉？一座带温室的城堡里当然有花粉。这证明不了我做过什么。\n\n林女士：\n单靠花粉不足以定案，这一点他说得没错。但如果花粉出现在一扇上锁的门把手上，那就可能说明：不久前有从温室来的人碰过它。",
	"The lights in this castle fail all the time. Old wiring, old walls, old problems.\n\nMrs. Lin:\nMaybe, but we should inspect the circuit panel before accepting that explanation.":
		"这城堡的灯三天两头就灭。旧线路、旧墙、旧毛病。\n\n林女士：\n也许吧。但在接受这个说法之前，我们该先去看看那块电路板。",

	# ---------- 终局档案室 ----------
	"Final Archive Document — Lord Ashford Record":
		"终局档案文件 —— 阿什福德勋爵记录",
	"Final Deduction":
		"最终推演",
	"Final Deduction Connection":
		"最终推演：证据串联",
	"Knowledge Engine Route":
		"知识引擎路线",
	"Mrs. Lin Found in the Final Room":
		"在终局档案室发现林女士",
	"Mrs. Lin's Final Notebook":
		"林女士最后的笔记本",
	"Ordinary Case Closure — The Butler":
		"普通结案 —— 管家",
	"True Case Closure — The Mechanic":
		"真相结案 —— 机械师",
	"Mrs. Lin lies beside the analysis table. She is already dead. Her notebook is still held against her coat. A torn violet cuff fragment with a copper-thread cross-stitch remains in her hand.":
		"林女士倒在分析台旁边，已经没有气息。笔记本仍被她按在外套上。她手里还攥着一块撕下的紫色袖口残片，上面有铜线十字缝补的痕迹。",
	"Mrs. Lin is dead beside the Ashford analysis table. There is no sign that she reached the final archive. Her notebook is still closed against her coat. A torn violet insulating fiber and a fragment of glove cuff are caught in her hand; the cuff carries a distinctive copper-thread cross-stitch that matches the repair described in the Circuit Room maintenance record.":
		"林女士死在阿什福德分析台旁。没有任何迹象表明她拿到了终局档案。笔记本仍旧合着，压在她的外套上。她手里攥着一段撕断的紫色绝缘纤维和一块手套袖口残片；那块袖口带着很好认的铜线十字缝补，与线路房维修记录里描述的那次修补完全吻合。",
	"The circular Ashford analysis table has five radial evidence links: staged scene, maintenance route, deliberate blackout, Dining opportunity, and the personalized glove match. It is waiting for the final deduction.":
		"阿什福德的圆形分析台有五条放射状的证据链：布置过的现场、维修路线、蓄意停电、餐厅时机，以及那处独一无二的手套匹配。它在等一次最终推演。",
	"The final pages do not name a culprit. They ask you to connect the staged Chemistry scene, the Greenhouse maintenance route, the deliberate blackout, the Dining timeline, and the personalized glove match before choosing a suspect.":
		"最后几页没有点出凶手的名字。它们要求你把这些串起来：被布置的化学室现场、温室通往服务通道的路线、蓄意的停电、餐厅的时间线，以及那处独一无二的手套匹配——串完之后，再去选人。",
	"The final pages do not name a culprit. They organize five questions: was the Chemistry scene staged, what links the Greenhouse to the service route, what caused the blackout, what does the Dining timeline prove, and who had the knowledge, tools, access, and route to connect them? The violet fiber and torn cuff in Mrs. Lin's hand are the final bridge to her last struggle.\n\nIf you are reading this, then I did not make it back. Do not finish this investigation for me. Finish it properly. Check every assumption. Connect the evidence. And do not guess.":
		"最后几页没有点出凶手的名字。它们把问题理成了五条：化学室的现场是不是被布置过；温室与服务通道之间是什么关系；停电由什么造成；餐厅的时间线证明了什么；以及——谁同时具备把这一切串起来所需的知识、工具、权限和路线？林女士手中的紫色纤维和撕下的袖口，是通向她最后那场挣扎的最后一座桥。\n\n如果你正在读这段话，那我就是没能回来。别为了我把这桩调查结掉——要把它做对。逐条检验你的每一个假设。把证据串起来。还有，不要猜。",
	"The final table connects Evidence to Person, Person to Location, and Location to Timeline. The chain identifies the Mechanic's access, route and opportunity before the suspect comparison.":
		"这张终局台把证据连到人、人连到地点、地点连到时间线。这条链会在比对嫌疑人之前，先确定机械师的权限、路线与时机。",
	"The final deduction identifies the Mechanic through knowledge, tools, access, opportunity and route. The staged red stain, maintenance pollen, deliberate short circuit, missing right glove, copper repair thread and torn cuff fragment form one connected case.":
		"最终推演从知识、工具、权限、时机和路线五个方面指向机械师。被布置的红色污渍、维修带来的花粉、蓄意的短路、失踪的右手手套、铜线修补痕和撕下的袖口残片，构成了同一桩案子。",
	"The five conclusions identify the Butler as the executor: he had the service access, reached the analysis table, and operated the prepared apparatus. Yet the glove evidence only proves contact with the maintenance chain. The original instruction remains unaccounted for.":
		"五条结论指认管家是执行者：他有服务通道的权限，他到过分析台，并且操作了那台已经准备好的装置。可是手套那条证据只能证明他接触过维修链条——那道最初的命令，仍旧没有着落。",
	"The Butler operated the apparatus under a forged emergency order. The three sealed archives reveal the author: the Mechanic exploited the Butler's pressure, forged the Mechanical Office instruction, and silenced Dr. Lin after she refused him funding and access to the Knowledge Engine plans.":
		"管家是在一道被伪造的紧急命令下操作装置的。三份密封档案揭出了写命令的人：机械师利用了管家的处境，伪造了机械办公室的指令，并在林博士拒绝给他经费与知识引擎图纸权限之后，让她永远沉默。",
	"The sealed record describes Ashford's research wings as a verification network: Matter, Life, Energy and Access. It names the Knowledge Engine as the castle's central research system and records unauthorized copies of its engineering diagrams and irregular maintenance-level archive requests. The document identifies the target and the route, but it does not name the person responsible.":
		"这份封存记录把阿什福德的几个研究区描述成一张验证网络：物质、生命、能量与通路。它指明知识引擎是城堡的中枢研究系统，并记录了其工程图纸的未授权复制件，以及若干不合规的维修级档案调阅申请。这份文件点明了目标和路线，却没有点明责任人。",
	"The Knowledge Engine's brass orrery links the violet circuit to the Master Archive. Its central sphere remains sealed until the Vault symbols confirm the route.":
		"知识引擎的黄铜星象仪，把那条紫色电路连向主档案库。在金库符号确认路线之前，它中央的球体一直是封着的。",
	"The Vault Door's central violet core is connected to the Master Archive route. Under Vision, its frozen symbols record the maintenance circuit used to reach Mrs. Lin's final room.":
		"金库门中央那枚紫色核心，接的正是通往主档案库的路线。在洞察之下，它凝固的符号记录着——那条通往林女士最后一间房的维修电路。",
	"The violet symbol in the vault matches the Knowledge Engine's maintenance circuit. The archive was the target, and the service route was the method.":
		"金库里那个紫色符号，与知识引擎的维修电路吻合。档案库才是目标，而服务通道是手段。",

	# ---------- 图书馆 ----------
	"Ashford Archive Record":
		"阿什福德档案记录",
	"RGB Archive Filter":
		"RGB 档案滤镜",
	"SEALED ARCHIVE III — Dr. Lin's Decision":
		"密封档案 III —— 林博士的决定",
	"Recipe learned: %s":
		"已学会配方：%s",
	"%s light is active. Activate the other two filters in any order; the archive will appear when all three colors overlap.":
		"%s光已亮。另外两片滤镜的顺序随意；三色叠在一起时，档案就会显形。",
	"Red, green and blue light are all active in the optical stand. Their additive combination becomes a pale neutral light, revealing the layered diagram and the route to the Ashford Archive Record.":
		"红、绿、蓝三色光都亮着了。它们叠加成近乎中性的淡白光，把分层的图解和通往阿什福德档案记录的路线一并显了出来。",
	"The archive text is split into three color layers. Use the red, green and blue filters before copying the record.":
		"档案上的字被拆成了三层颜色。先把红、绿、蓝三片滤镜都用上，再来誊抄这份记录。",
	"Archive record copied. It links the Knowledge Engine to the maintenance circuit and the hidden service route.":
		"档案记录已誊抄。它把知识引擎、维修电路和那条隐蔽的服务通道连了起来。",
	"You already copied the Ashford archive record into your notes.":
		"阿什福德的这份档案记录，你已经抄进笔记了。",
	"You already copied this recipe into your notes.":
		"这张配方你已经抄进笔记了。",
	"The violet archive drawer is bare. Dr. Lin's private decision has already been copied.":
		"那只紫色档案抽屉空了。林博士的私人决定已经被誊抄走了。",
	"A rolled scroll tucked between alchemical volumes. It holds the recipe for the Swiftness Potion.":
		"夹在几本炼金典籍之间的一卷卷轴。上面写着迅捷药水的配方。",
	"A scroll hidden inside an old atlas. It holds the recipe for the Vision Potion.":
		"藏在一本旧地图册里的卷轴。上面写着洞察药水的配方。",
	"A detective's work table covered in papers, candles and a magnifying glass. The notes point toward the lower hall.":
		"一张侦探的工作台，铺满纸张、蜡烛和一只放大镜。那些笔记指向下层厅堂。",
	"A broad chest-cabinet packed with books and bundled scrolls. The bindings are worn with age.":
		"一只宽大的箱柜，塞满书籍和成捆的卷轴。装帧都已年久磨损。",
	"A divided storage chest filled with banded books, scrolls and small sealed bundles.":
		"一只带隔层的储物箱，装着扎带的书册、卷轴和小捆封好的东西。",
	"A chained chest-cabinet. The lock is intact, but the books inside have been disturbed recently.":
		"一只上了链的箱柜。锁没被动过，可里面的书最近被人翻过。",
	"A heavy cabinet bound by a chain and a gold padlock. Whatever it guards, it was meant to stay sealed.":
		"一只用铁链和金色挂锁封住的重柜。不管它守着什么，那东西本就不打算见人。",
	"A dark cabinet bearing a circular crossed emblem. The lower handle is polished from frequent use.":
		"一只深色柜子，上面是圆形交叉纹章。下方把手被摩得发亮，显然常被人开合。",
	"A narrow cabinet with two ring handles and a heavy lower clasp. The lock has been opened and closed many times.":
		"一只窄柜，两只环形把手，下方是沉重的搭扣。这把锁被开过又合上过很多次。",
	"A narrow cabinet. A circular lock with an hourglass mark guards whatever lies within.":
		"一只窄柜。一把带沙漏标记的圆形锁，守着里面的东西。",
	"A tall cabinet of dark wood, marked with a compass-like emblem. Its door will not budge.":
		"一只深色木质高柜，标着类似罗盘的纹章。柜门纹丝不动。",
	"A tall ring-marked cabinet. Its lower emblem is scratched with a symbol that matches no library catalogue.":
		"一只带环形标记的高柜。下方纹章上被刻了一个符号——图书馆的任何目录里都查不到它。",
	"A tall bank of drawers with brass handles. One drawer is slightly open, papers peeking out.":
		"一排高身抽屉，配黄铜把手。有一格微微开着，纸角探了出来。",
	"A tall wooden panel with a wheel-like mechanism. Its symbols look designed to be turned in a precise order.":
		"一面高大的木板，嵌着轮盘状的机构。上面的符号，看样子要按某个精确的顺序转动。",
	"A reinforced archive cabinet with deep shelves and brass fasteners. Its contents are carefully sorted.":
		"一只加固的档案柜，隔板很深，配黄铜扣件。里面的东西分类得很仔细。",
	"A cabinet of bottles, powders and sealed jars. The dust around one vial has been recently disturbed.":
		"一只放着瓶子、粉末和封口罐的柜子。其中一支小瓶周围的灰尘，最近被人碰过。",
	"Rows of archive drawers filled with brittle notes, labels and fragments of old casework.":
		"一排排档案抽屉，装满脆化的笔记、标签，和旧案卷的残页。",
	"A restricted archive card describes the Knowledge Engine and the castle's security network. Lord Ashford restricted the complete Knowledge Engine plans to the Master Archive. Several maintenance copies of Ashford engineering diagrams were produced without authorization, and the archive access records contain irregular maintenance-level requests. The archive route is hidden behind the final vault, and the security system can be redirected through the maintenance circuit. Whoever made those requests needed technical access, a route through the service systems, and a reason to create a blackout.":
		"一张受限档案卡描述了知识引擎与城堡的安保网络。阿什福德勋爵把知识引擎的完整图纸限制在主档案库内。有若干份阿什福德工程图解的维修副本在未获授权的情况下被制作出来，而档案调阅记录里，还留着一些不合规的维修级申请。",
	"[center][b]SEALED ARCHIVE III — DR. LIN'S PRIVATE DECISION[/b][/center]\n\nDr. Lin's unsigned memorandum confirms that she rejected the Mechanic's request for independent funding and access to the complete Knowledge Engine plans. She had discovered unauthorized maintenance copies, so she prepared a controlled verification at the analysis table to trace the person directing them.\n\nHer final margin note reads: [color=#4a306d]“The Butler is frightened, not secretive. If an emergency order reaches him, verify its routing mark before he acts.”[/color]\n\nDr. Lin expected a forged instruction; she did not expect its isolation field to become lethal. The person who needed her silent also needed her research recognized as his own.":
		"[center][b]密封档案 III —— 林博士的私人决定[/b][/center]\n\n林博士一份未署名的备忘录确认：她驳回了机械师索取独立经费、以及查阅知识引擎完整图纸的请求。她发现了那些未经授权的维修副本，于是在分析台上准备了一次受控验证，想追出到底是谁在背后调度它们。\n\n她在页边的最后一句写着：[color=#4a306d]「管家是害怕，不是有意隐瞒。如果有紧急命令递到他手上，务必在他动手之前核实转递标记。」[/color]\n\n林博士预料到会有一份伪造的指令；她没有预料到，那道隔离力场会致命。那个需要她沉默的人，同时也需要她的研究成果被认成自己的。",
	# ---------- 图书馆 · 光学阵列（反射矩阵 / 光谱定序器 / 加色中继） ----------
	"Reflection Matrix":
		"反射矩阵",
	"Spectrum Sequencer":
		"光谱定序器",
	"Additive Relay":
		"加色中继",
	"Reflection, Absorption & Color":
		"反射、吸收与颜色",
	"Visible Spectrum & Wavelength":
		"可见光谱与波长",
	"Additive Color Mixing":
		"加色法混色",
	"A brass reflection matrix overlays the east writing desk.":
		"东侧那张书桌上，覆着一具黄铜反射矩阵。",
	"A wavelength sequencer is embedded in the illuminated research desk.":
		"一台波长定序器，嵌在那张亮着灯的研究桌里。",
	"Three emitter controls have been fitted around the west globe desk.":
		"西侧那张地球仪桌的四周，装上了三组发射器控制。",
	"An empty verdant lens slot waits for a filter recovered from the Reflection Matrix.":
		"一个空着的翠绿镜位，等着从反射矩阵取回的那片滤光片。",
	"An empty crimson lens slot waits for a filter recovered from the Spectrum Sequencer.":
		"一个空着的绯红镜位，等着从光谱定序器取回的那片滤光片。",
	"An empty cobalt lens slot waits for a filter recovered from the Additive Relay.":
		"一个空着的钴蓝镜位，等着从加色中继取回的那片滤光片。",
	"This slot is empty. Complete the %s to recover its %s filter.":
		"这个镜位是空的。先通过%s，取回它的 %s 滤光片。",
	"The %s filter is already seated and active.":
		"%s 滤光片已经装好并生效了。",
	"%s complete. Take the recovered %s filter to the central optical array.":
		"%s 已完成。把取回的 %s 滤光片装到中央光学阵列上。",
	"This challenge is complete. Carry the recovered %s filter to the central optical array.":
		"这道关卡完成了。把取回的 %s 滤光片带到中央光学阵列去。",
	"All three recovered filters remain seated. Their combined pale light keeps the hidden archive text visible.":
		"三片取回的滤光片都还嵌在位上。它们叠合出的淡光，让隐藏的档案文字持续显形。",
	"A three-tier bookcase. The top surface still holds an open book.":
		"一座三层书架。最上层还摊着一本翻开的书。",
	"An open shelf of dusty volumes and sealed containers.":
		"一排敞开的架子，堆着积灰的书册和封死的容器。",
	"A narrow two-part case, almost emptied. One volume remains on its shelf: a field study of visible wavelengths.":
		"一只狭长的两截式书柜，几乎被搬空了。架上只剩一册：一份关于可见光波长的实地研究。",
	"A violet archive cabinet with one empty compartment. A single field guide on reflection and absorption is still filed here.":
		"一只紫色档案柜，有一格是空的。这里还归档着一本讲反射与吸收的实地指南。",
	"An empty reinforced shelf holds a single filed volume on additive light.":
		"一层加固的空架子上，只归档着一册讲加色光的书。",
	"Seen color is reflected light. A green leaf reflects green wavelengths and absorbs much of the red and blue light.":
		"你看见的颜色，是被反射回来的光。绿叶反射绿色波长，同时吸收掉大部分红光和蓝光。",
	"A green leaf appears green because green wavelengths are reflected toward the eye while much of the red and blue light is absorbed.":
		"绿叶看上去是绿的，是因为绿色波长被反射进了眼睛，而红光和蓝光大部分都被吸收掉了。",
	"Visible-light wavelength decreases from red through green toward blue. Longest to shortest: red, green, blue.":
		"可见光的波长从红经绿向蓝递减。由长到短依次是：红、绿、蓝。",
	"Visible-light wavelength decreases from red through green toward blue. The recovered crimson filter was sealed behind a longest-to-shortest spectrum lock.":
		"可见光的波长从红经绿向蓝递减。取回的那片绯红滤光片，正是封在一道「由长到短」的光谱锁后面。",
	"Light adds: green plus blue makes cyan, red plus blue makes magenta, and red plus green plus blue makes white.":
		"光是相加的：绿加蓝得到青，红加蓝得到品红，红、绿、蓝三者相加得到白。",
	"Colored light adds: green plus blue makes cyan, red plus blue makes magenta, and red plus green plus blue makes white light.":
		"彩色光是相加的：绿加蓝得到青，红加蓝得到品红，红、绿、蓝三者相加得到白光。",

	# ---------- 线路房 · 联锁闸板与供电恢复 ----------
	"Three Flush Junction Plates":
		"三块齐平联锁闸板",
	"FOLLOW THE PULSE":
		"跟住脉冲",
	"The blueprint locates three flush junction plates. Their positions are now on record.":
		"图纸标出了三块与外壳齐平的联锁闸板。它们的位置已经记录在案。",
	"The bench is cleared. The plate will now throw in numbered order.":
		"台面已经清空。闸板现在会按编号顺序合闸。",
	"[center][b]Three Flush Junction Plates[/b][/center]\n\nThe workshop's junction plates are set level with their housings, so nothing protrudes for a hand to find. The repair blueprint numbers them [color=#4a306d]1 auxiliary[/color], [color=#4a306d]2 regulator[/color], [color=#4a306d]3 master[/color].\n\nThey must be thrown in that order; any other order trips the interlock and resets the run.":
		"[center][b]三块齐平联锁闸板[/b][/center]\n\n工坊里的联锁闸板与外壳装得齐平，没有任何凸起可供手摸到。维修图纸把它们编号为 [color=#4a306d]1 辅路[/color]、[color=#4a306d]2 调压[/color]、[color=#4a306d]3 主闸[/color]。\n\n必须按这个顺序合闸；换成任何别的顺序，都会触发联锁并把整轮重置。",
	"POWER RESTORED · The generator is online. Return to the Hall and open Map to recover your route memory.":
		"供电已恢复 · 发电机上线。回到大厅打开地图，取回你的路径记忆。",
	"ROUTE MEMORY ONLINE":
		"路径记忆已上线",
	"Dr. Lin's Partial Hall Map":
		"林博士的大厅残图",

	# ---------- 知识锁与合成锁的通用提示 ----------
	"Correct.\n\nThe knowledge lock accepts your answer.\n\nDoor opened.":
		"答对了。\n\n知识锁接受了你的答案。\n\n门开了。",
	"Not quite.\n\nThe lock remains sealed. Think about the science behind the question and try again.":
		"还差一点。\n\n锁没有开。想一想这道题背后的科学原理，再试一次。",
	"That answer does not fit the evidence you have learned.\n\nReview the corresponding room Knowledge note and try again.":
		"这个答案跟你掌握的证据对不上。\n\n回去复习对应房间的知识笔记，再试一次。",
	"Final Synthesis Lock — Question %d/%d:\n\n%s":
		"最终合成锁 —— 第 %d/%d 题：\n\n%s",
	"Question terminal locked. Study and file '%s' at the marked knowledge shelf first.":
		"问答终端已锁定。先到标记的知识书架研读并归档「%s」。",
	"The key fits, but the knowledge lock is still sealed.\n\nStudy the ":
		"钥匙对得上，但知识锁仍然封着。\n\n先去城堡大厅研究",
	" Knowledge exhibit in Castle Hall and save it to NoteHub before answering this question.":
		" 知识展品，存进 NoteHub，再来回答这个问题。",
	"the missing knowledge record":
		"那份缺失的知识记录",
	"\n\nThis knowledge has been added to NoteHub.":
		"\n\n这条知识已存入 NoteHub。",

	# ---------- 苏醒室与餐厅补遗 ----------
	"To whoever finds this —\n\nAshford sealed every room twice. First find the physical key belonging to that room. Then the knowledge lock will reveal its question.\n\nThe answer is always hidden nearby. Do not guess — read, observe, understand.\n\nFor this chamber, begin with the bed, then consult the bookshelf before facing the door.\n\n— Dr. Lin":
		"致找到这张字条的人 ——\n\n阿什福德把每个房间都封了两道。先找到属于那个房间的实体钥匙，知识锁才会显出它的问题。\n\n答案永远就藏在近旁。不要猜 —— 去读，去看，去想明白。\n\n这间屋子，从床开始，再去查书架，然后再面对那扇门。\n\n—— 林博士",
	"Mrs. Lin's Counter-Formulas":
		"林老师的反制配方",
	"Pressed inside the carving-board ledger are three formulas in Mrs. Lin's hand. \"They put the marker in the wine, not the food. It is why the thing in the corridor never has to search. Wash it out with moonleaf and blue blossom in twice-distilled water and it will lose you the moment you leave its sight. Two more, for when sight is not enough: iron salt and prism dust to blind it, prism dust alone to bend the light around you.\"":
		"砧板账簿里压着三道配方，是林老师的字迹。「标记物下在酒里，不在食物里。走廊里那东西之所以从来不必去找，就是这个缘故。用月叶和蓝花在二次蒸馏水里把它洗掉，你一离开它的视线，它就会跟丢你。另外两道，留给光靠躲还不够的时候：铁盐加棱镜粉可以让它失明，单用棱镜粉能把光在你周身折开。」",
	"A chemical change creates a new substance. Burning paper is chemical; melting ice, breaking glass, and dissolving sugar are physical changes.":
		"化学变化会生成新的物质。纸张燃烧是化学变化；冰融化、玻璃破碎、砂糖溶解，则都是物理变化。",

	# ---------- 温室：花坛全清的知识笔记 ----------
	"Blue Blossom and the Limiting Factor":
		"蓝花与限制因子",
	"Growth is capped by whichever of light, water and carbon dioxide is scarcest; pouring more of the others in changes nothing. That is why this bed keeps all three in step.\n\nBlue Blossom is one of the two herbs Mrs. Lin's formula names for washing the marker out of a person.":
		"生长的上限，由光照、水分、二氧化碳里最缺的那一项定死；把其余两项加得再多也没有用。这条花坛之所以要三项齐头并进，就是这个道理。\n\n蓝花正是林老师配方里点名的两味药之一——用来把标记物从人身上洗掉。",
	"Moonleaf and Light It Can Use":
		"月叶与它用得上的光",
	"Moonleaf opens only under the cold end of the spectrum, so the light it is given matters as much as how much.\n\nIt is the second herb in Mrs. Lin's formula — moonleaf and blue blossom in twice-distilled water.":
		"月叶只在光谱偏冷的那一端才张开，所以给它什么光，和给它多少光一样要紧。\n\n它是林老师配方里的第二味药——月叶配蓝花，在二次蒸馏水里。",
	"Every trial on this bed answered. The gardener's reserve yields %d more %s.":
		"这条花坛的每一道题都答上来了。园丁的存货又给了 %d 份%s。",

	# ---------- 获得物品提示（钥匙 / 证据 / 图纸） ----------
	"A brass key bearing a red Ashford seal. It belongs to the Wake Room exit.":
		"一把黄铜钥匙，压着阿什福德家的红色火漆。它开的是卧房的那道门。",
	"A ceremonial key shaped for the castle's oldest lock.":
		"一把礼仪用的钥匙，是照着城堡里最老的那把锁打的。",
	"A cold key recovered from the route toward the Final Room.":
		"一把冰凉的钥匙，是在通往终末之室的路上捡到的。",
	"A dark metal key threaded with a violet current.":
		"一把暗色金属钥匙，里面有一缕紫色的电流在走。",
	"A green-stained key marked with a leaf-shaped crest.":
		"一把染着绿渍的钥匙，上面刻着叶形的纹章。",
	"A hand-drawn hall fragment from Dr. Lin's desk. Its missing sections will reveal themselves only as you explore.":
		"林博士桌上一角手绘的大厅残图。缺掉的部分，只会随着你一步步走过去才浮现出来。",
	"A hand-drawn repair map marking the three switches and the correct activation order.":
		"一张手绘的检修图，标出了三个开关，以及正确的合闸顺序。",
	"A heavy laboratory key. Its worn teeth carry a faint chemical-blue shine.":
		"一把沉手的实验室钥匙。磨秃的齿上泛着一点药水般的幽蓝。",
	"A maintenance record assigns one pair of gloves to the Mechanic. The right glove had a distinctive copper-thread cross-stitch repair and went missing after the blackout.":
		"一份检修记录写明，有一副手套是发给机修工的。右手那只补过一道很好认的铜线十字缝，停电之后就不见了。",
	"A silver-marked key recovered from the Circuit Room equipment cabinet.":
		"一把带银色标记的钥匙，是从电路室的器材柜里取出来的。",
	"A slim brass key stamped with the library's spiral archive seal.":
		"一把细长的黄铜钥匙，打着图书馆那枚螺旋书库印。",
	"A strange key with a glowing central core. Its purpose is unknown.":
		"一把古怪的钥匙，芯子里亮着光。它是用来开什么的，还不知道。",
	"A torn cuff fragment in Mrs. Lin's hand carries the same distinctive copper-thread cross-stitch described in the Mechanic's missing glove record.":
		"林太太手里攥着一角撕下的袖口，上面那道铜线十字缝，和机修工那只失踪手套记录里写的一模一样。",
	"A torn piece of the Final Room Key. It seems incomplete — three fragments must be found.":
		"终末之室钥匙的一块残片。它显然还不完整——一共要找齐三块。",
	"A torn piece of the distinctive maintenance insulating weave was caught in Mrs. Lin's hand. It links her final struggle to the Circuit and Service Area evidence without identifying a worker by itself.":
		"林太太手里勾着一小块检修用的绝缘织物，纹路很好认。它把她最后的挣扎与电路室、勤务区的物证连了起来，但单凭它还指不到具体某个人。",
	"A violet thread caught on the pipe matches the insulating weave documented in the Circuit Room maintenance equipment.":
		"管道上挂着的一缕紫色丝线，和电路室检修器材记录里的绝缘织物对得上。",
	"Added to Satchel":
		"已收进行囊",
	"Added to Satchel Maps":
		"已收进行囊的地图册",
	"An ornate key assembled from three torn fragments.":
		"一把由三块残片拼合而成的华丽钥匙。",
	"Archive Key":
		"书库钥匙",
	"Deep-room pollen on the tools — someone entered the greenhouse from outside.":
		"工具上沾着温室深处的花粉——有人是从外面进的温室。",
	"Lord Ashford's sealed record connects the castle's research wings, the Knowledge Engine, and the hidden archive route.":
		"阿什福德勋爵那份封存的记录，把城堡的几处研究侧翼、知识引擎，还有那条隐蔽的书库通路串到了一起。",
	"Map and Satchel unlocked":
		"地图与行囊已解锁",
	"Master Key":
		"总钥匙",
	"The burn pattern is not accidental — someone cut the power on purpose.":
		"这道烧灼的痕迹不是意外——有人是存心把电切断的。",
	"The dark trail contains violet grit and a chemical smell. Something heavy was dragged from the workshop.":
		"那道暗色拖痕里有紫色的碎屑和一股药味。有很重的东西被从工坊拖了出去。",
	"The meal ended at 11:40; fresh ash and a stopped clock mark the missing twenty minutes.":
		"那顿饭在 11:40 结束；新落的灰和一台停摆的钟，标出了消失的那二十分钟。",
	"The pendulum was stopped deliberately to create a false midnight timestamp.":
		"钟摆是被人特意按停的，为的是造出一个假的午夜时刻。",
	"The red liquid reacts with a basic cleaner — the stain was staged.":
		"那摊红色液体遇上碱性清洁剂会起反应——这处污渍是做出来的。",
	"The red thread matches a service uniform, not the dining decorations.":
		"那根红线对得上的是勤务制服，而不是宴会厅的装饰。",
	"Under the Vision Potion, the vault dial reveals a violet circuit mark — the culprit's route recorder.":
		"在洞察药水下，金库的转盘上浮出一道紫色的电路印记——那是凶手留下的路线记录。",

	# ---------- 行囊 / 钥匙栏界面 ----------
	"SATCHEL":
		"行囊",
	"BAG":
		"行囊",
	"CASE SATCHEL":
		"办案行囊",
	"FIELD ARCHIVE  ·  RECOVERED MATERIALS":
		"现场档案  ·  已回收的材料",
	"CASE FILES":
		"案件卷宗",
	"ITEM INSPECTION":
		"物品查验",
	"USE":
		"使用",
	"Select an item":
		"选择一件物品",
	"EMPTY SATCHEL SLOT":
		"空的行囊格",
	"Choose a potion, material, or paper to inspect its details.":
		"选一瓶药水、一份材料或一张纸页，查看它的详情。",
	"OPEN MAP":
		"打开地图",
	"KEYS":
		"钥匙",
	"KEY REGISTER":
		"钥匙名录",
	"TEETH · CRESTS · ACCESS":
		"齿纹 · 纹章 · 通行",
	"KEY HUB AWAKENED":
		"钥匙栏已启用",
	"Your first key has been recorded. Press I or click the key.":
		"你的第一把钥匙已登记在案。按 I 键，或点击那把钥匙。",
	"RECOVERED":
		"已寻回",
	"Quantity: ":
		"数量：",
	"FILED: %d  •  SELECT AN ITEM TO INSPECT  •  TAB / ESC: CLOSE":
		"已归档 %d 件  •  选中一件查看详情  •  TAB / ESC 关闭",
	"FIELD KIT · FOUR FILES":
		"现场工具 · 四类卷宗",
	"1 · CHOOSE FILE    2 · INSPECT ITEM    3 · USE / OPEN":
		"1 · 选择卷宗    2 · 查看物品    3 · 使用 / 打开",
	"ALL":
		"全部",
	"POTIONS":
		"药水",
	"MATERIALS":
		"材料",
	"PAPERS":
		"纸页",
	"Knowledge Lock:":
		"知识锁：",
	"Which of these is a chemical change?":
		"下面哪一项属于化学变化？",
	"Which gas do plants absorb from the air to make their food?":
		"植物从空气中吸收哪种气体来制造养分？",
	"Which material usually allows electricity to flow most easily?":
		"哪种材料通常最容易导电？",
	"Which principle helps estimate elapsed time from a changing process?":
		"根据一个正在变化的过程推算经过的时间，应当依据哪条原则？",
	"Which of these is a primary color of light?":
		"下面哪一种是光的三原色之一？",
	"Final synthesis lock":
		"最终综合锁",
	"Burning paper":
		"纸张燃烧",
	"Melting ice":
		"冰融化",
	"Breaking glass":
		"玻璃破碎",
	"Dissolving sugar":
		"糖溶解",
	"Carbon dioxide":
		"二氧化碳",
	"Oxygen":
		"氧气",
	"Nitrogen":
		"氮气",
	"Argon":
		"氩气",
	"Metal":
		"金属",
	"Rubber":
		"橡胶",
	"Dry wood":
		"干木头",
	"Glass":
		"玻璃",
	"Red":
		"红",
	"Yellow":
		"黄",
	"Purple":
		"紫",
	"Brown":
		"棕",
	"Measure a reasonably steady change and compare independent indicators":
		"测量一个足够稳定的变化量，并比对多个独立线索",
	"Trust the first visible clue":
		"相信第一眼看到的线索",
	"Use the color of one object":
		"只看某一件物品的颜色",
	"Assume every process changes at the same rate":
		"假设所有过程的变化速率都相同",
	"A new substance forms":
		"生成了新的物质",
	"The paper only changes shape":
		"纸张只是改变了形状",
	"The ash is the same substance as the paper":
		"灰烬与纸张是同一种物质",
	"Heat cannot change matter":
		"热量无法改变物质",
	"Photosynthesis":
		"光合作用",
	"Condensation":
		"凝结",
	"Magnetism":
		"磁性",
	"Sound transmission":
		"声音传播",
	"Several independent indicators that changed at reasonably steady rates":
		"多个以足够稳定速率变化的独立线索",
	"One clock reading by itself":
		"仅凭一个钟表读数",
	"A guess based on the first clue":
		"基于第一条线索的猜测",
	"Press E to study ":
		"按 E 研究",
	"This knowledge has been added to NoteHub.":
		"这条知识已记入笔记本。",
	"The color of one object":
		"某一件物品的颜色",
	"Knowledge Notes":
		"知识笔记",
	"Close note":
		"关闭笔记",
	"Tutorial: Knowledge Notes\n\n":
		"教学：知识笔记\n\n",
	"This tool stores important knowledge you discover while exploring.\n\n":
		"这个工具会记录你在探索中发现的重要知识。\n\n",
	"Use it when a knowledge lock asks a question. You can open it from the top-left Notes button or by pressing K.\n\n":
		"当知识锁向你提问时就打开它。点左上角的「笔记」按钮，或者按 K 键。\n\n",
	"As you progress, more tools may unlock here, such as Evidence, Objectives, Map, or Inventory.\n\n":
		"随着调查推进，这里还会解锁更多工具：证据、目标、地图、行囊。\n\n",
	"Parchment Scroll (Study Desk)\n\n":
		"羊皮卷轴（书桌）\n\n",
	"Observation:\nEach Ashford room is sealed by a physical key and a knowledge question. The question appears on the door only after the matching key is used.\n\n":
		"观察：\n阿什福德的每个房间都由一把实体钥匙和一道知识题共同封锁。只有先用对钥匙，门上才会浮现问题。\n\n",
	"How to Apply It:\nFind the room's key, read the question on its door, then search the room for evidence of the answer.\n\n":
		"怎么用：\n先找到这个房间的钥匙，读门上的问题，再回房间里找出答案的依据。\n\n",
	"Bookshelf: The Science of Flame\n\n":
		"书架：火焰的科学\n\n",
	"Observation:\nA science volume on the bookshelf explains that a flame cannot keep burning without oxygen from the air.\n\n":
		"观察：\n书架上的科学书写道：没有空气中的氧气，火焰就无法持续燃烧。\n\n",
	"Science Concept:\nFire needs oxygen to keep burning. If oxygen is removed or blocked, the flame weakens and goes out.\n\n":
		"科学概念：\n火焰需要氧气才能持续燃烧。氧气被耗尽或阻断时，火焰会变弱直至熄灭。\n\n",
	"How to Apply It:\nIf the knowledge lock asks what a flame needs from the air, the answer is oxygen.":
		"怎么用：\n如果知识锁问「火焰需要空气中的什么」，答案就是氧气。",
	"No notes collected yet.\n\nInspect the study desk to learn how Ashford's room locks work.":
		"还没有记下任何笔记。\n\n去调查书桌，先弄明白阿什福德的门锁是怎么运作的。",
	"--------------------------------\n\n":
		"--------------------------------\n\n",
}
