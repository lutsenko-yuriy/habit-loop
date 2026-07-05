package com.habitloop.habit_loop

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.habitloop.device_info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") {
                    result.success(mapOf("model" to Build.MODEL, "osVersion" to Build.VERSION.RELEASE))
                } else {
                    result.notImplemented()
                }
            }
    }
}
