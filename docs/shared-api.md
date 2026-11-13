# 共享组件与 API 手册（给 AI Agent）

改代码前先查这份文件。**项目里已有的实现一律复用，不要新写第二份。**

查不到时按顺序：本文件 → `grep -rn "组件名" lib` 看真实调用点 → 确实没有才新增，
并放到上表对应的目录（组件进 `lib/widgets/`，纯函数进 `lib/core/`，状态与 IO 进 `lib/services/`）。

## 分层与依赖方向

```
screens/  →  services/  models/  theme/  widgets/
                ↓           ↓        ↓        ↓
                        core/
```

- `screens/` 只做布局与交互，可 import 其他所有层。
- `services/` 不 import `screens/`、`widgets/`，**不接收 `BuildContext`**；要弹窗就把结果返回给页面。
- `models/` 只 import `core/`（不可变数据 + 序列化）。
- `widgets/` 不 import `screens/`；需要业务状态时由调用方传参。
- `core/` 只依赖 dart/flutter 基础库，不依赖上面任何一层。

## widgets/ —— 共享 UI 组件

### 基础控件（经 `widgets/kit.dart` barrel 导出）

| 符号 | 文件 | 作用 / 何时用 |
| --- | --- | --- |
| `Button` | `app_button.dart` | 全局按钮。M3 填充色调配色（默认 `primaryContainer`），按压 0.98 缩放反馈，图标可四向排布。参数：`child`、`icon`+`iconDirection`、`onPressed`、`size`、`padding`、`shape`、`backgroundColor`/`foregroundColor`。**不要直接用 `ElevatedButton`**。 |
| `TextContainer` | `text_container.dart` | 带背景色的纯展示文本块；`selectable` 可复制，`animated` 时背景生长 + 文本淡入上移。 |
| `CategoryChips` | `category_chips.dart` | 只读展示一组分类标签（`Wrap`）。 |
| `SelectChip` | `category_chips.dart` | 多选筛选 chip（`FilterChip` 统一外观）。 |
| `CategoryFilter` | `category_chips.dart` | 分类筛选面板：`available` 候选 + `selected` 集合 + `onChanged`。 |
| `ChooseButtons` | `choose_buttons.dart` | 选择题四选项按钮组。 |
| `ChooseButtonBox` | `choose_buttons.dart` | 单个选项按钮，判定反馈由内部 `AnimationController` 驱动（约 700ms）。 |
| `popSelectClasses` | `class_select.dart` | 弹出课程选择页，返回 `ClassSelection`；`withCache` / `withReviewChoose` 切换选择模式。 |
| `classesSelectionList` | `class_select.dart` | 内嵌式课程勾选列表（不弹页）。 |
| `ClassSelectPage` | `class_select.dart` | 课程选择整页（一般通过 `popSelectClasses` 使用）。 |
| `SettingItem` | `setting_controls.dart` | 设置分区容器：`title` + `children`，首尾圆角、项间自动分隔。 |
| `SettingRow` | `setting_controls.dart` | 单行设置项：`leading` + `note` + 尾部 `end` 控件。 |
| `SettingRedirectButton` | `setting_controls.dart` | 整行跳转按钮：`title` + `target`，内部走 `pushPage`。 |

> `kit.dart` 是**纯 barrel**，新增代码优先直接 import 实现文件。

### 业务组件（直接 import）

| 符号 | 文件 | 作用 |
| --- | --- | --- |
| `ChoiceQuestions` | `questions.dart` | 选择题页（题面 + 选项 + 判定）。 |
| `WordCardQuestion` | `questions.dart` | 卡片题：展示单词卡片。 |
| `SelfRatingQuestion` | `questions.dart` | 自我评级题：卡片 + 评级按钮。 |
| `SpellQuestion` | `questions.dart` | 拼写题。 |
| `ListeningQuestion` | `questions.dart` | 听力题（含播放与重播）。 |
| `TestItem` | `questions.dart` | 题面公共外壳（题干 + 提示文本）。 |
| `FlipWordCard` | `flip_word_card.dart` | 翻卡单词卡片（正/反面、发音、收藏、释义遮挡、FSRS 记忆态）。列表、复习、详解浮层都用它。 |
| `WordCardInfoRow` / `WordCardArabicButton` | `flip_word_card.dart` | 卡片内的双栏信息行 / 顶部阿语发音按钮。 |
| `ReviewForecastChart` | `review_forecast_chart.dart` | 未来复习量折线图卡片（7/14/30/60 天切换）。 |
| `QuestionChainListView` | `question_chain_editor.dart` | 题型序号链展示（长按拖动排序、可删除）。 |
| `QuestionTypeAddMenu` | `question_chain_editor.dart` | FAB 展开后的「添加题型」按钮组。 |
| `TypeChooseCard` | `type_choose_card.dart` | 向导式大号类型选择卡（标题 + 说明 + 箭头）。 |
| `EmptyHintCard` | `shared.dart` | 空状态提示卡（`EmptyHintCard("暂无收藏单词")`）。 |
| `StatCard` | `shared.dart` | 首页统计卡（`width`/`height`/`spacing`/`label`/`value`/`statusIcon`）。 |
| `SettingCard` | `shared.dart` | 设置页参数卡（`color` + `child`，`padding` 默认 8）。 |
| `ConclusionCard` | `shared.dart` | 学习结果卡，`visible` 驱动滑入与数值动画。 |
| `PKScoreRow` | `shared.dart` | 对战计分行（双条对比 + 动画）。 |
| `RevealableActionBar` | `shared.dart` | 底部双按钮栏（「查看详解 / 下一题」），`revealed` 驱动揭示动画。 |
| `ButtonLabel` | `shared.dart` | 按钮内文字惯用法 `Expanded + FittedBox`；只缩不放。 |
| `LoadingIndicator` | `feedback.dart` | 不确定进度指示器，颜色解析与原生一致。 |
| `ProgressBar` | `feedback.dart` | 线性进度条（下载 / 解压 / 同步统一用它）：`value` 0~1，null 为不确定进度；确定值按 `AppMotion.quick` 插值；`animationsDisabled` 为 null 时读系统「减弱动态效果」；`minHeight` 默认 6。**不要直接写 `LinearProgressIndicator`**。 |

### 弹窗 / 浮层 / 提示

| 符号 | 文件 | 作用 |
| --- | --- | --- |
| `alert(context, msg, {...})` | `overlays.dart` | **应用内唯一的确认弹窗**。支持 `title`、`confirmLabel`、`destructive`（多给「取消」+ 错误色）、`delayConfirm`（倒计时确认）、`onConfirmed`。不要自己写 `AlertDialog`。 |
| `showSnackBar(context, msg, {duration})` | `overlays.dart` | 底部瞬时提示。 |
| `viewAnswer(context, word, {chosenWrong})` | `overlays.dart` | 详解弹窗；`chosenWrong` 非空时展示同义/不同标记区。 |
| `showWordCardOverlay(context, word)` | `overlays.dart` | 长按选项弹出的单词卡片浮层（点遮罩关闭）。 |
| `showEmptyDictDialog(context, {onImport})` | `empty_dict_dialog.dart` | 词库为空时的引导弹窗。 |
| `showUpdateSheet(context)` | `update_sheet.dart` | **应用内更新的唯一提示入口**；返回 `UpdateSheetResult.download` 表示要打开下载页。 |

### 动效封装

| 符号 | 文件 | 作用 |
| --- | --- | --- |
| `FadeSlideIn` | `motion.dart` | 单元素入场（淡入 + 位移），`delay` 走同一时间轴。 |
| `StaggeredEntrance` | `motion.dart` | 列表/网格项交错入场，`index` 递增延迟，默认前 20 项。 |
| `CrossFadeSwitcher` | `motion.dart` | 状态切换交叉淡入；`child` 必须带不同的 `Key`。 |

三者都尊重系统「减弱动态效果」，并默认使用 `AppMotion` token。**新动画一律用它们或 token，
不要硬编码 `Duration(milliseconds: ...)`。**

## theme/ —— 设计 token

| 符号 | 文件 | 说明 |
| --- | --- | --- |
| `AppSpacing` | `tokens.dart` | `xxs=4 / xs=8 / sm=16 / md=24 / lg=32`。 |
| `AppRadius` | `tokens.dart` | `card=25 / control=12` + 现成 `cardBorder`/`controlBorder`/`cardShape`/`controlShape`。`StaticsVar.br` 即 `cardBorder`。 |
| `AppMotion` | `tokens.dart` | 时长：`quick`200ms / `mediumShort`250 / `medium`300 / `mediumLong`400 / `long1`500 / `long2`600 / `extraLong1`700 / `extraLong2`800 / `slow`1s / `slower`2s / `slowest`3s / `ultraSlow`4s；曲线：`standardCurve` / `emphasizedCurve` / `decelerateCurve`（入场）/ `accelerateCurve`（退场）/ `linearCurve`（纯时间映射）。 |
| `AppBreakpoints` | `tokens.dart` | `mobile=600 / tablet=1024 / desktop=1440`，`isMobile`/`isTablet`/`isDesktop`，以及 `contentWidth(context)`（详情页正文宽度：屏宽 90%，上限 760）。 |
| `AppSemanticColors` | `tokens.dart` | `ThemeExtension`：`success`/`onSuccess`/`warning`/`onWarning`/`error`/`disabled`/`disabledContainer`。读法见下。 |
| `arabicStyle` / `arabicTextStyle` / `withoutColor` | `typography.dart` | 套阿语备用字体（按是否需要）/ 剥离颜色保留排版属性。 |
| `buildTheme` | `app_theme.dart` | 构建 M3 明暗 `ThemeData`；`AppBar` 统一 `centerTitle`，所以页面标题不用再套 `Center`。 |
| `AppPageTransitionsBuilder` | `page_transitions.dart` | 全平台统一转场，已在 `buildTheme` 注册；页面跳转无需再指定转场。 |

`BuildContext` 上有便捷扩展（`core/extensions.dart`）：`context.semanticColors`
（等价 `Theme.of(context).extension<AppSemanticColors>()`）、字符串/数字/列表扩展。

## core/ —— 纯函数与平台门面

| 符号 | 文件 | 作用 |
| --- | --- | --- |
| `pushPage` / `pushPageOn` / `replacePage` | `navigation.dart` | **唯一的页面跳转方式**。`MaterialPageRoute` 只在这里构造。已持有 `NavigatorState` 时用 `pushPageOn`。 |
| `AdaptiveScope.of(context)` / `AdaptiveData` | `adaptive.dart` | 屏宽/宽屏判断（替代全局布尔）。`AdaptiveTabBody` 为顶层 Tab 页算尺寸并在高度不足时兜底滚动。 |
| `shouldLockPortrait(shortestSide)` | `adaptive.dart` | 手机锁竖屏；平板/桌面/Web 不限方向。 |
| `SingleSelectionNotifier` | `selection.dart` | 单选状态的 `ChangeNotifier`。 |
| `daysSinceEpoch` / `dueDayText` | `date_utils.dart` | 以 `learningEpoch` 计天数 / 到期相对文案（已逾期 N 天·今天·N 天后）。 |
| `versionStringToInt` / `versionIntToString` / `parseGithubTag` / `isNewerVersion` / `parseReleaseVersion` / `isNewerRelease` / `parseReleaseRedirectTag` | `version.dart` | 版本号编解码与比较（含 alpha/rc 后缀）。 |
| `normalizeArabic` / `tokenize` / `lookupStems` / `estimateSeconds` | `recitation_text.dart` | 阿语归一化、词序列、查词候选（剥前附词/后缀）、背诵时长估算。 |
| `encodeWav16` | `wav.dart` | Float32 采样 → 16-bit PCM WAV。 |
| `StaticsVar` 常量 | `statics.dart` | `appName`、`appVersion`、`buildVersion`（`--dart-define=APP_VERSION`）、`isDesktop`、`player`、`br`、主题种子列表 `themeList`、`ttsModels`/`asrModels`/`dictRepos` 目录、`learningMessage`、备份字体名。 |
| `AIPrompt` | `ai_prompt.dart` | 生成给外部 AI 用的提示词（词库整理 / 课文整理）。 |
| `LicenseVars` | `license_storage.dart` | 开源许可文本与字体许可展示数据。 |
| `DohResolver` / `buildDohHttpClient` / `createDio` | `doh*.dart`、`services/http_client.dart` | DoH 解析与统一 `Dio` 构建；Web 走 stub，忽略 `useDoh`。 |
| `decodeJsonOffMain` / `encodeJsonOffMain` | `json_offload*.dart` | 大 JSON 在后台 isolate 编解码（Web 退化为同步）。 |

## models/ —— 不可变数据

| 符号 | 文件 | 说明 |
| --- | --- | --- |
| `Config` + `DebugConfig` / `RegularConfig` / `AudioConfig` / `LearningConfig` / `QuizConfig` / `SyncConfig` / `SyncAccountConfig` | `config.dart` | 全部设置项；用 `copyWith` 改，经 `AppData().config = ...` + `Global.updateSetting()` 落盘。 |
| `DictData` / `SourceItem` / `ClassItem` / `WordItem` | `dict.dart` | 词库、词库来源、课程、单词。`WordItem.id` 是数组下标，见 AGENTS.md 的 word-ID 契约。 |
| `PlanScopeRef` / `PlanChain` / `StudyPlan` / `PlanDayProgress` / `PlanState` | `plan.dart` | 计划学习的全部持久化结构。 |
| `ReadingData` / `ClassSelection` / `ReadingUnit` / `ReadingQuestion` | `reading.dart` | 阅读测试数据。 |
| `RecitationWord` / `RecitationSentence` / `RecitationTextUnit` / `RecitationTextData` | `recitation_text.dart` | 课文库；`RecitationTextUnit.buildFromMap` 是宽松解析入口。 |
| `GlossPair` / `SynonymData` | `synonym.dart` | 同义/不同标记。 |

## services/ —— 逻辑与单例

| 符号 | 文件 | 作用 |
| --- | --- | --- |
| `Global`（`ChangeNotifier`，唯一 app 级 provider） | `global_state.dart` | 初始化编排、主题、设置持久化、`conveySetting()`、`reloadStoredData()`、`updateLearningStreak()`、`uiLogger`。`context.read<Global>()`。 |
| `AppData()` | `app_data.dart` | 词库/配置/TTS 的单例门面：`init()`、`config`、`wordData`、`importDictData`、`compactUnreferencedWords`、`resetDictsPreservingFsrs`、`deleteDictSource`、`loadTTS`/`resetTTS`、`storage`。 |
| `FSRS()` | `fsrs.dart` | 调度核心：`initAsync`、`produceCard`、`cardFor`、`isContained`、`getWillDueCount`、`getOverdueCount`、`getForecastCounts`、`remapWordIds`、`save/flush`。`FSRSConfig` 存参数。 |
| `BKSearch` | `search.dart` | 静态词库检索：`init` / `rebuild` / `lookup` / `search` / `searchWithTiers`。另有 `ArabicStemmer`、`VocabularyLookupIndex`、`wordsForRoot`。 |
| `FavoriteStore()` | `favorites.dart` | 收藏（`Set<int>`）：`toggle`、`contains`、`removeAll`、`remap`、`clear`。 |
| `SynonymStore()` | `synonyms.dart` | 同义/不同标记：`areSynonyms`、`isSynonymWord`、`markSynonym`、`markDistinct`、`synonymGroups()`。 |
| `PlanStore()` / `plan_scheduler.dart` 顶层函数 | `plan_store.dart`、`plan_scheduler.dart` | 计划的读写与推算：`evaluateNow`、`computeDailyMin`、`nextGroupWords`、`planBlocksStreak`、`extendPlanDeadline`、`resolveScopeWords`。 |
| `LearningSessionStore` / `LearningSessionCheckpoint` | `learning_session.dart` | 常规学习断点（`load`/`save`/`clear`）。 |
| `PushSessionStore` / `PushCheckpoint` / `buildDailyPushPlan` | `push_session.dart` | 每日推送断点与选词。 |
| `RecitationService` / `RecitationRecorder` / audio / asr / scorer / store | `recitation_*.dart` | 录音→能量分析→ASR→LCS 对齐→打分，成绩摘要落 `RecitationStore`。 |
| `ModelManager` | `model_manager.dart` | 本地模型下载/解压/删除/导入；`resolveTts` / `resolveAsr` 按目录内容识别架构。 |
| `playTextToSpeech` / `TtsFailure` | `tts.dart` | 统一朗读入口与错误归一。 |
| `UpdateService`（`ChangeNotifier`） | `update_service.dart` | 检查更新、下载、安装、跳过版本；错误描述在 `update/update_error.dart`。 |
| `WebDAV` | `sync.dart` | WebDAV 备份上传/下载（按 `usedKeys`）。 |
| `downloadFile` / `downloadBytes` / `extractTarBz2` | `download.dart` | **统一的文件传输入口**：`downloadFile(url, savePath, {onDownloading, cancelToken, options, dio})` 落盘（更新 APK、TTS/ASR 模型包都走它，`dio` 可注入调用方已配好 DoH/超时的客户端）；`downloadBytes` 进内存（Web / 无文件系统）；`extractTarBz2` 解压模型包。 |
| `WordMembershipIndex` | `memberships.dart` | 词条→课程归属反查（内存缓存）。 |
| `getSelectedWords` / `getRandomWords` / `buildChineseChoiceOptionWords` / `collectAllCategories` / `wordMatchesCategories` / `wordMatchesAnyCategory` / `calculateButtonBoxLayout` / `getStrokeDays` | `words.dart` | 出题、选词、分类筛选等纯选词逻辑。 |

## 常见任务 → 该用什么

| 要做的事 | 用这个 |
| --- | --- |
| 打开一个页面 | `pushPage(context, page)` / `replacePage` |
| 确认/警告弹窗 | `alert(...)`，危险操作用 `destructive: true` |
| 一句话提示 | `showSnackBar` |
| 列表项入场 | `StaggeredEntrance(index: i, child: ...)` |
| 加载→内容切换 | `CrossFadeSwitcher` + 不同 `Key` |
| 空列表占位 | `EmptyHintCard` |
| 按钮 | `Button`（`kit.dart`） |
| 间距/圆角/时长 | `AppSpacing` / `AppRadius` / `AppMotion` |
| 语义色 | `context.semanticColors` |
| 阿语文本样式 | `arabicStyle` / `arabicTextStyle` |
| 设置项 | `SettingItem` + `SettingRow` / `SettingRedirectButton` |
| 词库为空 | `showEmptyDictDialog` |
| 发现新版本 | `showUpdateSheet` |
| 读/改设置 | `AppData().config.copyWith(...)` → `Global.updateSetting()` |
| 读/改词库 | `AppData().wordData`；改完 `persistWordDataDeferred()`，新增/导入词库后再 `BKSearch.rebuild` |
| 新增持久化键 | 必须加进 `SharedPreferences.usedKeys` |

## 不要做

- 不要 `import 'package:shared_preferences/shared_preferences.dart'`，用 `package_replacement/storage.dart`。
- 不要在 `services/` 里接收 `BuildContext` 或弹窗。
- 不要直接构造 `MaterialPageRoute`。
- 不要为单处使用新建"通用"组件；先在本文件里找。
- 不要在 `models/` 里 import `services/`。
- 不要硬编码动画时长、圆角、间距（用 token）。
- 不要手改 `lib/oss_licenses.dart`（生成文件）或 `*.g.dart`。
