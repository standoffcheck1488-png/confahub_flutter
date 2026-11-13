import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'dart:convert';

class WgServer {
  String id;
  String name;
  String privateKey;
  String publicKey;
  String endpoint;
  String allowedIps;
  String dns;
  String flag;
  String address;
  String mtu;

  WgServer({
    required this.id,
    required this.name,
    required this.privateKey,
    required this.publicKey,
    required this.endpoint,
    this.allowedIps = '0.0.0.0/0',
    this.dns = '1.1.1.1',
    this.flag = '🌍',
    this.address = '10.0.0.2/32',
    this.mtu = '1280',
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
        'address': address,
        'mtu': mtu,
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
        address: json['address'] ?? '10.0.0.2/32',
        mtu: json['mtu'] ?? '1280',
      );
}

class WgConfigParser {
  static Map<String, String> parse(String config) {
    final result = <String, String>{};
    String? section;
    for (var line in config.split('\n')) {
      line = line.trim();
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).toLowerCase();
      } else if (line.contains('=') && section != null) {
        final idx = line.indexOf('=');
        final key = line.substring(0, idx).trim().toLowerCase();
        final value = line.substring(idx + 1).trim();
        result['${section}.${key}'] = value;
      }
    }
    return result;
  }

  static WgServer fromConfig(String config,
      {String name = 'Eclips', String flag = '🌍'}) {
    final p = parse(config);
    return WgServer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      privateKey: p['interface.privatekey'] ?? '',
      publicKey: p['peer.publickey'] ?? '',
      endpoint: p['peer.endpoint'] ?? '',
      allowedIps: p['peer.allowedips'] ?? '0.0.0.0/0',
      dns: p['interface.dns'] ?? '1.1.1.1',
      address: p['interface.address'] ?? '10.0.0.2/32',
      mtu: p['interface.mtu'] ?? '1280',
      flag: flag,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  List<WgServer> servers = [];
  String? connectedServerId;
  bool isConnecting = false;
  static const MethodChannel _vpnChannel = MethodChannel('com.eclips.app/vpn');

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadServers();
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getStringList('servers') ?? [];
    setState(() {
      servers = json.map((e) => WgServer.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'servers', servers.map((e) => jsonEncode(e.toJson())).toList());
  }

  Future<void> _connectToServer(WgServer server) async {
    setState(() => isConnecting = true);
    try {
      final config = '''
[Interface]
PrivateKey = ${server.privateKey}
Address = ${server.address}
DNS = ${server.dns}
MTU = ${server.mtu}

[Peer]
PublicKey = ${server.publicKey}
Endpoint = ${server.endpoint}
AllowedIPs = ${server.allowedIps}
PersistentKeepalive = 25
''';
      await _vpnChannel.invokeMethod('startVpn', {
        'name': server.name,
        'config': config,
      });
      setState(() {
        connectedServerId = server.id;
        isConnecting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Туннель поднят 🌑 трафик идёт через сервер')),
        );
      }
    } on PlatformException catch (e) {
      setState(() => isConnecting = false);
      if (mounted) {
        if (e.code == 'NEED_PERMISSION') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Разреши VPN в окне Android и нажми ещё раз')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${e.message}')),
          );
        }
      }
    } catch (e) {
      setState(() => isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _vpnChannel.invokeMethod('stopVpn');
    } catch (e) {}
    setState(() {
      connectedServerId = null;
      isConnecting = false;
    });
  }

  void _addServer(WgServer server) {
    setState(() => servers.add(server));
    _saveServers();
    Navigator.pop(context);
  }

  void _deleteServer(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Удалить?', style: TextStyle(color: Colors.white)),
        content: Text('Удалить ${servers[index].name}?',
            style: TextStyle(color: Colors.white.withOpacity(0.7))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () {
                setState(() => servers.removeAt(index));
                _saveServers();
                Navigator.pop(context);
              },
              child: const Text('Удалить',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24).withOpacity(0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.2))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                const Text('Импорт сервера',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 20),
                _importOption(Icons.text_fields, 'Вставить конфиг',
                    'Скопируй текст', Colors.blue, () {
                  Navigator.pop(context);
                  _showPasteConfigSheet();
                }),
                const SizedBox(height: 12),
                _importOption(Icons.link, 'По ссылке', 'URL файла .conf',
                    Colors.green, () {
                  Navigator.pop(context);
                  _showImportFromUrlSheet();
                }),
                const SizedBox(height: 12),
                _importOption(Icons.edit, 'Вручную', 'Заполнить поля',
                    Colors.purple, () {
                  Navigator.pop(context);
                  _showManualInputSheet();
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _importOption(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withOpacity(0.2)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  void _showPasteConfigSheet() {
    final configController = TextEditingController();
    final nameController = TextEditingController(text: 'Eclips');
    String flag = '🌍';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24).withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Вставить конфиг',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 16),
                  _glassField(nameController, 'Название'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: TextField(
                        controller: configController,
                        maxLines: 10,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText:
                              '[Interface]\nPrivateKey = ...\n\n[Peer]\nPublicKey = ...\nEndpoint = ...',
                          hintStyle: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15))),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Флаг',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 8),
                  _flagsRow(flag, (f) => setModalState(() => flag = f)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (configController.text.contains('[Interface]') &&
                            configController.text.contains('[Peer]')) {
                          try {
                            _addServer(WgConfigParser.fromConfig(
                              configController.text,
                              name: nameController.text.isEmpty
                                  ? 'Eclips'
                                  : nameController.text,
                              flag: flag,
                            ));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Ошибка: $e')));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Неверный формат')));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Импортировать',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showImportFromUrlSheet() {
    final urlController = TextEditingController();
    final nameController = TextEditingController(text: 'Eclips');
    String flag = '🌍';
    bool isLoading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24).withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2))),
              ),
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Импорт по ссылке',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  const SizedBox(height: 16),
                  _glassField(nameController, 'Название'),
                  const SizedBox(height: 12),
                  _glassField(urlController, 'https://example.com/config.conf'),
                  const SizedBox(height: 16),
                  const Text('Флаг',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                  const SizedBox(height: 8),
                  _flagsRow(flag, (f) => setModalState(() => flag = f)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (urlController.text.isEmpty) return;
                              setModalState(() => isLoading = true);
                              try {
                                final response = await http
                                    .get(Uri.parse(urlController.text));
                                if (response.statusCode == 200) {
                                  _addServer(WgConfigParser.fromConfig(
                                    response.body,
                                    name: nameController.text.isEmpty
                                        ? 'Eclips'
                                        : nameController.text,
                                    flag: flag,
                                  ));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'HTTP ${response.statusCode}')));
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Ошибка: $e')));
                              } finally {
                                setModalState(() => isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Скачать',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showManualInputSheet() {
    final nameController = TextEditingController();
    final privateKeyController = TextEditingController();
    final publicKeyController = TextEditingController();
    final endpointController = TextEditingController();
    final dnsController = TextEditingController(text: '1.1.1.1');
    String flag = '🌍';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24).withOpacity(0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.2))),
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
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Ввести вручную',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 16),
                    _glassField(nameController, 'Название'),
                    const SizedBox(height: 12),
                    _glassField(privateKeyController, 'Private Key'),
                    const SizedBox(height: 12),
                    _glassField(publicKeyController, 'Public Key сервера'),
                    const SizedBox(height: 12),
                    _glassField(endpointController, 'Endpoint (IP:порт)'),
                    const SizedBox(height: 12),
                    _glassField(dnsController, 'DNS'),
                    const SizedBox(height: 16),
                    const Text('Флаг',
                        style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    _flagsRow(flag, (f) => setModalState(() => flag = f)),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (privateKeyController.text.isNotEmpty &&
                              publicKeyController.text.isNotEmpty &&
                              endpointController.text.isNotEmpty) {
                            _addServer(WgServer(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              name: nameController.text.isEmpty
                                  ? 'Eclips'
                                  : nameController.text,
                              privateKey: privateKeyController.text,
                              publicKey: publicKeyController.text,
                              endpoint: endpointController.text,
                              dns: dnsController.text,
                              flag: flag,
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Добавить',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
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

  Widget _flagsRow(String selected, Function(String) onSelect) {
    final flags = ['🇩', '🇳', '🇺', '🇯🇵', '🇬', '🇧', '🇷', '🇷🇺', '🌍'];
    final widgets = <Widget>[];
    for (final f in flags) {
      widgets.add(GestureDetector(
        onTap: () => onSelect(f),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected == f
                ? const Color(0xFF7C3AED)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: selected == f
                  ? const Color(0xFF7C3AED)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Center(
            child: Text(f, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ));
    }
    return Wrap(spacing: 8, children: widgets);
  }

  Widget _glassField(TextEditingController controller, String hint) {
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
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF7C3AED), width: 2)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connected = servers.firstWhere(
      (s) => s.id == connectedServerId,
      orElse: () => WgServer(
        id: '',
        name: 'Не подключено',
        privateKey: '',
        publicKey: '',
        endpoint: '',
      ),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('Eclips',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 28),
              onPressed: _showImportOptions),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
              child: Stack(children: [
            Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF7C3AED).withOpacity(0.4),
                      const Color(0xFF7C3AED).withOpacity(0),
                    ]),
                  ),
                )),
            Positioned(
                bottom: 100,
                left: -80,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF06B6D4).withOpacity(0.3),
                      const Color(0xFF06B6D4).withOpacity(0),
                    ]),
                  ),
                )),
          ])),
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
              SliverToBoxAdapter(
                  child: Center(
                child: Column(children: [
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
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF10B981),
                                  Color(0xFF059669),
                                ],
                              )
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF7C3AED),
                                  Color(0xFF5B21B6),
                                ],
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: (connectedServerId != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF7C3AED))
                                .withOpacity(0.5),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(alignment: Alignment.center, children: [
                        if (isConnecting)
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) => Container(
                              width: 160 + (_pulseController.value * 30),
                              height: 160 + (_pulseController.value * 30),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(
                                      1 - _pulseController.value),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        Icon(
                          connectedServerId != null
                              ? Icons.check
                              : Icons.power_settings_new,
                          size: 60,
                          color: Colors.white,
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(connected.name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                      connectedServerId != null
                          ? 'Защищено'
                          : 'Нажмите для подключения',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.5))),
                ]),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Серверы',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text('${servers.length} доступно',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.5))),
                    ]),
              )),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (servers.isEmpty)
                const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(children: [
                    Icon(Icons.vpn_lock_outlined,
                        size: 64, color: Colors.white38),
                    SizedBox(height: 16),
                    Text('Нет серверов',
                        style: TextStyle(
                            fontSize: 16, color: Colors.white54)),
                    SizedBox(height: 8),
                    Text('Нажмите + чтобы добавить',
                        style: TextStyle(
                            fontSize: 13, color: Colors.white38)),
                  ]),
                ))),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final server = servers[index];
                    final isConnected = server.id == connectedServerId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: GestureDetector(
                        onTap: () => isConnected
                            ? _disconnect()
                            : _connectToServer(server),
                        onLongPress: () => _deleteServer(index),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: Colors.white.withOpacity(
                                    isConnected ? 0.15 : 0.08),
                                border: Border.all(
                                  color: isConnected
                                      ? const Color(0xFF10B981)
                                          .withOpacity(0.5)
                                      : Colors.white.withOpacity(0.15),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                  if (isConnected)
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  child: Center(
                                    child: Text(server.flag,
                                        style: const TextStyle(
                                            fontSize: 24)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(server.name,
                                          style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: Colors.white)),
                                      const SizedBox(height: 4),
                                      Text(server.endpoint,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white
                                                  .withOpacity(0.6))),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isConnected
                                        ? const Color(0xFF10B981)
                                        : Colors.white.withOpacity(0.3),
                                    boxShadow: isConnected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                      0xFF10B981)
                                                  .withOpacity(0.6),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: servers.length),
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
    super.dispose();
  }
}
