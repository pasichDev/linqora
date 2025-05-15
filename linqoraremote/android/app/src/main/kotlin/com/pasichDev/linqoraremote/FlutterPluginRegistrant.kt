package com.pasichDev.linqoraremote

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

object FlutterPluginRegistrant {
    fun registerWith(flutterEngine: FlutterEngine) {
        try {
            // Use Flutter's automatic plugin registration
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        } catch (e: Exception) {
            // Log error
            println("Error registering plugins: ${e.message}")
            e.printStackTrace()
        }
    }
}