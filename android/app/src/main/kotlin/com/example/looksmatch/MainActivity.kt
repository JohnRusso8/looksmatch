package com.russo.looksmatch

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Small in-house replacement for the app_settings plugin (dropped — its iOS
// side only ships a Swift Package Manager manifest with a broken dependency
// Flutter's own tooling can't satisfy, see Settings screen's "Change
// Language" row). iOS opens its own settings via url_launcher's
// app-settings: scheme; Android needs an actual Intent, hence this channel.
private const val APP_SETTINGS_CHANNEL = "com.russo.looksmatch/app_settings"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_SETTINGS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.fromParts("package", packageName, null)
                    }
                    startActivity(intent)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
