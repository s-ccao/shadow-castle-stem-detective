# 新会话接管提示词（Claude Opus 5）

> 将下方“开始复制”到“结束复制”之间的全部内容粘贴到新的 VS Code Agent 会话。

---

## 开始复制

你正在 VS Code Agent 模式中接管一款接近发布的 Godot 游戏。请使用中文与我沟通，并持续采取实际行动；不要只给计划，也不要在能通过代码、测试或项目文件自行判断时向我提出不必要的问题。

# 项目定位

- 游戏：**Shadow Castle: STEM Detective**
- 引擎：Godot 4.7 stable，GDScript，GL Compatibility
- 设计分辨率：1024×768，2D 像素风 STEM 推理游戏
- **真正的项目根目录：** `/Users/yaleshen/shadow-castle-stem-detective`
- 当前 VS Code workspace 可能仍是 `/Users/yaleshen/algomap`，它不是游戏项目。工作前先进入真正项目目录；若工作区搜索找不到文件，请使用绝对路径或终端中的 `grep` / `find`，不要误判文件不存在。
- Godot 二进制：`/Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot`
- 当前日期：2026-08-14

# 第一动作（必须按顺序完成）

1. `cd /Users/yaleshen/shadow-castle-stem-detective`
2. 阅读以下文件，按此顺序建立事实模型：
   - `AGENTS.md`
   - `docs/AGENT_HANDOFF.md`（当前实现与测试的主要事实源）
   - `docs/PROJECT_STATUS.md`
   - `docs/AGENT_STAGE_REPORT.md`（最新完成阶段）
   - `docs/DEVELOPMENT_HISTORY.md` 的末尾阶段
   - `README.md`
3. 检查 `git status --porcelain` 和当前 diff。工作树非常脏，里面包含多个已验证但尚未发布的阶段；**全部视为有意保留的用户工作**。
4. 在编辑前运行基线解析和与当前任务有关的测试。不要在没有读取当前实现的情况下按训练记忆重写 Godot 代码。
5. 第一轮工作从“剩余发布路线”中的 Stage 15 开始，除非我在新会话里给出更高优先级的具体要求。

# 硬性仓库规则

- 保留当前 dirty worktree；禁止 `git reset`、`git checkout --`、`git clean` 或删除无法确认来源的改动/证据。
- **不要 commit、push、修改 remote、配置 Git 身份或处理 GitHub 凭据。** 发布同步由另一个 GitHub/Codex 维护者完成。
- 源码编辑使用补丁工具；不要用终端命令拼接或覆盖源码文件。
- 每个可见阶段完成后同步更新：
  - `docs/AGENT_STAGE_REPORT.md`
  - `docs/PROJECT_STATUS.md`
  - `docs/DEVELOPMENT_HISTORY.md`
  - `docs/AGENT_HANDOFF.md`
  - 必要时 `README.md`
- 最新完成阶段是 **`UX-20260814-14`**。下一个离散阶段从 **`UX-20260814-15`** 开始。
- 功能文字保持代码原生，不把可交互文字烘焙进图片。
- 角色尺寸改动只作用于视觉节点/脚底锚点；除非测试证明确有必要，不改变 CharacterBody2D、碰撞体、移动速度、A*、抓捕距离或交互半径。
- 新音频必须是原创可重现生成，或具有明确可发行许可并记录来源；不得使用版权不明素材。
- 当前没有得到发布到商店/网站或提交 Git 的授权。可以生成本地构建产物和发布文档，但不能替用户上传。
- Weapon Hub、Forge Hub、战斗、血条和体力系统目前是明确延后的非目标；除非我再次明确要求，否则不要加入，以免破坏“推理 + 躲避 + 炼金反制”的核心身份。

# 当前已完成且必须保留的系统

## 主流程

主菜单 → 开场动画 → Wake Room → Castle Hall → Chemistry → Greenhouse → Circuit → Dining → Library → Final Room → 普通结局 / 密封档案真相结局均已实现。死亡、重试、checkpoint、Continue 和返回大厅流程已有实现。

## Wake Room

- Desk 解锁调查工具包与不完整地图。
- Bed 提供 Wake Room Key。
- Bookshelf 提供氧气知识与 Chemistry Key。
- Door 使用实体钥匙 + 知识锁。
- 书架曾因“可见矩形”和“可行走接近点”错位而无法交互，已在 Stage 14 修复：
  - `interaction_rect` 必须继续等于可见像素矩形。
  - `_get_visual_interaction_approach()` 单独在 13.5px/14px 接触带上寻找可行走点。
  - `scenes/wake_room.tscn` 中 Bookshelf Visual 的 y 有 +6px 对齐修正。
- 修改 Wake 道具时必须同时跑 `wake_room_debug_path_test.gd` 和 `room_spatial_audit.gd`。

## 四个 Hub

- Bag 只有严格四类：`all`、`potions`、`materials`、`papers`。
- Materials = herbs + reagents/materials + dishes + final-key fragments。
- Papers = recipes/formulas + route/repair maps。
- 四个标签使用明确 `CATEGORY_BUTTON_RECTS`，逐一覆盖原 Bag 背景图的四个金属凹槽。
- Key 的新版 4×2 格子保持不重叠，并通过原图 atlas 区域适配到金框内。
- Note 使用更宽 dossier、真实滚动条和可聚焦关闭按钮。
- Map 与迷雾、房间标记、玩家和守卫标记共用严格坐标框，不得使用会裁切坐标的 cover 模式。

## 断电、地图和供电恢复

- `story_flags.circuit_power_restored` 是唯一供电事实源，已通过现有 `story_flags` 持久化，无需单独存储计数。
- 供电前：大厅每帧恢复纯黑，只保留当前 230px、80px 清晰区的墙体遮挡手电筒；走过区域仍黑。
- Full Map 和 Guardian minimap 供电前也不泄露建筑轮廓，只显示实时信号。
- 供电后：走过区域是灰色记忆，未走区域仍纯黑；世界、Full Map、minimap 必须一致。
- 主开关完成后已有：
  - 发电机双冲击环、机械回弹、轻镜头冲击、两次青色闪灯。
  - 原创 1.65s 电流声 `assets/audio/sfx/power_restore_surge.wav`（-7dB）。
  - 生成器：`tools/generate_power_restore_sfx.mjs`。
  - 来源记录：`assets/audio/README.md`。
- 第一次供电后回厅：
  - 不叠加普通 Guardian close-up。
  - 以 Circuit 门为中心按距离排序，用 1.20s 逐段恢复路线。
  - 扫描和 1.15s 奖励阅读窗内守卫暂停且不可抓捕，ETA/感知条隐藏。
  - 完成显示 `POWER RESTORED · ROUTE MEMORY ONLINE`。
  - 激活“立即打开 Map”目标；Map 扫描完成即可打开，打开后设置 `power_map_reviewed` 并清除临时目标。
  - 相关一次性标记：`power_restoration_sequence_pending`、`power_restoration_sequence_seen`、`power_map_objective_active`、`power_map_reviewed`。

## Guardian

- FSM：DORMANT / CHASE / PATROL / SEARCH / STUNNED；后两个枚举值是追加的，不能重排，旧存档依赖整数兼容。
- 追击速度：145 × `(1 + tier × 0.12)`，tier 来自持有的房间钥匙，最多 6。
- 玩家基础速度 180px/s；Tier 2 守卫约 179.8px/s。
- 回厅最小分离已从 520px 调为 **800px**，最坏 pre-Circuit Tier-2 反应时间为 **4.32s**。
- 追踪药剂净化前：守卫全知追踪。
- 净化后：300px、±46° 视野锥 + 78px 近身警戒 + 网格 LOS；丢失视野搜索 6s，然后在下一目标房间门口以 44px/s 徘徊。
- Daze 眩晕 7s；Shroud 隐身 12s。
- Guardian LOS 必须使用 `astar_grid.is_point_solid()`，不能复用 `is_player_position_walkable()`，因为门格不可走但必须可见。

## 当前公平性测量

真实 Hall A* 标准路径：

- Wake entrance → Chemistry：2656px，14.76s，Tier 1，回厅反应 4.78s。
- Chemistry → Greenhouse：2976px，16.53s，Tier 1，回厅反应 4.78s。
- Greenhouse → Circuit：1376px，7.64s，Tier 2，回厅反应 4.32s。
- 合计 38.93s，但被 Chemistry 与 Greenhouse 两个安全房间分成三个压力波。
- 自动证据：`docs/evidence/2026-08-14-power-restoration/STANDARD_FLOW_PRESSURE_AUDIT.md`。
- 仍需要一位不熟悉地图的人做一次 Wake→Circuit 人工试玩；自动测量不能代替首次玩家体验。

# 当前验证状态

最后一次验证结果：

- **12/12 逻辑套件通过**。
- **12/12 原生视觉夹具通过，共 113 张 1024×768 截图**。
- Godot editor parse/import：0 错误。
- `git diff --check`：通过。
- `power_restore_surge.wav` 可解码为 1.65s、立体声、16-bit PCM。
- 当前 QA 存档不存在：
  `$HOME/Library/Application Support/Godot/app_userdata/ShadowCastleSTEMDetective/shadow_castle_save.json`

逻辑套件：

1. `character_scale_profiles_test`
2. `guardian_hunt_flow_test`
3. `guardian_awareness_flow_test`
4. `power_blackout_flow_test`
5. `power_restoration_milestone_test`
6. `standard_flow_pressure_audit`
7. `hub_room_polish_contract_test`
8. `library_knowledge_access_test`
9. `library_light_challenges_test`
10. `room_spatial_audit`
11. `ui_design_contract_test`
12. `wake_room_debug_path_test`

视觉夹具：

1. `character_scale_visual_capture`（8）
2. `guardian_hunt_visual_capture`（3）
3. `guardian_pressure_visual_capture`（3）
4. `guardian_awareness_visual_capture`（7）
5. `power_blackout_visual_capture`（4）
6. `power_restoration_visual_capture`（4）
7. `hub_room_polish_visual_capture`（20）
8. `item_model_visual_capture`（5）
9. `library_light_challenges_visual_capture`（19）
10. `room_spatial_visual_capture`（24）
11. `ui_visual_gallery`（13）
12. `wake_room_debug_path_visual_capture`（3）

基础命令：

```bash
cd /Users/yaleshen/shadow-castle-stem-detective
GODOT=/Users/yaleshen/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --editor --quit-after 3000
$GODOT --headless --script tests/<suite>.gd
$GODOT --script tests/<visual_harness>.gd --position 40,40
git diff --check
```

视觉夹具必须窗口化运行，不要把它们改成 headless。`ui_visual_gallery.gd` 支持 `-- --output=<variant>`。

# 测试与存档纪律

- 自动测试设置 `GameState._loading_save = true` 防止真实写盘；测试结束恢复。
- 测试前记录 QA save 是否存在；测试后必须保持相同状态。当前为 absent。
- 若以后检测到存档存在，先区分用户真实存档与测试污染，禁止直接删除未知用户数据。
- Headless Hall intro 可能留下 `dialogue_active=true`，Guardian awareness 测试需显式调用 `_update_awareness()`，不要等待 physics 自动推进。
- Guardian reveal 会临时隐藏 `fog_sprite`；黑暗视觉夹具必须等 reveal 结束，否则截图是假阳性。
- 新增 Bag item 必须同步添加 `ITEM_VISUAL_INFO`，否则 UI contract 会失败。
- 本机没有 Python PIL/numpy；图像处理优先用 Godot `Image` API 或现有 Godot/Node 工具。

# 剩余发布路线（按优先级执行）

## Stage 15：大厅玩家与守卫视觉比例

目标：只在 Castle Hall 把玩家和守卫模型调小，保持脚底、碰撞、寻路、速度、LOS 和抓捕机制不变。

当前事实：

- Player 的 `VisualRoot` 所有房间目前都是 2.0；内部 AnimatedSprite scale 0.19，当前不透明站立高度约 91px。
- Guardian `GuardianCore.scale=1.0`，`position=(0,-56)`，不透明高度约 100px。
- 用户只要求大厅视觉建模变小，不要求改变其他房间。

建议初始视觉候选（不是未经验证就锁死的最终值）：

- Hall player `VisualRoot`：约 **1.60**（约 73px 不透明高度）。
- Guardian `GuardianCore.scale`：约 **0.84**（约 84px），仍比玩家明显大约 15%。
- 根据 alpha-bound 与脚底实测重新计算 Guardian y 锚点，不要简单保持 -56。

实施要求：

- 只修改 `ROOM_VISUAL_SCALE_PROFILES["floor_1_hub"]`、Guardian 视觉 scale/foot anchor 和对应测试常量。
- 不修改玩家/守卫 CharacterBody2D root、collision shape、速度、800px 分离、catch distance、A* 或 interaction。
- 在 1024×768 下用 Hall 门、家具、通道和双方同框截图判断，而不是只看数字。
- `character_scale_profiles_test.gd` 应把 Hall player 与其他房间期望拆开。
- 更新 `character_scale_visual_capture.gd` 并人工检查全部 8 个房间，确保 Hall-only 改动没有影响实例共享场景在其他房间中的 scale profile。
- 完成条件：逻辑契约通过、脚底无漂移、碰撞无变化、Guardian 仍清晰更大、原生截图确认比例合适。

## Stage 16：通关后 Case Archive 调查 UI

目标：通关后提供可反复调查的响应式档案界面，并从结局页和主菜单进入。

建议接口：

- 独立 `CaseArchiveUI` 场景/深模块，不把逻辑塞入 GameOverUI。
- 分类建议：Evidence / People / Timeline / Science / Verdict（可按现有数据适度调整，但不要堆成一个长文本页面）。
- 数据来自现有 `GameState.evidence_items`、`knowledge_items`、`story_flags`、`completed_rooms`、已保存 Note clues 和最终结论；先验证真实 ID，不要杜撰状态。
- 使用现有 `ArchiveUi` 视觉语言与 `CaseLocale` 中英文本。
- 结局页面现有 `view_conclusion_requested` 是接入点之一；主菜单需要仅在完成任一结局后显示 `CASE ARCHIVE`。
- 优先通过已有 ending story flags 推导解锁，或使用新的 story flag；尽量不增加并行布尔字段和不必要的 SAVE_VERSION 升级。旧结局存档必须迁移/自动识别。
- UI 必须支持键盘/手柄 focus、滚动、44px+ 触控目标、16:9/4:3 安全边距。
- 添加逻辑 contract、结局→Archive→返回、主菜单→Archive 集成测试，以及普通/真相结局、中英文和至少三种视口的视觉证据。
- 完成条件：任一结局可靠解锁，重新启动后主菜单仍可进入，所有分类数据真实、可读、可返回，旧存档不丢失。

## Stage 17：自适应背景音乐与音频设置

当前音频事实：

- 没有自定义 `default_bus_layout.tres`；目前只有隐式 Master。
- Intro 有 `AudioStreamGenerator` 程序氛围。
- Stage 14 新增唯一正式 WAV：`power_restore_surge.wav`，带可重现生成脚本与 provenance。
- 还没有完整 BGM、Music/SFX/UI/Voice buses、音量设置或全局 MusicDirector。

目标架构：

- 新增 `MusicDirector`/`AudioDirector` autoload，界面保持小而深。
- buses：Master / Music / SFX / UI / Voice；留足 headroom。
- PlayerPreferences 增加 master/music/sfx（必要时 voice）0..1 设置，通过 `linear_to_db` 映射并持久化。
- 音乐状态至少覆盖：Menu、pre-power exploration、safe-room/investigation、Guardian search/chase、post-power exploration、ordinary ending、true ending。
- Guardian 状态通过现有 `guardian_tracking_changed` 驱动；对话期间音乐平滑 duck，结束后恢复。
- 转场使用交叉淡入淡出；不要每次状态变化从头生硬播放。
- 音乐优先采用项目内可重现生成的原创预渲染循环，或明确 CC0/可商用素材；每个文件记录作者、来源、许可和编辑过程。
- 对 Web/移动设备做音频首次用户手势、暂停/恢复和性能测试。
- 完成条件：音乐状态过渡正确、设置持久化、无削波、对话可听、版权来源完整、桌面与 Web smoke test 均有声音。

## Stage 18：Web、桌面下载版和移动版

当前发布事实：

- 目前没有 `export_presets.cfg`。
- 1024×768 + `canvas_items`，GL Compatibility 对 Web/移动较友好。
- 输入仍以键盘/鼠标为主；正式称为“手机版”之前必须增加触控与 safe-area 验证。
- 存档已使用 `user://`，跨平台路径方向正确。

执行顺序：

1. 先做移动端交互审计：移动、交互、取消、Hub 打开/关闭、Map、Note、Bag、Key、对话、谜题、暂停/菜单都要能仅用触控完成。
2. 增加横屏触控方案（虚拟摇杆或 click/tap-to-move + 明确 Interact/Back），并支持安全区、最小触控面积与小屏文字。
3. 创建并验证 export presets：
   - Web
   - macOS
   - Windows x86_64
   - Linux x86_64
   - Android（APK/AAB）
   - iOS（Xcode project）
4. 先检查当前 Godot 4.7 export templates 是否安装；缺失则明确安装/阻塞，不要假装构建成功。
5. 当前 macOS 机器能本地生成什么就实际生成并 smoke test。Android 需要 JDK/SDK/keystore；iOS 需要 Xcode、证书和 provisioning。签名密钥/密码由用户直接在终端或系统工具中输入，不通过聊天收集。
6. Web 构建用本地 HTTP 服务器测试，不能用 `file://`。若启用线程，部署需 COOP/COEP；优先评估无线程导出以降低静态托管门槛。
7. 生成下载版压缩包、版本号、图标/启动图、许可/credits、已知问题和平台安装说明。
8. 完成条件：每个宣称支持的平台都有真实构建结果和 smoke-test 记录；不能构建的平台列出精确 SDK/签名阻塞项，不能标记为已发布。

# 发布前仍需完成的人工门槛

- 一位不了解地图的玩家完成 New Case → 至少 Circuit，最好完整到两种结局。
- 记录：卡关、误触、死亡、回厅压力、UI 溢出、文字可读性、音量平衡和首次通关时间。
- 检查 Continue / Retry / Checkpoint / New Case 删除旧档案的行为。
- 中英文完整跑一次关键 UI。
- 1024×768、16:9 桌面、Web 浏览器和目标手机横屏检查。
- Credits/许可/音频和生成资产 provenance 完整。
- 禁用或门控开发者输出/F3，不在 release build 暴露调试工具。

# 每个阶段的完成协议

1. 先建立能在改动前失败、改动后通过的 focused contract。
2. 最小实现，不重排无关系统。
3. 运行 focused tests，修复真实失败。
4. 运行全量逻辑和视觉 gate，并人工检查新截图。
5. 检查解析、diagnostics、`git diff --check`、测试存档前后状态。
6. 更新阶段文档，Stage ID 递增。
7. 最终回复说明：做了什么、为什么这样设计、测试结果、仍存在的真实阻塞项；不得声称未实际构建的平台已发布。

现在请先完成“第一动作”，用一段简短事实摘要确认你已经读取了当前项目，而不是复述本提示词；随后立即开始 Stage 15 的 Hall visual scale focused contract 与原生视觉校准。不要 commit 或 push。

## 结束复制
