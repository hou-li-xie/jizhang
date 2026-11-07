package com.jizhang.app

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/download")
            .setMethodCallHandler { call, result ->
                if (call.method == "saveCsv") {
                    val name = call.argument<String>("name")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (name == null || bytes == null) {
                        result.error("ARG", "缺少 name/bytes 参数", null)
                        return@setMethodCallHandler
                    }
                    try {
                        result.success(saveToDownloads(name, bytes))
                    } catch (e: Exception) {
                        result.error("IO", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** 通过 MediaStore 写入公共 Download 目录，Android 10+ 无需存储权限 */
    private fun saveToDownloads(name: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT < 29) {
            throw IllegalStateException("需要 Android 10 及以上系统")
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "text/csv")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val uri = contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
        ) ?: throw IllegalStateException("无法在 Download 创建文件")
        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw IllegalStateException("文件写入失败")
        return "Download/$name"
    }
}
