package com.example.rakshak_ai

import android.app.ActivityManager
import android.content.Context
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
                else -> result.notImplemented()
            }
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
            egl.eglChooseConfig(display, intArrayOf(EGL10.EGL_RENDERABLE_TYPE, 4), configs, 1, numConfigs)
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
