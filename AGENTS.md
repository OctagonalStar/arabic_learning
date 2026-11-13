# AGENTS.md

跨平台 Flutter/Dart 阿拉伯语单词学习应用（AGPL-3.0）。目标平台 **Android / Windows / Linux / macOS / iOS / Web**；iOS 只出无签名 IPA（不签名、不上架）。**UI 与注释统一中文。**

> **改代码前先读 [`docs/shared-api.md`](docs/shared-api.md)**：共享组件、token、单例与纯函数手册。
> 已有实现一律复用，不要新建第二份；新增组件后同步更新该文档。

## 常用命令

```bash
flutter pub get
flutter run
flutter analyze          # 必须 0 issues（排除 build/、各平台目录、生成的 lib/oss_licenses.dart）
flutter test             # 650+ 用例，必须全绿
flutter build web --release
```

- **测试**：`test/` 下 `core`、`funcs`、`vars`、`services`、`theme`、`widgets`（目录名对应被测模块）、
  `test/macos_entitlements_test.dart` 与 `test/widget_test.dart` 冒烟测试，共享 fixture 在 `test/helpers/`。
  `test/helpers/test_env.dart` 提供 `mockPathProvider()`、`mockStorage(...)`：**在 `setUp` 里先调用**，
  否则触碰 `Global`/`AppData` 会因平台插件抛 `MissingPluginException`。动态取色在
  `test/theme/theme_resolver_test.dart` 用 `dynamic_color_testing` 打桩。
  CI 不跑 `test`/`analyze`（只跑 `pub get` + 各平台 `build`），所以本地这两步不能省。
- **Flutter 版本**：CI 全部用 **3.47.5**；`pubspec.yaml` 要求 Dart `^3.13.0`。
  `android/gradle.properties` 保留 `android.newDsl=false` / `android.builtInKotlin=false`
  （AGP 9 新 DSL 与内置 Kotlin 的退出开关）。升级依赖前注意：`material_ui` 1.3.0 已撤回，
  且 sherpa_onnx 2.x 删掉了 espeak-ng（阿语模型没有 lexicon，升上去只会输出空音频）。
- **生成文件**（无脚本包装）：`flutter_launcher_icons` 生成图标；`dart run dart_pubspec_licenses:generate`
  重新生成 `lib/oss_licenses.dart`（依赖变更后必做，禁止手改，已在 `analysis_options.yaml` 排除）。

## 目录结构

```
lib/
  main.dart      # 仅引导：日志、方向锁、workmanager、window_manager、runApp
  app.dart       # MyApp（init FutureBuilder + 主题化 MaterialApp）、MyHomePage（自适应导航壳）
  core/          # 纯函数/平台门面：adaptive, navigation, statics, extensions, date_utils,
                 # selection, version, wav, recitation_text（阿语归一化/分词）, ai_prompt,
                 # license_storage, doh* / json_offload*（条件导入 shim）
  models/        # 不可变数据 + 序列化：config, dict, plan, reading, recitation_text, synonym
  services/      # 逻辑与单例：global_state(Global), app_data, fsrs, search(BKSearch), words,
                 # plan_*, recitation_*, tts, sync, download, model_manager, update*, db/
  theme/         # tokens, app_theme, page_transitions, theme_resolver, typography
  widgets/       # 共享组件：kit.dart(纯 barrel) + 各实现文件 + questions/overlays/shared/
                 # feedback/motion/flip_word_card/type_choose_card/question_chain_editor
  screens/       # 页面：home/, learning/, test/, setting/, policy/
  package_replacement/  # Web shim，勿删
```

重构前的 `pages/`、`sub_pages_builder/`、`vars/`、`funcs/`、`ui.dart`、`utili.dart` 已不存在，别引用。

## 架构要点（非显而易见）

- `main()` 只做引导，然后 `runApp` 一个 **唯一的 `ChangeNotifierProvider<Global>`** 包住 `MyApp`；
  重初始化全部放进 `MyApp` 内 `FutureBuilder` 等 `Global.init()`。
- **全应用只有一个 provider：`Global`**（`services/global_state.dart`）。其余是手写单例
  （`AppData()`、`FSRS()`、静态 `BKSearch`）或页面局部 `ChangeNotifier`（`PKServer`、`SingleSelectionNotifier`）。
  `context.read<Global>()` 常只用于写日志（`uiLogger`）。
- **导航不是路由表**：`MaterialApp.home` + 自适应壳 `MyHomePage`——桌面（宽 > `AppBreakpoints.mobile`）
  用 `NavigationRail` + 纵向 `PageView` 四页（Home/Learning/Test/Setting），移动端用横向 `PageView` +
  `NavigationBar`，共用一个 `PageController`；无命名路由、无路由包。详情页统一用
  `lib/core/navigation.dart` 的 `pushPage` / `pushPageOn`（已持有 `NavigatorState`）/ `replacePage`，
  `MaterialPageRoute` 只在该文件内构造，转场由 `theme/page_transitions.dart` 统一提供。
- **分层**：`screens` → `services`/`models`/`theme`/`widgets` → `core`。
  `services` 不碰 UI（不接收 `BuildContext`、不弹窗），`models` 不 import `services`。
- **计划学习**（`models/plan.dart`、`services/plan_store.dart` + `plan_scheduler.dart`、`screens/learning/plan/`）：
  以 FSRS 卡片判定「已学」，按截止日期与课程范围算每日最低量，按组出题。范围只存「词库文件名 + 课程名」，
  不存 word id；今日进度在 `planData`（`PlanState{plan,today}`）按日快照，跨日自动重建。
  `planBlocksStreak()` 是连胜门禁的唯一判定入口，由 `Global.updateLearningStreak()` 调用。
- **模型管理**（`screens/setting/model_management_page.dart`、`services/model_manager.dart`）：目录集中在
  `core/statics.dart`（`StaticsVar.ttsModels`/`asrModels`/`dictRepos`，`id` 同时是解压目录名与发布包名
  `<id>.tar.bz2`）。首选 TTS/ASR 存在 `AudioConfig.preferredModelId`/`preferredAsrModelId`（空串即默认）。
  下载/解压/删除/导入统一走 `ModelManager`；`AppData.loadTTS` 用 `resolveTts` 按目录内容选 VITS 或 Kokoro，
  `recitation_asr` 用 `resolveAsr` 选 Whisper 或 NeMo CTC；**切换或删除模型前必须 `resetTTS()`**。
  导入不限定内置目录名，按包内文件结构识别类型；模型来自用户自备文件，来源与许可由用户自负。
  **Web 端**同样可下载/导入/删除：文件存 IndexedDB（`web_model_store.dart`，库 `models.db` 的 `files`+`meta`，
  不进 `usedKeys` 备份）；加载时先 `initBindingsAsync()`，再用 `Module.FS.createPath/writeFile` 写进 wasm MEMFS，
  配置路径统一 `models/<id>/...`（ID 取包内顶层目录名）。1.13.8 的 wasm 仍内置 espeak-ng：VITS 与 Kokoro
  都必须挂载 `espeak-ng-data` 全部文件并把 `dataDir` 指向该目录（Kokoro 传空串会报
  `Please provide --kokoro-data-dir`）。
- **课文背诵**（`screens/test/recitation/`、`services/recitation_*.dart`、`models/recitation_text.dart`）：
  课文库存 `recitationTextData`，导入靠粘贴 JSON（`RecitationTextUnit.buildFromMap` 宽松解析：Markdown 围栏、
  字段别名、纯字符串句子、`passage` 兜底）或复制 `ai_prompt.dart` 的 `recitationPrompt` 交给外部 AI 整理。
  详情页分「学习 / 逐句 / 整篇」：学习页逐句给原文+译文+注释，点词先 `lookupStems` 剥前附词
  （وال/بال/كال/فال/لل/ال/و/ف/ب/ك/ل）与后附词（ها/هم/هن/كما/كم/نا/ه/ك/ي/ات/ون/ين/ان）再查词库，命中本课生词优先；
  背诵页原文与译文默认 `ImageFiltered` 模糊，可逐句或全局显示。流程：录音（`record`，16k 单声道 WAV）→
  20ms RMS 能量分析（语音占比、停顿、切段，**不引入 VAD 模型**）→ Whisper tiny 逐段识别 → 归一化词序列 LCS 对齐 →
  覆盖率/插入/顺序/时长/停顿打分。只做词级指标，不做音素级评分；门禁命中（听不清 / 太短 / 没识别完整）不给分。
  成绩只存摘要（`recitationData`，按 `reference` 哈希索引），不存录音，**不得接入 FSRS 调度**。
  逐句 tab 每张卡单独录音、出分后停在本句由用户手动翻页，成绩只在本次会话（不写 `recitationData`）；
  整篇沿用整篇评分与历史。三 tab 底部共用 `RecitationProgressBar`；学习页与逐句页的卡片外框/标签/译文块共用
  `recitation_shared.dart`；详情页阿语用 `headline` 级字号、译文低一级。Web 端已启用：录音走 `record` 的浏览器实现
  （返回 blob URL，`RecitationService` 用 dio 读字节），识别与本地 TTS 一样把模型挂进 wasm MEMFS；仅支持 HTTPS/localhost。
- `core/adaptive.dart` 的 `AdaptiveScope`/`AdaptiveData` 挂在 `MaterialApp.builder` 下（`home` 与所有 push 页共享），
  用 `AdaptiveScope.of(context)` 读（无 scope 时回退 `MediaQuery`）。它替代旧全局 `AppData().isWideScreen`；
  `AdaptiveTabBody` 负责 Tab 页尺寸与滚动兜底。方向策略：手机（最短边 < 600）锁竖屏，其余不限（`shouldLockPortrait`）。

## 主题与动效

- 设计 token 全在 `theme/tokens.dart`：`AppSpacing`、`AppRadius`、`AppMotion`、`AppBreakpoints`
  （含 `contentWidth(context)`：详情页正文宽 = 屏宽 90% 且 ≤760）、`AppSemanticColors`
  （`ThemeExtension`，经 `context.semanticColors` 或 `Theme.of(context).extension<AppSemanticColors>()` 读）。
  `StaticsVar.br`/`StaticsVar.curve` 是 token 代理。**禁止硬编码间距、圆角、动画时长。**
- `theme/app_theme.dart` 构建 M3 明暗 `ThemeData`（`AppBar` 统一 `centerTitle`，页面标题不要再套 `Center`）；
  `theme/typography.dart` 提供 `arabicStyle`/`arabicTextStyle`/`withoutColor`；
  `theme/theme_resolver.dart` 是纯函数（`themeModeFromConfig`、`darkModeFromThemeMode`、`seedScheme`、`resolveSchemes`）。
- 主题模式三态：`RegularConfig.themeMode`（0 系统 / 1 亮 / 2 暗）。旧 `RegularConfig.darkMode` 仍写入以兼容降级，
  读旧数据时反推 `themeMode`（`true→2`、`false→1`）。
- 动态取色用 `dynamic_color`，由 `RegularConfig.dynamicColor` 控制。`resolveSchemes` 取系统主色（Android）或
  强调色（桌面），任何失败都回退到 `ColorScheme.fromSeed(StaticsVar.themeList)`。
  **Web 无动态取色实现，永远回退种子色**（`kIsWeb` 守卫 + `MissingPluginException` 兜底）。
- 入场/切换动画用 `widgets/motion.dart` 的 `FadeSlideIn`、`StaggeredEntrance`、`CrossFadeSwitcher`（均尊重系统
  「减弱动态效果」）。页面转场已在 `buildTheme` 全局注册，跳转处无需再指定。

## 存储与数据

- `lib/package_replacement/storage.dart` 里有一个**同名自定义 `SharedPreferences` 包装类**（不是插件）：
  Web 走 idb_shim IndexedDB（失败回退 shared_preferences），其余平台走 shared_preferences。**导入这个包装类。**
- **备份契约**：只有 `usedKeys` 里的键（`settingData`、`wordData`、`fsrsData`、`readingData`、`synonymData`、
  `favoriteData`、`planData`、`pushSessionData`、`learningSessionData`、`recitationData`、`recitationTextData`）
  会被 WebDAV/本地导出保存与恢复。**新增顶层存储键必须注册进 `usedKeys`**，否则会被静默丢弃。
- 设置一律 `AppData().config = AppData().config.copyWith(...)` 再 `Global.updateSetting()`（落盘 + `notifyListeners`），
  不是 provider 状态；恢复数据后调用 `Global.conveySetting()` 重建 `Config`。
- `AppData.basePath` 是 `late final`，只在 `!kIsWeb` 时赋值——**Web 上绝不能读**。TTS 模型与缓存走 `path_provider`，
  与键值存储无关。
- 词库整体存成一个 JSON 字符串放在 `wordData`（`{"Words":[...],"Classes":{fileName:{className:[indexes]}}}`）。
  `WordItem.id` 是位置下标，`toMap` 不写；导入 JSON 是另一套 schema（`{ClassName:[{arabic,chinese,explanation}]}`），
  由 `AppData.dataFormater` 转换。导出是「以 `usedKeys` 为键、值是 JSON 字符串」的 JSON（双重编码）。
- `ReadingUnit.toMap(export: true)` 故意省略答案 `corrects`。

### word-ID 强契约

`WordItem.id` 是 `wordData.words` 的位置下标，**不序列化**，`DictData.buildFromMap` 载入时按数组顺序重新推导。
因此仅在数组没有被重排/缩短时稳定。所有以 id 为键的旁路存储必须在下列时机同步：

- `AppData.compactUnreferencedWords` 重排/缩短 → 用共享的 `oldToNew` 映射调用各 store 的 remap
  （FSRS：`FSRS().remapWordIds`；收藏：`FavoriteStore().remap`）。不在 `oldToNew` 里的 id 直接丢弃。
- `AppData.resetDictsPreservingFsrs` 清空全部单词 → 一并清空以 id 为键的旁路数据（`FavoriteStore().clear()`）。
  只保留 FSRS，并按词条身份（`arabic.identityKey()`）经 `restoreFsrsFromPending` 恢复；收藏故意不恢复。
- `AppData.deleteDictSource` 保留词条（不重排），但要用 `FavoriteStore().removeAll(unreferencedWordIds())`
  丢掉新失效词的收藏。

**新增 id 键 store 必须**：(1) 成员用 `Set<int>` 保证 O(1)；(2) 存储键注册进 `SharedPreferences.usedKeys`；
(3) 在 `AppData.init()` 里加载、在 `Global.reloadStoredData()` 里重载。

## 平台与 Web 兼容

- Dart 不能任意条件 import，原生专属代码用 **`fake_*.dart` shim**：
  `import 'package:.../fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;`。
  `lib/package_replacement/` 里的空实现是 Web 构建的承重墙，**不要删**（见其 README）。
- 现有 fake：`fake_dart_io.dart`（dart:io + idb 类型）、`fake_sherpa_onnx.dart`（已无调用点，仅为历史说明保留）。
  `sherpa_onnx` 现在直接 import（1.13.8 自带 Web 实现），Web 侧必须先 `await initBindingsAsync()`。
  其余插件（`window_manager`、workmanager/notifications、`mobile_scanner`、`flutter_webrtc`、`wakelock_plus`、
  `flutter_tts`、`dynamic_color`、`record`）直接 import，但用 `StaticsVar.isDesktop` / `kIsWeb` /
  `io.Platform.isAndroid` 做运行时守卫（或包在 `MissingPluginException` 捕获里）。
- **Web-only 代码用反向条件导入**（`dart:js_interop` 在 VM 编不过）：门面 + `_stub.dart` + `_web.dart` 三件套，
  条件统一 `if (dart.library.html)`（与 `storage.dart` 一致），例如 `blob_url.dart`、`web_model_store.dart`。
  因此 `flutter build web --wasm` 会落到 stub，沿用现有 Web 限制。**不要直接 import `dart:js_interop`。**
- 新增原生专属依赖：要么加 `fake_*.dart` + 条件导入，要么加 `kIsWeb`/`io.Platform` 守卫，并重新生成 `oss_licenses.dart`。
- `ios/` 由 Flutter 3.47 模板生成（含 `SceneDelegate`，走 CocoaPods；`ios/Podfile` 由首次 `flutter build ios` 自动生成，
  未入库），bundle id 沿用 `com.ayuban.arlearning`。只出无签名 IPA：`flutter build ios --release --no-codesign`，
  CI 把 `Runner.app` 装进 `Payload/` 打成 `ios-unsigned.ipa`（直接压缩 `iphoneos` 目录得到的 ipa 结构无效）。
- `ios/Runner/Info.plist` 已声明相机与本地网络用途（`mobile_scanner` 扫码、`flutter_webrtc` 局域网对战）：
  新增需要权限的原生功能要同步补 key，否则 iOS 上调用即失败。iOS 不提供应用内检查更新/APK 安装，
  入口由 `io.Platform.isAndroid` 守卫。

## 版本与发布

- `.github/workflows/FlutterBuild.yml` 的 `prepare` 作业算版本并注入所有构建：main 推送 →
  `x.y.(z+1)-alpha.<run_number>`，`--build-number` 随时间递增；打 `v*` tag → 直接用 tag。
  main 全平台构建成功后自动建 pre-release（tag `v<版本>`，正文取 `CHANGELOG.md` 的 `## Unreleased`）；
  正式版靠推 tag，正文取对应 `## V x.y.z` 段（`.github/scripts/changelog_notes.py`）。
- 应用内 `StaticsVar.buildVersion`（`--dart-define=APP_VERSION`）用于识别 alpha/rc；
  `RegularConfig.updateChannel`（0 正式 / 1 开发版）决定 `UpdateService` 查 `/releases/latest` 还是 `/releases?per_page=20`。

## 贡献约束

- 提交必须 **DCO 签名**：`git commit -s`。CI `CheckSignOff.yml` 会拒绝未签名提交（跳过 merge/revert/release/dep/ci 提交）。
  `CONTRIBUTING.md` 还要求 **GPG 验证**。
- 远端：`origin` = `OctagonalStar/arabic_learning`（上游，默认分支 `main`）；`JYinherit` = 贡献者 fork。
- 不要提交 API key 或 TTS/AI 凭据。
- `docs/smoke-checklist.md` 是每阶段与发版前的手动回归清单，`test/` 不能替代。

## 其他陷阱

- `CHANGELOG.md` 作为**运行时资源**打包并在应用内展示——必须保持合法 Markdown。
- `NotoSansSC` 由 `services/global_state.dart` 里的 `FontLoader` **手动加载**；`pubspec.yaml` 的 font 块是注释掉的，
  声明的 family 是空操作。
- `flutter_statix/` 是空的历史遗留目录，忽略。
- `BKSearch.init` 初始化后直接返回，所以运行中导入新词库不会重建索引（正确做法是 `BKSearch.rebuild`）。
- `flutter_tts`、`flutter_webrtc`、`workmanager_android` 仍应用 Kotlin Gradle Plugin，Flutter 会警告未来版本将构建失败，
  直到它们迁移到 Built-in Kotlin（当前 `android.builtInKotlin=false` 退出该模式）；`mobile_scanner` 7.4.2+ 已不再应用 KGP。
