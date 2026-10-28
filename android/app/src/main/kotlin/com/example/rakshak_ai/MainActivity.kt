package com.example.rakshak_ai

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.provider.ContactsContract
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import javax.microedition.khronos.egl.EGL10
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.egl.EGLContext

class MainActivity : FlutterActivity() {
    private val CHANNEL = "rakshak_ai/device"
    private val CONTACTS_PERMISSION_REQUEST_CODE = 201
    private var pendingPermissionResult: MethodChannel.Result? = null

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
                "hasContactsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_CONTACTS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestContactsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_CONTACTS),
                            CONTACTS_PERMISSION_REQUEST_CODE
                        )
                    }
                }
                "getContacts" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                        result.error("PERMISSION_DENIED", "READ_CONTACTS permission not granted", null)
                    } else {
                        try {
                            val list = fetchContacts()
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("FETCH_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CONTACTS_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun fetchContacts(): List<Map<String, String>> {
        val contacts = mutableListOf<Map<String, String>>()
        val seen = mutableSetOf<String>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.CONTACT_ID,
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER
        )
        val cursor = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} COLLATE NOCASE ASC"
        )
        cursor?.use {
            val idCol = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.CONTACT_ID)
            val nameCol = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numCol = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

            while (it.moveToNext()) {
                val id = if (idCol >= 0) it.getString(idCol) ?: "" else ""
                val name = if (nameCol >= 0) it.getString(nameCol) ?: "" else ""
                val number = if (numCol >= 0) it.getString(numCol) ?: "" else ""
                val cleanNumber = number.replace("[\\s\\-\\(\\)]".toRegex(), "")
                if (cleanNumber.isNotBlank() && name.isNotBlank()) {
                    val key = "$name|$cleanNumber"
                    if (!seen.contains(key)) {
                        seen.add(key)
                        contacts.add(mapOf(
                            "id" to id,
                            "name" to name.trim(),
                            "phone" to cleanNumber
                        ))
                    }
                }
            }
        }
        return contacts
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
