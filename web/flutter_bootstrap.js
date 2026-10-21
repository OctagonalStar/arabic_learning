{{flutter_js}}
{{flutter_build_config}}

// 启动屏淡出：首帧渲染后移除 #splash。
// 30s 兜底：仍未就绪则提示加载较慢，但不移除启动屏（此时引擎多半已死）。
const splash = document.getElementById('splash');
const splashHint = document.getElementById('splash-hint');

function updateHint(text) {
  if (splashHint) splashHint.textContent = text;
}

let splashDone = false;
function finishSplash() {
  if (splashDone || !splash) return;
  splashDone = true;
  splash.classList.add('is-done');
  setTimeout(function () {
    if (splash && splash.parentNode) splash.parentNode.removeChild(splash);
  }, 400); // 与 index.html 中 #splash 的 0.35s transition 对应
}

window.addEventListener('flutter-first-frame', finishSplash);
setTimeout(function () {
  if (!splashDone) updateHint('加载较慢，请耐心等待或检查网络');
}, 30000);

updateHint('正在加载中…');
_flutter.loader.load({
    serviceWorkerSettings: {
        serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
        updateHint('正在启动引擎…');
        const appRunner = await engineInitializer.initializeEngine({
            'fontFallbackBaseUrl': 'https://fonts.gstatic.cn/s/',
            // CanvasKit 自托管：从构建产物相对路径加载 WASM，避免 gstatic
            // 在国内网络下缓慢或被阻断。注意：flutter build web 的输出
            // 目录必须包含 canvaskit/ 子目录，否则 Web 端无法渲染。
            'canvasKitBaseUrl': 'canvaskit/',
        });

        updateHint('加载完成，正在进入…');
        await appRunner.runApp();
    },
});
