package com.eyobaledger.apk

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eyobaledger.apk/telegram_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareImageToTelegram") {
                val filePath = call.argument<String>("filePath")
                val text = call.argument<String>("text")
                if (filePath != null) {
                    val success = shareImageToTelegram(filePath, text)
                    result.success(success)
                } else {
                    result.error("INVALID_PATH", "File path cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun shareImageToTelegram(filePath: String, text: String?): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri: Uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            val telegramPackages = listOf(
                "org.telegram.messenger",
                "org.telegram.messenger.web",
                "org.thunderdog.challegram"
            )

            var targetPackage: String? = null
            val pm = packageManager
            for (pkg in telegramPackages) {
                try {
                    pm.getPackageInfo(pkg, 0)
                    targetPackage = pkg
                    break
                } catch (_: Exception) {
                }
            }

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                if (!text.isNullOrEmpty()) {
                    putExtra(Intent.EXTRA_TEXT, text)
                }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                if (targetPackage != null) {
                    setPackage(targetPackage)
                }
            }

            if (targetPackage != null) {
                startActivity(shareIntent)
            } else {
                val chooser = Intent.createChooser(shareIntent, "Share to Telegram")
                chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                startActivity(chooser)
            }
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}

