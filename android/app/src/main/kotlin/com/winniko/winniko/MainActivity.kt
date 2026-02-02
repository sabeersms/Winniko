package com.winniko.winniko

import android.os.Bundle
import com.google.android.gms.common.images.WebImage
import com.google.android.gms.security.ProviderInstaller
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.winniko.winniko/share"

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareFile") {
                val path = call.argument<String>("path")
                val text = call.argument<String>("text")
                val mimeType = call.argument<String>("mimeType")
                if (path != null && mimeType != null) {
                    try {
                        shareFile(path, text, mimeType)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SHARE_ERROR", e.message, e.stackTraceToString())
                    }
                } else {
                    result.error("INVALID_ARGS", "Path or mimeType cannot be null", null)
                }
            } else if (call.method == "shareImage") {
                 val path = call.argument<String>("path")
                 val text = call.argument<String>("text")
                 if (path != null) {
                     try {
                         shareFile(path, text, "image/png")
                         result.success(null)
                     } catch (e: Exception) {
                         result.error("SHARE_ERROR", e.message, e.stackTraceToString())
                     }
                 } else {
                     result.error("INVALID_ARGS", "Path cannot be null", null)
                 }
            } else if (call.method == "shareText") {
                val text = call.argument<String>("text")
                if (text != null) {
                    shareText(text)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "Text cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun shareText(text: String) {
        val intent = android.content.Intent(android.content.Intent.ACTION_SEND)
        intent.type = "text/plain"
        intent.putExtra(android.content.Intent.EXTRA_TEXT, text)
        startActivity(android.content.Intent.createChooser(intent, "Share"))
    }

    private fun shareFile(path: String, text: String?, mimeType: String) {
        try {
            val file = java.io.File(path)

            if (!file.exists()) {
                throw java.io.FileNotFoundException("File not found at path: $path")
            }

            val uri = androidx.core.content.FileProvider.getUriForFile(
                context, 
                "com.winniko.winniko.fileprovider",
                file
            )

            val intent = android.content.Intent(android.content.Intent.ACTION_SEND)
            intent.type = mimeType
            intent.putExtra(android.content.Intent.EXTRA_STREAM, uri)
            if (text != null) {
                intent.putExtra(android.content.Intent.EXTRA_TEXT, text)
            }
            intent.addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            
            val chooser = android.content.Intent.createChooser(intent, "Share")
            chooser.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
        } catch (e: Exception) {
            throw e
        }
    }
}
