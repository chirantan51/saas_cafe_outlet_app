package com.example.outlet_app

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.media.RingtoneManager
import android.os.Bundle
import android.os.PowerManager
import android.view.WindowManager
import android.widget.TextView
import com.example.outlet_app.R
import android.os.Build
import android.content.Intent

class OrderAlertActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
                or WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                or WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)

        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP or PowerManager.ON_AFTER_RELEASE,
            "OrderApp::OrderAlertWakeLock"
        )
        wakeLock.acquire(10 * 1000L) // Wake up for 10 seconds

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val keyguardLock = keyguardManager.newKeyguardLock("OrderApp::KeyguardLock")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        setContentView(R.layout.activity_order_alert)

        val textView = findViewById<TextView>(R.id.orderText)
        textView.text = "🚨 New Order Received!"

        val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val r = RingtoneManager.getRingtone(applicationContext, notification)
        r.play()
    }
}
