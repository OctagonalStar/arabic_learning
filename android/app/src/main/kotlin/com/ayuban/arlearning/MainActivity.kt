package com.ayuban.arlearning

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "app_update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 是否已允许「安装未知来源应用」
                    "canRequestPackageInstalls" -> result.success(canRequestPackageInstalls())
                    // 返回设备支持的 ABI 列表（最优在前），供 Dart 侧与按 ABI 拆分的 APK 资产名匹配
                    "getSupportedAbis" -> result.success(Build.SUPPORTED_ABIS.toList())
                    // 跳转到系统设置申请该权限；返回 boolean 表示是否真的跳转成功
                    "requestInstallPermission" -> result.success(requestInstallPermission())
                    // 调起系统安装器
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        result.success(installApk(path))
                    }
                    // 读取 APK 的包名 / 版本号，供 Dart 侧校验
                    "verifyApk" -> {
                        val path = call.argument<String>("path")
                        result.success(verifyApk(path))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Android O 以下无需「安装未知来源」权限。 */
    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    /**
     * 打开「安装未知来源应用」设置页。
     *
     * 返回是否真的成功跳转：个别 ROM 没有该设置页（如部分精简定制系统），
     * 此时 startActivity 会抛异常，返回 false 让 Dart 侧能提示用户而不是毫无反馈。
     */
    private fun requestInstallPermission(): Boolean {
        // Android O 以下无需该权限。注意 Dart 侧只有在 canRequestPackageInstalls()
        // 为 false 时才会调用本方法，而旧系统该方法恒为 true，故这里不会真正被触发；
        // 返回 false 表示「没有跳转任何设置页」，与方法的语义保持一致。
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** 通过 FileProvider 以 ACTION_VIEW 调起安装器。 */
    private fun installApk(path: String?): Boolean {
        if (path.isNullOrEmpty()) return false
        return try {
            val file = File(path)
            if (!file.exists()) return false
            val uri: Uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addCategory(Intent.CATEGORY_DEFAULT)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 解析 APK 元信息，返回 packageName / versionCode / versionName 以及
     * 当前应用自身的 versionCode，交给 Dart 侧判断包名与版本是否合法。
     */
    @Suppress("DEPRECATION")
    private fun verifyApk(path: String?): Map<String, Any>? {
        if (path.isNullOrEmpty()) return null
        return try {
            val archive = packageManager.getPackageArchiveInfo(path, 0) ?: return null
            val self = packageManager.getPackageInfo(packageName, 0)
            val archiveCode: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                archive.longVersionCode
            } else {
                archive.versionCode.toLong()
            }
            val selfCode: Long = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                self.longVersionCode
            } else {
                self.versionCode.toLong()
            }
            mapOf(
                "packageName" to (archive.packageName ?: ""),
                "versionCode" to archiveCode,
                "versionName" to (archive.versionName ?: ""),
                "currentVersionCode" to selfCode
            )
        } catch (_: Exception) {
            null
        }
    }
}
