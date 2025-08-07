package com.example.outlet_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import android.content.ContentResolver

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.chaimates/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.chaimates/native")
        .setMethodCallHandler { call, result ->
            if (call.method == "launchOrderAlert") {
                val orderJson = call.argument<String>("order")  // This must be a String, not HashMap!
                val intent = Intent(this, OrderAlertActivity::class.java)
                intent.putExtra("order", orderJson)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                startActivity(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val soundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${context.packageName}/raw/order_alert_1")

            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val channel = NotificationChannel(
                "orders_channel",
                "New Orders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new food orders"
                enableLights(true)
                enableVibration(true)
                setSound(soundUri, attributes)
            }

            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel(this)

        // // Handle the intent if the activity was launched from a notification
        // intent?.let {
        //     if (it.hasExtra("order")) {
        //         val orderJson = it.getStringExtra("order")
        //         if (orderJson != null) {
        //             // Process the order JSON as needed
        //             val order = JSONObject(orderJson)
        //             // Do something with the order
        //         }
        //     }
        // }
    }
}
