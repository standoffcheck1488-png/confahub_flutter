package com.eclips.app

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
                    "startVpn" -> {
                        val prepareIntent = VpnService.prepare(this)
                        if (prepareIntent != null) {
                            startActivityForResult(prepareIntent, 100)
                            result.error("NEED_PERMISSION", "Разреши VPN в следующем окне", null)
                            return@setMethodCallHandler
                        }
                        val i = Intent(this, EclipsVpnService::class.java)
                        i.action = "START"
                        i.putExtra("name", call.argument<String>("name") ?: "Eclips")
                        startService(i)
                        result.success(true)
                    }
                    "stopVpn" -> {
                        val i = Intent(this, EclipsVpnService::class.java)
                        i.action = "STOP"
                        startService(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

class EclipsVpnService : VpnService() {
    private var tunnel: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> startTunnel(intent.getStringExtra("name") ?: "Eclips")
            "STOP" -> stopTunnel()
        }
        return START_STICKY
    }

    private fun startTunnel(name: String) {
        try {
            val builder = Builder()
            builder.setSession(name)
            builder.setMtu(1420)
            builder.addAddress("10.8.0.2", 32)
            builder.addDnsServer("1.1.1.1")
            tunnel = builder.establish()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopTunnel() {
        try {
            tunnel?.close()
            tunnel = null
            stopSelf()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onRevoke() {
        stopTunnel()
        super.onRevoke()
    }
}
