package com.example.linqoraremote

import io.flutter.embedding.android.FlutterActivity

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "android.net.wifi.WifiManager"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> acquireMulticastLock(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun acquireMulticastLock(result: MethodChannel.Result) {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
        if (wifiManager != null) {
            val lock = wifiManager.createMulticastLock("multicast_lock")
            lock.acquire()
            result.success("Multicast lock acquired")
        } else {
            result.error("UNAVAILABLE", "WifiManager not available", null)
        }
    }
}
