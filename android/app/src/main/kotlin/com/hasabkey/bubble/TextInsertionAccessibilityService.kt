package com.hasabkey.voicebubble

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.io.File

class TextInsertionAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "HasabkeyA11y"
        private const val ACTION_INSERT = "com.hasabkey.voicebubble.INSERT_TEXT"
        private const val PENDING_FILE = "pending_insert.txt"

        private var instance: TextInsertionAccessibilityService? = null
        private var lastInterimLength: Int = 0

        fun getInstance(): TextInsertionAccessibilityService? = instance

        fun insertText(text: String, isFinal: Boolean): Boolean {
            return instance?.performTextInsertion(text, isFinal) ?: false
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var pendingCheckRunnable: Runnable? = null

    private val insertReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val text = intent?.getStringExtra("text") ?: return
            val isFinal = intent.getBooleanExtra("isFinal", true)
            Log.d(TAG, "Broadcast received: text=$text, isFinal=$isFinal")
            if (!performTextInsertion(text, isFinal)) {
                // Insertion failed (no focused field), ensure pending file exists
                if (isFinal) writePendingFile(text)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Service connected")

        val filter = IntentFilter(ACTION_INSERT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(insertReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(insertReceiver, filter)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_FOCUSED,
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                checkPendingFile()
            }
        }
    }

    override fun onInterrupt() {}

    /**
     * Schedule repeated checks for the pending file.
     * Called after the file is written to handle the case where
     * the text field is already focused or gains focus shortly after.
     */
    fun schedulePendingChecks() {
        pendingCheckRunnable?.let { handler.removeCallbacks(it) }

        var attempts = 0
        val runnable = object : Runnable {
            override fun run() {
                val file = File(filesDir, PENDING_FILE)
                if (!file.exists()) return // Already consumed

                if (checkPendingFile()) return // Success

                attempts++
                if (attempts < 10) {
                    handler.postDelayed(this, 500) // Retry every 500ms for 5 seconds
                }
            }
        }
        pendingCheckRunnable = runnable
        // Start checking after a short delay (give overlay time to shrink)
        handler.postDelayed(runnable, 300)
    }

    private fun writePendingFile(text: String) {
        try {
            val file = File(filesDir, PENDING_FILE)
            file.writeText(text)
            Log.d(TAG, "Pending file written from service")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write pending file", e)
        }
    }

    private fun checkPendingFile(): Boolean {
        try {
            val file = File(filesDir, PENDING_FILE)
            if (!file.exists()) return false

            val text = file.readText().trim()
            if (text.isEmpty()) {
                file.delete()
                return false
            }

            Log.d(TAG, "Pending file found (${text.length} chars), attempting insertion")
            if (performTextInsertion(text, isFinal = true)) {
                file.delete()
                Log.d(TAG, "Pending file consumed successfully")
                return true
            }
            Log.d(TAG, "No focused editable field yet, file kept")
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking pending file", e)
            return false
        }
    }

    /**
     * Returns true if text was actually inserted into a focused editable field.
     */
    private fun performTextInsertion(text: String, isFinal: Boolean): Boolean {
        val rootNode = rootInActiveWindow ?: return false
        val focusedNode = rootNode.findFocus(AccessibilityNodeInfo.FOCUS_INPUT) ?: run {
            rootNode.recycle()
            return false
        }

        if (!focusedNode.isEditable) {
            focusedNode.recycle()
            rootNode.recycle()
            return false
        }

        val existingText = focusedNode.text?.toString() ?: ""

        val updatedText = if (isFinal) {
            val textWithoutInterim = if (lastInterimLength > 0 && existingText.length >= lastInterimLength) {
                existingText.substring(0, existingText.length - lastInterimLength)
            } else {
                existingText
            }

            val finalToAppend = if (textWithoutInterim.isNotEmpty() && !textWithoutInterim.endsWith(" ")) {
                " $text"
            } else {
                text
            }
            lastInterimLength = 0
            textWithoutInterim + finalToAppend
        } else {
            val textWithoutOldInterim = if (lastInterimLength > 0 && existingText.length >= lastInterimLength) {
                existingText.substring(0, existingText.length - lastInterimLength)
            } else {
                existingText
            }

            val interimToAppend = if (textWithoutOldInterim.isNotEmpty() && !textWithoutOldInterim.endsWith(" ")) {
                " $text"
            } else {
                text
            }
            lastInterimLength = interimToAppend.length
            textWithoutOldInterim + interimToAppend
        }

        val args = Bundle().apply {
            putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, updatedText)
        }
        focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)

        val selectionArgs = Bundle().apply {
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT, updatedText.length)
            putInt(AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT, updatedText.length)
        }
        focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, selectionArgs)

        // Also delete pending file if it exists (prevent double insertion from other paths)
        try {
            val file = File(filesDir, PENDING_FILE)
            if (file.exists()) file.delete()
        } catch (_: Exception) {}

        Log.d(TAG, "Text inserted successfully: $updatedText")

        focusedNode.recycle()
        rootNode.recycle()
        return true
    }

    override fun onDestroy() {
        pendingCheckRunnable?.let { handler.removeCallbacks(it) }
        try {
            unregisterReceiver(insertReceiver)
        } catch (_: Exception) {}
        instance = null
        super.onDestroy()
    }
}
