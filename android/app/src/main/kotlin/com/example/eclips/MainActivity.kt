package com.example.eclips

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eclips.app/vpn"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openConfig" -> {
                        val config = call.argument<String>("config") ?: ""
                        val send = Intent(Intent.ACTION_SEND)
                        send.type = "text/plain"
                        send.putExtra(Intent.EXTRA_TEXT, config)
                        startActivity(Intent.createChooser(send, "Открыть в WireGuard"))
                        result.success(true)
                    }
                    "stopVpn" -> {
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
