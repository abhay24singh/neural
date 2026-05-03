package com.example.neural_gate

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.telephony.SmsManager
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.telecom.TelecomManager
import android.content.Context
import android.media.AudioManager
import android.view.KeyEvent
import android.hardware.camera2.CameraManager
import android.content.Intent
 

class MainActivity : FlutterActivity() {
    // Tera purana channel name (Isi ka use karenge)
    private val CHANNEL = "sos_app/sms"
    private var isFlashlightOn = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            
            // 📩 TERA PURANA SMS LOGIC
            if (call.method == "sendSMS") {
                val phone = call.argument<String>("phone")
                val message = call.argument<String>("message")
                if (phone != null && message != null) {
                    sendSMS(phone, message, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Phone or message is null", null)
                }
            } 
            // 🎵 NAYA MEDIA CONTROL LOGIC YAHAN HAI
            else if (call.method == "playPauseMedia") {
                playPauseMedia()
                result.success("Media toggled")
            } 
            else if (call.method == "pickCall") {
                pickCall(result)
            }
            else if (call.method == "toggleFlashlight") {
                toggleFlashlight(result)
            }
            else if (call.method == "triggerAssistant") {
                triggerAssistant(result)
            }
            else if (call.method == "volumeUp") {
                volumeUp(result)
            }
            else {
                result.notImplemented()
            }
        }
    }

    // 📩 TERA PURANA SMS FUNCTION (Safe hai)
    private fun sendSMS(phone: String, message: String, result: MethodChannel.Result) {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.SEND_SMS), 1)
            result.error("PERMISSION_DENIED", "SMS permission not granted", null)
            return
        }

        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phone, null, message, null, null)
            result.success("SMS sent successfully")
        } catch (e: Exception) {
            result.error("SEND_FAILED", e.message, null)
        }
    }

    // 🎵 NAYA FUNCTION: MEDIA PLAY/PAUSE KE LIYE
    private fun playPauseMedia() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // Virtual button press banaya
        val eventDown = KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        val eventUp = KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
        
        // System ko command bhej diya
        audioManager.dispatchMediaKeyEvent(eventDown)
        audioManager.dispatchMediaKeyEvent(eventUp)
    }
    // 📞 NAYA FUNCTION: CALL PICK KARNE KE LIYE
    private fun pickCall(result: MethodChannel.Result) {
        // Pehle permission check karenge
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ANSWER_PHONE_CALLS) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ANSWER_PHONE_CALLS), 2)
            result.error("PERMISSION_DENIED", "Call Answer permission not granted", null)
            return
        }

        try {
            val telecomManager = getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            // Agar Android version mein call pick karne ki suvidha hai aur phone baj raha hai
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                telecomManager.acceptRingingCall()
                result.success("Call successfully picked")
            } else {
                result.error("UNSUPPORTED_VERSION", "Android version is too old to pick calls", null)
            }
        } catch (e: Exception) {
            result.error("CALL_PICK_FAILED", e.message, null)
        }
    }
    // 🔦 FUNCTION: FLASHLIGHT ON/OFF
    private fun toggleFlashlight(result: MethodChannel.Result) {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList[0] // 0 usually back camera hota hai
            isFlashlightOn = !isFlashlightOn
            cameraManager.setTorchMode(cameraId, isFlashlightOn)
            result.success("Flashlight toggled")
        } catch (e: Exception) {
            result.error("FLASHLIGHT_FAILED", e.message, null)
        }
    }

    // 🎙️ FUNCTION: GOOGLE ASSISTANT TRIGGER
    private fun triggerAssistant(result: MethodChannel.Result) {
        try {
            // Android ko bolte hain ki voice command sunna shuru kare
            val intent = Intent(Intent.ACTION_VOICE_COMMAND)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            result.success("Assistant triggered")
        } catch (e: Exception) {
            result.error("ASSISTANT_FAILED", e.message, null)
        }
    }

    // 🔊 FUNCTION: VOLUME INCREASE
    private fun volumeUp(result: MethodChannel.Result) {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            // Volume badhao aur UI par slider bhi dikhao
            audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
            result.success("Volume increased")
        } catch (e: Exception) {
            result.error("VOLUME_FAILED", e.message, null)
        }
    }
}