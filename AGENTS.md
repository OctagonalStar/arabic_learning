# AGENTS.md

Cross-platform Flutter/Dart app for learning Arabic vocabulary (AGPL-3.0). Targets **Android / Windows / Linux / macOS / Web**; iOS was dropped in v0.1.12. UI and comments are Chinese.

## Commands

```bash
flutter pub get
flutter run
flutter analyze          # analysis_options excludes build/ and all platform dirs
```

- **There are no working tests.** `test/widget_test.dart` is the untouched Flutter counter template: it pumps `MyApp` without the `Global` provider and asserts on a counter that does not exist, so `flutter test` fails (`ProviderNotFoundException`). No CI job runs tests or `flutter analyze` — all workflows only run `pub get` + `flutter build`.
- **Flutter version is split and deliberate:** Android CI is pinned to **3.44.0**; Windows/macOS/Web use **3.47.0**. Flutter 3.47.0's AGP bump breaks many Android plugins. `pubspec.yaml` requires Dart SDK `^3.11.0`.
- Manual generators (no wrappers/scripts): `flutter_launcher_icons` for app icons, and `dart_pubspec_licenses` for `lib/oss_licenses.dart`. Regenerate `oss_licenses.dart` by hand after changing dependencies; never edit that generated file.

## Architecture (non-obvious)

- `lib/main.dart` — `main()` sets up logging, orientation, Android `workmanager` (30-min task via `funcs/noification.dart`), and desktop `window_manager`, then `runApp`s a **single `ChangeNotifierProvider<Global>`**. All heavy init is deferred into a `FutureBuilder` on `Global.init()` inside `MyApp`.
- **Only one app-wide provider exists: `Global`** (`lib/vars/global.dart`). Everything else is a hand-rolled singleton (`AppData()`, `FSRS()` in `funcs/fsrs_func.dart`, static `BKSearch` in `funcs/utili.dart`) or a locally-scoped `ChangeNotifier` created inside a `MaterialPageRoute` (e.g. `PKServer`, `SingleSelectionNotifier`). `context.read<Global>()` is often used just to log.
- **Navigation is not route-based.** Root is `MaterialApp.home` + a responsive `PageView` of 4 tabs (`Home/Learning/Test/Setting`), switched by `PageController`. No named routes, no router package. Detail screens live in `lib/sub_pages_builder/{setting,learning,test}_pages/` and are opened with `Navigator.push(MaterialPageRoute(...))`.
- `lib/funcs/ui.dart` is the shared **widget kit** (custom `Button`, `TextContainer`, question widgets, `ClassSelectPage`) plus dialog/selection helpers — reuse it instead of raw Material widgets. `lib/vars/` holds immutable models/constants only; `lib/funcs/` holds logic.
- `lib/main.dart` writes `AppData().isWideScreen` as a **build side effect**; layouts elsewhere depend on this global flag.

## Storage & data

- `lib/package_replacement/storage.dart` defines a **custom class also named `SharedPreferences`** (a wrapper, not the plugin). Web uses idb_shim IndexedDB (falling back to shared_preferences); everything else uses shared_preferences. Import this wrapper, not the plugin.
- **Backup contract:** only keys listed in `usedKeys` (`settingData`, `wordData`, `fsrsData`, `readingData`) are saved/restored. Any new top-level storage key MUST be added there or it is silently dropped from WebDAV backup and local export.
- Settings mutate the immutable `Config` via `AppData().config = AppData().config.copyWith(...)` then `Global.updateSetting()` (persists + `notifyListeners`), not via provider state. After restoring data, call `Global.conveySetting()` to rebuild `Config`.
- `AppData.basePath` is a `late final` assigned only when `!kIsWeb` — never read it on Web. TTS model and cache files use `path_provider`, separate from key-value storage.
- Word data is stored as one JSON string under `wordData` (`{"Words":[...],"Classes":{fileName:{className:[indexes]}}}`). `WordItem.id` is positional and omitted from `toMap`; import JSON uses a different schema (`{ClassName:[{arabic,chinese,explanation}]}`) transformed by `AppData.dataFormater`. WebDAV/local export is JSON keyed by `usedKeys` whose values are themselves JSON strings (double-encoded).
- `ReadingUnit.toMap(export: true)` intentionally omits the `corrects` answer key.

## Platform / Web compatibility

- Because Dart cannot conditionally import per platform at will, native-only code uses the **`fake_*.dart` shim pattern**: `import 'package:.../fake_dart_io.dart' if (dart.library.io) 'dart:io' as io;`. The empties in `lib/package_replacement/` are load-bearing for Web — do not delete them (see its README).
- Existing fakes: `fake_dart_io.dart` (dart:io + idb types) and `fake_sherpa_onnx.dart` (native-only). `sherpa_onnx` must always be behind the conditional import. Other plugins (`window_manager`, workmanager/notifications, `mobile_scanner`, `flutter_webrtc`, `wakelock_plus`, `flutter_tts`) are imported directly but guarded at runtime by `StaticsVar.isDesktop` / `kIsWeb` / `io.Platform.isAndroid`.
- Adding a new native-only dependency requires either a new `fake_*.dart` + conditional import or a runtime `kIsWeb`/`io.Platform` guard.

## Contributing constraints

- Commits must be **DCO signed off**: use `git commit -s`. CI `CheckSignOff.yml` rejects unsigned commits (skips merges/reverts/release/dep/ci commits). CONTRIBUTING.md also requires **GPG-verified** commits.
- Remotes: `origin` = `OctagonalStar/arabic_learning` (upstream, default branch `main`); `JYinherit` = a contributor fork.
- Do not commit API keys or TTS/AI credentials (called out in CONTRIBUTING.md).

## Other gotchas

- `CHANGELOG.md` is bundled as a **runtime asset** and shown in-app — keep it valid markdown.
- `NotoSansSC` is loaded **manually** via `FontLoader` in `vars/global.dart`; its `pubspec.yaml` font block is commented out, so the declared family is a no-op.
- `flutter_statix/` is an empty, untracked leftover directory — ignore it.
- `BKSearch.init` early-returns once initialized, so importing a new word library in a running session does not rebuild the search index.
