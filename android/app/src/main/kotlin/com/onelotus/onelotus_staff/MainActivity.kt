package com.onelotus.onelotus_staff

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity dibutuhkan local_auth (biometrik, UM-05/UM-07).
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Layar data sensitif (foto rontgen): blokir screenshot & rekam layar, sembunyikan isi di daftar aplikasi.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "onelotus/secure").setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
