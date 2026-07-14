package com.example.sampada

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Adds a `sampada/secure_screen` method channel so Flutter can mark the window
 * FLAG_SECURE while a sensitive screen (payments, chat, KYC capture) is on top.
 *
 * FLAG_SECURE is a property of the whole window, but sensitive screens can stack
 * (a payment screen opening a receipt, say), so enable/disable are ref-counted:
 * the flag is cleared only when the last sensitive screen has gone. This blocks
 * screenshots and screen recording and blanks the app-switcher thumbnail for
 * those screens.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "sampada/secure_screen"
    private var secureCount = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        secureCount++
                        applySecureFlag()
                        result.success(null)
                    }
                    "disable" -> {
                        if (secureCount > 0) secureCount--
                        applySecureFlag()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun applySecureFlag() {
        runOnUiThread {
            if (secureCount > 0) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A configuration change (rotation) recreates the activity and resets
        // window flags; re-apply if a secure screen was showing.
        applySecureFlag()
    }
}
