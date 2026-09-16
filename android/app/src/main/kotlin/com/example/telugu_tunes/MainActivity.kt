package com.example.telugu_tunes

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : AudioServiceActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private val notificationChannel = "telugu_tunes_chats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "telugu_tunes/chat_privacy")
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecure") {
                    if (call.argument<Boolean>("enabled") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "telugu_tunes/chat_alerts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 ||
                            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            notificationPermissionResult = result
                            ActivityCompat.requestPermissions(this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS), 901)
                        }
                    }
                    "show" -> {
                        val title = call.argument<String>("title") ?: "New message"
                        val body = call.argument<String>("body") ?: "Open Telugu Tunes to read it"
                        val id = call.argument<Int>("id") ?: title.hashCode()
                        showChatNotification(id, title, body)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 901) {
            notificationPermissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            notificationPermissionResult = null
        }
    }

    private fun showChatNotification(id: Int, title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(notificationChannel,
                "Chat messages", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(this, id, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(this, notificationChannel) else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        manager.notify(id, notification)
    }
}
