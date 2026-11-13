package com.example.eclips

import android.content.Intent
import android.net.VpnService
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
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
                    "startVpn" -> {
                        val configText = call.argument<String>("config") ?: ""
                        val name = call.argument<String>("name") ?: "eclips"
                        try {
                            val prepare = VpnService.prepare(this)
                            if (prepare != null) {
                                startActivityForResult(prepare, 100)
                                result.error("NEED_PERMISSION", "Разреши VPN и нажми ещё раз", null)
                                return@setMethodCallHandler
                            }
                            val i = Intent(this, EclipsVpnService::class.java)
                            i.action = "START"
                            i.putExtra("config", configText)
                            i.putExtra("name", name)
                            startService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("VPN_ERROR", e.message, null)
                        }
                    }
                    "stopVpn" -> {
                        val i = Intent(this, EclipsVpnService::class.java)
                        i.action = "STOP"
                        startService(i)
                        result.success(true)
                    }
                    "openConfig" -> {
                        val config = call.argument<String>("config") ?: ""
                        val send = Intent(Intent.ACTION_SEND)
                        send.type = "text/plain"
                        send.putExtra(Intent.EXTRA_TEXT, config)
                        startActivity(Intent.createChooser(send, "Открыть в WireGuard"))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

class AppTunnel(private val name: String) : Tunnel {
    override fun getName(): String = name
    override fun onStateChange(newState: Tunnel.State) {}
}

class EclipsVpnService : VpnService(), GoBackend.VpnService {
    private var backend: GoBackend? = null
    private var tunnel: AppTunnel? = null
    private var currentConfig: Config? = null

    override fun onCreate() {
        super.onCreate()
        backend = GoBackend(this)
    }

    override fun getBuilder(): Builder {
        val b = Builder()
        b.setSession("Eclips")
        val cfg = currentConfig
        if (cfg != null) {
            val iface = cfg.getInterface()
            if (iface.getMtu().isPresent) b.setMtu(iface.getMtu().asInt)
            for (addr in iface.getAddresses()) b.addAddress(addr.getAddress(), addr.getPrefix())
            for (dns in iface.getDnsServers()) b.addDnsServer(dns.getHostAddress())
            for (peer in cfg.getPeers()) {
                for (ip in peer.getAllowedIps()) b.addRoute(ip.getAddress(), ip.getPrefix())
            }
        } else {
            b.addAddress("10.8.0.2", 32)
            b.addDnsServer("1.1.1.1")
            b.addRoute("0.0.0.0", 0)
        }
        return b
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START" -> start(intent.getStringExtra("config") ?: "", intent.getStringExtra("name") ?: "eclips")
            "STOP" -> stop()
        }
        return START_STICKY
    }

    private fun start(configText: String, name: String) {
        try {
            val config = Config.parse(configText)
            currentConfig = config
            val t = AppTunnel(name)
            tunnel = t
            backend?.startTunnel(t, config, this, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stop() {
        try {
            tunnel?.let { backend?.stopTunnel(it) }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        tunnel = null
        currentConfig = null
        stopSelf()
    }

    override fun onRevoke() {
        stop()
        super.onRevoke()
    }
}
