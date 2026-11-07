package com.jizhang.app

import android.app.Activity
import android.content.Context
import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var pickResult: MethodChannel.Result? = null

    companion object {
        private const val REQ_PICK_FILE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "jizhang/download")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveCsv", "saveFile" -> {
                        val name = call.argument<String>("name")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        if (name == null || bytes == null) {
                            result.error("ARG", "缺少 name/bytes 参数", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(saveToDownloads(name, bytes, mime))
                        } catch (e: Exception) {
                            result.error("IO", e.message, null)
                        }
                    }
                    "pickFile" -> {
                        pickResult = result
                        try {
                            // 用 */* 而不是具体 MIME：国产文件管理器对 csv/db
                            // 的 MIME 识别不统一，按 MIME 过滤会把文件全部隐藏。
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            startActivityForResult(intent, REQ_PICK_FILE)
                        } catch (e: Exception) {
                            pickResult = null
                            result.error("PICK", e.message, null)
                        }
                    }
                    "updateWidget" -> {
                        val expense = call.argument<Double>("expense") ?: 0.0
                        val income = call.argument<Double>("income") ?: 0.0
                        saveWidgetData(expense, income)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_FILE) return
        val result = pickResult
        pickResult = null
        if (resultCode != Activity.RESULT_OK) {
            result?.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result?.success(null)
            return
        }
        try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
            result?.success(bytes)
        } catch (e: Exception) {
            result?.error("IO", e.message, null)
        }
    }

    /** 保存桌面小组件展示的数据到 SharedPreferences */
    private fun saveWidgetData(expense: Double, income: Double) {
        val prefs = getSharedPreferences("jizhang_widget", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("expense", String.format("%.2f", expense))
            .putString("income", String.format("%.2f", income))
            .apply()
        // 通知小组件刷新
        val intent = Intent(this, JizhangWidgetProvider::class.java).apply {
            action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        }
        sendBroadcast(intent)
    }

    /** 通过 MediaStore 写入公共 Download 目录，Android 10+ 无需存储权限 */
    private fun saveToDownloads(name: String, bytes: ByteArray, mime: String): String {
        if (Build.VERSION.SDK_INT < 29) {
            throw IllegalStateException("需要 Android 10 及以上系统")
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, mime)
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

