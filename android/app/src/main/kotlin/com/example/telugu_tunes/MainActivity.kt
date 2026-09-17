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
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.security.SecureRandom
import android.util.Base64
import org.json.JSONObject

class MainActivity : AudioServiceActivity() {
    private var notificationPermissionResult: MethodChannel.Result? = null
    private val notificationChannel = "telugu_tunes_chats"
    private val snapClientId = "f662d4a2-612e-441a-9a2c-0cee20b0c627"
    private val snapRedirect = "telugutunes://snap-login/oauth2"
    private var snapResult: MethodChannel.Result? = null
    private var snapState: String? = null
    private var snapVerifier: String? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "telugu_tunes/snap_login")
            .setMethodCallHandler { call, result ->
                if (call.method == "start") startSnapLogin(result)
                else result.notImplemented()
            }
    }

    private fun startSnapLogin(result: MethodChannel.Result) {
        if (snapResult != null) {
            result.error("snap_login_running", "Finish the current Snapchat sign-in first.", null)
            return
        }
        val verifier = randomUrlSafe(32)
        val challenge = Base64.encodeToString(
            MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(Charsets.US_ASCII)),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        val state = randomUrlSafe(24)
        val scope = "https://auth.snapchat.com/oauth2/api/user.display_name " +
            "https://auth.snapchat.com/oauth2/api/user.bitmoji.avatar"
        val uri = Uri.parse("https://accounts.snapchat.com/accounts/oauth2/auth")
            .buildUpon()
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("client_id", snapClientId)
            .appendQueryParameter("redirect_uri", snapRedirect)
            .appendQueryParameter("scope", scope)
            .appendQueryParameter("state", state)
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .build()
        snapResult = result
        snapState = state
        snapVerifier = verifier
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
        } catch (error: Exception) {
            clearSnapLogin()
            result.error("snap_browser_unavailable", "Could not open Snapchat sign-in.", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val uri = intent.data ?: return
        if (uri.scheme != "telugutunes" || uri.host != "snap-login" ||
            uri.path != "/oauth2") return
        val result = snapResult ?: return
        val verifier = snapVerifier
        if (uri.getQueryParameter("state") != snapState || verifier == null) {
            clearSnapLogin()
            result.error("snap_state_mismatch", "Snapchat sign-in could not be verified. Try again.", null)
            return
        }
        val code = uri.getQueryParameter("code")
        if (code.isNullOrBlank()) {
            clearSnapLogin()
            result.error("snap_access_denied",
                uri.getQueryParameter("error_description") ?: "Snapchat access was not granted.", null)
            return
        }
        Thread {
            try {
                val token = exchangeSnapCode(code, verifier)
                val avatarUrl = fetchSnapAvatar(token)
                runOnUiThread {
                    clearSnapLogin()
                    if (avatarUrl.isNullOrBlank()) result.error("no_bitmoji",
                        "Allow Bitmoji Avatar access in Snapchat to use your avatar.", null)
                    else result.success(avatarUrl)
                }
            } catch (error: Exception) {
                runOnUiThread {
                    clearSnapLogin()
                    result.error("snap_login_failed", error.message ?: "Snapchat sign-in failed.", null)
                }
            }
        }.start()
    }

    private fun clearSnapLogin() {
        snapResult = null
        snapState = null
        snapVerifier = null
    }

    private fun randomUrlSafe(size: Int): String {
        val bytes = ByteArray(size)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    }

    private fun exchangeSnapCode(code: String, verifier: String): String {
        val body = Uri.Builder()
            .appendQueryParameter("grant_type", "authorization_code")
            .appendQueryParameter("code", code)
            .appendQueryParameter("redirect_uri", snapRedirect)
            .appendQueryParameter("client_id", snapClientId)
            .appendQueryParameter("code_verifier", verifier)
            .build().encodedQuery ?: ""
        val connection = URL("https://accounts.snapchat.com/accounts/oauth2/token")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
            connection.doOutput = true
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val stream = if (connection.responseCode in 200..299) connection.inputStream
                else connection.errorStream
            val data = JSONObject(stream?.bufferedReader()?.use { it.readText() } ?: "{}")
            if (connection.responseCode !in 200..299)
                throw IllegalStateException(data.optString("error_description",
                    data.optString("error", "Snapchat token request failed.")))
            return data.optString("access_token").takeIf { it.isNotBlank() }
                ?: throw IllegalStateException("Snapchat did not return an access token.")
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchSnapAvatar(token: String): String? {
        val connection = URL("https://kit.snapchat.com/v1/me")
            .openConnection() as HttpURLConnection
        try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.doOutput = true
            connection.outputStream.use {
                it.write(JSONObject().put("query", "{me{bitmoji{avatar}}}")
                    .toString().toByteArray(Charsets.UTF_8))
            }
            val stream = if (connection.responseCode in 200..299) connection.inputStream
                else connection.errorStream
            val data = JSONObject(stream?.bufferedReader()?.use { it.readText() } ?: "{}")
            if (connection.responseCode !in 200..299)
                throw IllegalStateException("Snapchat avatar request failed (${connection.responseCode}).")
            return data.optJSONObject("data")?.optJSONObject("me")
                ?.optJSONObject("bitmoji")?.optString("avatar")
        } finally {
            connection.disconnect()
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
