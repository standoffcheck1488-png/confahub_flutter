package com.eclips.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.net.VpnService
import android.os.ParcelFileDescriptor

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.eclips.app/vpn"
    private var vpnInterface: ParcelFileDescriptor? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> {
                    val name = call.argument<String>("name") ?: "Eclips"
                    try {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            result.error("NEED_PERMISSION", "Нужно разрешение VPN", null)
                            return@setMethodCallHandler
                        }
                        val builder = VpnService.Builder()
                        builder.setSession(name)
                        builder.addAddress("10.0.0.2", 32)
                        builder.addDnsServer("1.1.1.1")
                        builder.addRoute("0.0.0.0", 0)
                        builder.setMtu(1420)
                        vpnInterface = builder.establish()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VPN_ERROR", e.message, null)
                    }
                }
                "stopVpn" -> {
                    vpnInterface?.close()
                    vpnInterface = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
