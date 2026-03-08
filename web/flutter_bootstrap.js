{{flutter_js}}
{{flutter_build_config}}

const loading = document.createElement('div');
document.body.appendChild(loading);
loading.textContent = "正在加载中(Step 1)...\n若长时间无响应请尝试更换网络";
_flutter.loader.load({
    serviceWorkerSettings: {
        serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
        loading.textContent = "正在加载中(Step 2)...长时间无响应请尝试删除缓存或更换浏览器";
        const appRunner = await engineInitializer.initializeEngine({
            'fontFallbackBaseUrl': 'https://fonts.gstatic.cn/s/',
        });

        loading.textContent = "加载完成正在进入...";
        await appRunner.runApp();
    },
});