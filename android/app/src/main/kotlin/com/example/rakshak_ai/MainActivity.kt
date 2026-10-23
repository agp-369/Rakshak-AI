package com.example.rakshak_ai

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.microedition.khronos.egl.EGL10
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.egl.EGLContext

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rakshak_ai/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasGpu" -> result.success(hasGpu())
                "isLowRamDevice" -> result.success(isLowRamDevice())
                "sendSms" -> {
                    val number = call.argument<String>("number")
                    val message = call.argument<String>("message")
                    if (number.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("ARGS", "number and message required", null)
                    } else {
                        try {
                            sendSms(number, message)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSms(number: String, message: String) {
        val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = smsManager.divideMessage(message)
        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(number, null, parts, null, null)
        } else {
            smsManager.sendTextMessage(number, null, message, null, null)
        }
    }

    private fun hasGpu(): Boolean {
        return try {
            val egl = EGLContext.getEGL() as EGL10
            val display = egl.eglGetDisplay(EGL10.EGL_DEFAULT_DISPLAY)
            val version = IntArray(2)
            egl.eglInitialize(display, version)
            val configs = arrayOfNulls<EGLConfig>(1)
            val numConfigs = IntArray(1)
            // EGL_OPENGL_ES3_BIT_KHR = 0x0040 — ES2 (0x4) exists on every device,
            // only report GPU-capable when ES3 configs are available (needed for vision inference).
            egl.eglChooseConfig(display, intArrayOf(EGL10.EGL_RENDERABLE_TYPE, 0x0040), configs, 1, numConfigs)
            egl.eglTerminate(display)
            numConfigs[0] > 0
        } catch (e: Exception) {
            false
        }
    }

    private fun isLowRamDevice(): Boolean {
        return try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            am.isLowRamDevice
        } catch (e: Exception) {
            false
        }
    }
}
