# AGENTS.md

Cross-platform Flutter/Dart app for learning Arabic vocabulary (AGPL-3.0). Targets **Android / Windows / Linux / macOS / Web**; iOS was dropped in v0.1.12. UI and comments are Chinese.

## Commands

```bash
flutter pub get
flutter run
flutter analyze          # expected 0 issues; excludes build/, all platform dirs and generated lib/oss_licenses.dart
flutter test             # unit + widget tests under test/ (85+ cases) — must pass
flutter build web --release
```

- **Tests live in `test/` and must pass.** Unit tests under `test/core`, `test/funcs`, `test/vars`, `test/theme`, `test/widgets` (dir names follow the modules they cover) plus the `test/widget_test.dart` app smoke test. `test/helpers/test_env.dart` mocks `path_provider` (`mockPathProvider()`) and `shared_preferences` (`mockStorage(...)`); call them in `setUp` before touching `Global`/`AppData`, otherwise platform plugins throw `MissingPluginException`. `dynamic_color_testing` mocks dynamic color in `test/theme/theme_resolver_test.dart`. Run with `flutter test`. No CI job runs tests or `flutter analyze` — all workflows only run `pub get` + `flutter build`.
- **Flutter version:** all CI jobs use **3.47.x** (Android pinned to **3.47.5**, Windows/macOS/Web to **3.47.0**). The old Android/3.44 pin was dropped: with AGP bumped to **9.1.0** + Gradle **9.3.1** (Flutter 3.47.5 template defaults) and plugins upgraded, Android builds cleanly — the breakage was the retracted `material_ui 1.3.0` (`@awaitNotRequired`, only exported by Flutter ≥3.47) plus the AGP 8.11.0 `>=8.11.1` validation, not the plugins themselves. `android/gradle.properties` keeps `android.newDsl=false` / `android.builtInKotlin=false` to opt out of AGP 9's new DSL and built-in Kotlin. `pubspec.yaml` requires Dart SDK `^3.11.0`; `pubspec.lock` currently floors at Dart `>=3.13.0` / Flutter `>=3.47.0`.
- Manual generators (no wrappers/scripts): `flutter_launcher_icons` for app icons, and `dart_pubspec_licenses` for `lib/oss_licenses.dart`. Regenerate with `dart run dart_pubspec_licenses:generate` (default output: `lib/oss_licenses.dart`; dev dependencies included) after any dependency change; never edit that generated file by hand. It is listed in `analysis_options.yaml`'s `exclude` because generator 3.2.0 no longer emits the `unnecessary_string_escapes` ignore header.

## Directory layout

```
lib/
  main.dart              # bootstrap only: logging, orientation, workmanager, window_manager, runApp
  app.dart               # MyApp (init FutureBuilder + themed MaterialApp) and MyHomePage (adaptive nav shell)
  core/                  # pure helpers: adaptive.dart, statics.dart, extensions.dart, date_utils.dart, selection.dart, ai_prompt.dart, license_storage.dart
  models/                # immutable models/constants: config.dart, dict.dart, reading.dart
  services/              # logic & singletons: global_state.dart (Global), app_data.dart, fsrs.dart, search.dart (BKSearch), words.dart, sync.dart, download.dart, tts.dart, notifications.dart, pk_server.dart
  theme/                 # tokens.dart, app_theme.dart, theme_resolver.dart, typography.dart
  widgets/               # shared widget kit: kit.dart, questions.dart, overlays.dart, shared.dart, feedback.dart, motion.dart
  screens/               # pages: home/, learning/, test/, setting/, policy/
  package_replacement/   # Web shims (do not delete)
```

The old pre-refactor paths no longer exist: `pages/`, `sub_pages_builder/`, `vars/`, `funcs/`, `ui.dart`, `utili.dart`.

## Architecture (non-obvious)

- `lib/main.dart` — `main()` sets up logging, orientation, Android `workmanager` (30-min task via `services/notifications.dart`), and desktop `window_manager`, then `runApp`s a **single `ChangeNotifierProvider<Global>`** wrapping `MyApp` (`lib/app.dart`). All heavy init is deferred into a `FutureBuilder` on `Global.init()` inside `MyApp`.
- **Only one app-wide provider exists: `Global`** (`lib/services/global_state.dart`). Everything else is a hand-rolled singleton (`AppData()` in `services/app_data.dart`, `FSRS()` in `services/fsrs.dart`, static `BKSearch` in `services/search.dart`) or a locally-scoped `ChangeNotifier` created inside a `MaterialPageRoute` (e.g. `PKServer`, `SingleSelectionNotifier`). `context.read<Global>()` is often used just to log.
- **Navigation is not route-based.** Root is `MaterialApp.home` + an adaptive shell (`MyHomePage`): desktop (`width > AppBreakpoints.mobile`, 600) uses `NavigationRail` + vertical `PageView` of 4 tabs (Home/Learning/Test/Setting); mobile uses horizontal `PageView` + `NavigationBar`, both driven by one `PageController`. No named routes, no router package. Detail screens live in `lib/screens/{setting,learning,test,...}/` and are opened with `Navigator.push(MaterialPageRoute(...))`.
- `lib/widgets/kit.dart` is the shared **widget kit** (custom `Button`, `TextContainer`, question widgets, `ClassSelectPage`), with questions/overlays/shared split into sibling files under `lib/widgets/` (some import `kit.dart` circularly; legal in Dart). `lib/models/` holds immutable models/constants only; `lib/services/` holds logic.
- `lib/core/adaptive.dart` provides `AdaptiveScope` / `AdaptiveData` (mounted under `MaterialApp` via its `builder`, so `home` and all pushed routes share one instance), read with `AdaptiveScope.of(context)` (falls back to `MediaQuery` when no scope). It replaces the old global `AppData().isWideScreen`; `AdaptiveTabBody` uses it for tab layout. Orientation policy in `lib/main.dart`: phones (shortest side < 600) lock portrait, tablets/desktop/Web allow all orientations via `shouldLockPortrait`.

## Theming

- `lib/theme/tokens.dart` — design tokens: `AppSpacing`, `AppRadius`, `AppMotion`, `AppBreakpoints`, and `AppSemanticColors` (a `ThemeExtension` for success/warning/error/disabled, read via `Theme.of(context).extension<AppSemanticColors>()`). `StaticsVar.br` / `StaticsVar.curve` proxy these tokens.
- `lib/theme/app_theme.dart` builds the Material 3 light/dark `ThemeData`; `lib/theme/typography.dart` resolves fonts/text roles; `lib/theme/theme_resolver.dart` holds pure helpers (`themeModeFromConfig`, `darkModeFromThemeMode`, `seedScheme`) plus `resolveSchemes(config)`.
- Theme mode is three-state: `RegularConfig.themeMode` (0=system, 1=light, 2=dark; see `RegularConfig.themeModeSystem/Light/Dark`). The legacy `RegularConfig.darkMode` bool is still written for downgrade compatibility and used to derive `themeMode` for old data (`true→2`, `false→1`).
- Dynamic color uses the `dynamic_color` package, gated by `RegularConfig.dynamicColor`. `ThemeResolver.resolveSchemes` requests the system core palette (Android) or accent color (desktop) and falls back to `ColorScheme.fromSeed` over `StaticsVar.themeList` on any failure. **Web has no dynamic-color implementation and always falls back to the seed color** (`kIsWeb` guard plus `MissingPluginException` catch for tests/unsupported platforms).

## Storage & data

- `lib/package_replacement/storage.dart` defines a **custom class also named `SharedPreferences`** (a wrapper, not the plugin). Web uses idb_shim IndexedDB (falling back to shared_preferences); everything else uses shared_preferences. Import this wrapper, not the plugin.
- **Backup contract:** only keys listed in `usedKeys` (`settingData`, `wordData`, `fsrsData`, `readingData`) are saved/restored. Any new top-level storage key MUST be added there or it is silently dropped from WebDAV backup and local export.
- Settings mutate the immutable `Config` via `AppData().config = AppData().config.copyWith(...)` then `Global.updateSetting()` (persists + `notifyListeners`), not via provider state. After restoring data, call `Global.conveySetting()` to rebuild `Config`.
- `AppData.basePath` is a `late final` assigned only when `!kIsWeb` — never read it on Web. TTS model and cache files use `path_provider`, separate from key-value storage.
- Word data is stored as one JSON string under `wordData` (`{"Words":[...],"Classes":{fileName:{className:[indexes]}}}`). `WordItem.id` is positional and omitted from `toMap`; import JSON uses a different schema (`{ClassName:[{arabic,chinese,explanation}]}`) transformed by `AppData.dataFormater`. WebDAV/local export is JSON keyed by `usedKeys` whose values are themselves JSON strings (double-encoded).
- `ReadingUnit.toMap(export: true)` intentionally omits the `corrects` answer key.

## Platform / Web compatibility

- Because Dart cannot conditionally import per platform at will, native-only code uses the **`fake_*.dart` shim pattern**: `import 'package:.../fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;`. The empties in `lib/package_replacement/` are load-bearing for Web — do not delete them (see its README).
- Existing fakes: `fake_dart_io.dart` (dart:io + idb types) and `fake_sherpa_onnx.dart` (native-only). `sherpa_onnx` must always be behind the conditional import. Other plugins (`window_manager`, workmanager/notifications, `mobile_scanner`, `flutter_webrtc`, `wakelock_plus`, `flutter_tts`, `dynamic_color`) are imported directly but guarded at runtime by `StaticsVar.isDesktop` / `kIsWeb` / `io.Platform.isAndroid` (or wrapped in a `MissingPluginException` catch).
- Adding a new native-only dependency requires either a new `fake_*.dart` + conditional import or a runtime `kIsWeb`/`io.Platform` guard, plus regenerating `lib/oss_licenses.dart`.

## Contributing constraints

- Commits must be **DCO signed off**: use `git commit -s`. CI `CheckSignOff.yml` rejects unsigned commits (skips merges/reverts/release/dep/ci commits). CONTRIBUTING.md also requires **GPG-verified** commits.
- Remotes: `origin` = `OctagonalStar/arabic_learning` (upstream, default branch `main`); `JYinherit` = a contributor fork.
- Do not commit API keys or TTS/AI credentials (called out in CONTRIBUTING.md).
- `docs/smoke-checklist.md` is the manual regression checklist to run after each phase and before release; `test/` cannot replace it.

## Other gotchas

- `CHANGELOG.md` is bundled as a **runtime asset** and shown in-app — keep it valid markdown.
- `NotoSansSC` is loaded **manually** via `FontLoader` in `services/global_state.dart`; its `pubspec.yaml` font block is commented out, so the declared family is a no-op.
- `flutter_statix/` is an empty, untracked leftover directory — ignore it.
- `BKSearch.init` early-returns once initialized, so importing a new word library in a running session does not rebuild the search index (`BKSearch.rebuild` is the supported path).
- `flutter_tts`, `flutter_webrtc` and `workmanager_android` still apply the Kotlin Gradle Plugin; Flutter warns that future versions will fail to build until they migrate to Built-in Kotlin (`android.builtInKotlin=false` currently opts out). `mobile_scanner` 7.4.2+ no longer applies KGP.
