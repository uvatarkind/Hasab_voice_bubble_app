package com.hasabkey.bubble

import android.content.Context
import android.content.Intent
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class HasabkeyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private var context: Context? = null

    companion object {
        private const val TAG = "HasabkeyPlugin"
        private const val CHANNEL = "com.hasabkey.bubble/text"
        private const val ACTION_INSERT = "com.hasabkey.bubble.INSERT_TEXT"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler(this)
        Log.d(TAG, "Plugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "insertText" -> {
                val text = call.argument<String>("text") ?: ""
                handleInsertText(text, isFinal = true)
                result.success(null)
            }
            "insertInterim" -> {
                val text = call.argument<String>("text") ?: ""
                handleInsertText(text, isFinal = false)
                result.success(null)
            }
            "isAccessibilityEnabled" -> {
                val ctx = context ?: run {
                    result.success(false)
                    return
                }
                val enabledServices = Settings.Secure.getString(
                    ctx.contentResolver,
                    Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                ) ?: ""
                val pkg = ctx.packageName
                val enabled = enabledServices.contains("$pkg/.TextInsertionAccessibilityService")
                    || enabledServices.contains("$pkg/com.hasabkey.bubble.TextInsertionAccessibilityService")
                    || enabledServices.contains("TextInsertionAccessibilityService")
                result.success(enabled)
            }
            "openAccessibilitySettings" -> {
                val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context?.startActivity(intent)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleInsertText(text: String, isFinal: Boolean) {
        Log.d(TAG, "handleInsertText: text=$text, isFinal=$isFinal")

        // Try 1: Static call to accessibility service instance
        val instance = TextInsertionAccessibilityService.getInstance()
        if (instance != null) {
            val inserted = TextInsertionAccessibilityService.insertText(text, isFinal)
            if (inserted) {
                Log.d(TAG, "Static instance inserted text directly")
                return
            }
            Log.d(TAG, "Static instance exists but no focused field")
        }

        // Try 2: Send broadcast (in case static ref is stale)
        val ctx = context
        if (ctx != null) {
            Log.d(TAG, "Sending broadcast")
            val intent = Intent(ACTION_INSERT).apply {
                setPackage(ctx.packageName)
                putExtra("text", text)
                putExtra("isFinal", isFinal)
            }
            ctx.sendBroadcast(intent)
        }

        // Try 3: Write pending file + schedule checks
        // The accessibility service will pick this up when a text field gets focus
        if (isFinal) {
            writePendingFile(text)
            instance?.schedulePendingChecks()
        }
    }

    private fun writePendingFile(text: String) {
        try {
            val ctx = context ?: return
            val file = File(ctx.filesDir, "pending_insert.txt")
            file.writeText(text)
            Log.d(TAG, "Pending file written")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write pending file", e)
        }
    }
}
