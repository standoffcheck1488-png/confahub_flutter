import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import 'dart:math';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const ConfahubApp());
}

class ConfahubApp extends StatelessWidget {
  const ConfahubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Confahub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// Модель WireGuard сервера
class WgServer {
  String id;
  String name;
  String privateKey;
  String publicKey;
  String endpoint;
  String allowedIps;
  String dns;
  String flag;
  bool isConnected;

  WgServer({
    required this.id,
    required this.name,
    required this.privateKey,
    required this.publicKey,
    required this.endpoint,
    this.allowedIps = '0.0.0.0/0',
    this.dns = '1.1.1.1',
    this.flag = '🌍',
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'privateKey': privateKey,
        'publicKey': publicKey,
        'endpoint': endpoint,
        'allowedIps': allowedIps,
        'dns': dns,
        'flag': flag,
      };

  factory WgServer.fromJson(Map<String, dynamic> json) => WgServer(
        id: json['id'],
        name: json['name'],
        privateKey: json['privateKey'],
        publicKey: json['publicKey'],
        endpoint: json['endpoint'],
        allowedIps: json['allowedIps'] ?? '0.0.0.0/0',
        dns: json['dns'] ?? '1.1.1.1',
        flag: json['flag'] ?? '🌍',
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  List<WgServer> servers = [];
  int? connectedServerId;
  bool isConnecting = false;
  final WireguardFlutter _wireguard = WireguardFlutter();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadServers();
    _initWireguard();
  }

  Future<void> _initWireguard() async {
    await _wireguard.init();
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = prefs.getStringList('servers') ?? [];
    setState(() {
      servers = serversJson
          .map((e) => WgServer.fromJson(jsonDecode(e)))
          .toList();
    });
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final serversJson = servers.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('servers', serversJson);
  }

  Future<void> _connectToServer(WgServer server) async {
    setState(() {
      isConnecting = true;
    });

    try {
      final config = '''
[Interface]
PrivateKey = ${server.privateKey}
Address = 10.0.0.2/32
DNS = ${server.dns}

[Peer]
PublicKey = ${server.publicKey}
Endpoint = ${server.endpoint}
AllowedIPs = ${server.allowedIps}
PersistentKeepalive = 25
''';

      await _wireguard.startVpn(
        serverName: server.name,
        wgQuickConfig: config,
        providerBundleIdentifier: 'com.confahub.app',
      );

      setState(() {
        connectedServerId = server.id;
        isConnecting = false;
        servers.forEach((s) => s.isConnected = (s.id == server.id));
      });
    } catch (e) {
      setState(() {
        isConnecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await _wireguard.stopVpn();
    setState(() {
      connectedServerId = null;
      isConnecting = false;
      servers.forEach((s) => s.isConnected = false);
    });
  }

  void _showAddServerSheet() {
    final nameController = TextEditingController();
    final privateKeyController = TextEditingController();
    final publicKeyController = TextEditingController();
    final endpointController = TextEditingController();
    final dnsController = TextEditingController(text: '1.1.1.1');
    String selectedFlag = '🌍';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Добавить WireGuard сервер',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildGlassTextField(nameController, 'Название (например: Германия #1)'),
                    const SizedBox(height: 12),
                    _buildGlassTextField(privateKeyController, 'Private Key (начинается с [ или буквы)'),
                    const SizedBox(height: 12),
                    _buildGlassTextField(publicKeyController, 'Public Key сервера'),
                    const SizedBox(height: 12),
                    _buildGlassTextField(endpointController, 'Endpoint (например: 1.2.3.4:51820)'),
                    const SizedBox(height: 12),
                    _buildGlassTextField(dnsController, 'DNS (например: 1.1.1.1)'),
                    const SizedBox(height: 16),
                    const Text('Флаг страны', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['🇩🇪', '🇳🇱', '🇺🇸', '🇯🇵', '🇸🇬', '🇬🇧', '🇫🇷', '🇷🇺', '🌍'].map((flag) {
                        return GestureDetector(
                          onTap: () => setModalState(() => selectedFlag = flag),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedFlag == flag ? const Color(0xFF7C3AED) : Colors.white.withOpacity(0.1),
                              border: Border.all(
                                color: selectedFlag == flag ? const Color(0xFF7C3AED) : Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Center(child: Text(flag, style: const TextStyle(fontSize: 22))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          if (nameController.text.isNotEmpty &&
                              privateKeyController.text.isNotEmpty &&
                              publicKeyController.text.isNotEmpty &&
                              endpointController.text.isNotEmpty) {
                            final newServer = WgServer(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              name: nameController.text,
                              privateKey: privateKeyController.text,
                              publicKey: publicKeyController.text,
                              endpoint: endpointController.text,
                              dns: dnsController.text,
                              flag: selectedFlag,
                            );
                            setState(() {
                              servers.add(newServer);
                            });
                            _saveServers();
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Добавить сервер', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassTextField(TextEditingController controller, String hint) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedServer = servers.firstWhere((s) => s.id == connectedServerId, orElse: () => WgServer(id: '', name: 'Не подключено', privateKey: '', publicKey: '', endpoint: ''));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Confahub', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 28), onPressed: _showAddServerSheet),
        ],
      ),
      body: Stack(
        children: [
          // Фоновые блобы
          Positioned.fill(
            child: Stack(
              children: [
                Positioned(top: -100, right: -100, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFF7C3AED).withOpacity(0.4), const Color(0xFF7C3AED).withOpacity(0)])))),
                Positioned(bottom: 100, left: -80, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFF06B6D4).withOpacity(0.3), const Color(0xFF06B6D4).withOpacity(0)])))),
              ],
            ),
          ),

          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),

              // Кнопка подключения
              SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (connectedServerId != null) {
                            _disconnect();
                          } else if (servers.isNotEmpty) {
                            _connectToServer(servers.first);
                          }
                        },
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: connectedServerId != null
                                ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF10B981), Color(0xFF059669)])
                                : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                            boxShadow: [
                              BoxShadow(
                                color: (connectedServerId != null ? const Color(0xFF10B981) : const Color(0xFF7C3AED)).withOpacity(0.5),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isConnecting)
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 160 + (_pulseController.value * 30),
                                      height: 160 + (_pulseController.value * 30),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(1 - _pulseController.value), width: 2),
                                      ),
                                    );
                                  },
                                ),
                              Icon(connectedServerId != null ? Icons.check : Icons.power_settings_new, size: 60, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(connectedServer.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(connectedServerId != null ? 'Защищено' : 'Нажмите для подключения', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Серверы', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                      Text('${servers.length} доступно', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5))),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final server = servers[index];
                      final isConnected = server.id == connectedServerId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GestureDetector(
                          onTap: () {
                            if (isConnected) {
                              _disconnect();
                            } else {
                              _connectToServer(server);
                            }
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white.withOpacity(isConnected ? 0.15 : 0.08),
                                  border: Border.all(color: isConnected ? const Color(0xFF10B981).withOpacity(0.5) : Colors.white.withOpacity(0.15), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                                    if (isConnected) BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 30, spreadRadius: 2),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)), child: Center(child: Text(server.flag, style: const TextStyle(fontSize: 24)))),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(server.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                                          const SizedBox(height: 4),
                                          Text(server.endpoint, style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6))),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isConnected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.3),
                                        boxShadow: isConnected ? [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.6), blurRadius: 8, spreadRadius: 2)] : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: servers.length,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wireguard.stopVpn();
    super.dispose();
  }
}
