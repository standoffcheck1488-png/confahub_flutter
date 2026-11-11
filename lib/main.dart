import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';

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
        fontFamily: 'SF Pro Display',
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

// Модель сервера
class Server {
  final String name;
  final String protocol;
  final String address;
  int ping;
  int status; // 0 = offline, 1 = connecting, 2 = online
  String flag;

  Server({
    required this.name,
    required this.protocol,
    required this.address,
    this.ping = -1,
    this.status = 0,
    this.flag = '🌍',
  });
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int selectedIndex = -1;
  bool isConnecting = false;

  final List<Server> servers = [
    Server(name: 'Германия #1', protocol: 'VLESS Reality', address: '8.8.8.8', flag: '🇩🇪'),
    Server(name: 'Нидерланды #2', protocol: 'Hysteria2', address: '1.1.1.1', flag: '🇳🇱'),
    Server(name: 'США #3', protocol: 'Trojan', address: '9.9.9.9', flag: '🇺🇸'),
    Server(name: 'Япония #4', protocol: 'VLESS', address: '1.0.0.1', flag: '🇯🇵'),
    Server(name: 'Сингапур #5', protocol: 'Shadowsocks', address: '1.1.1.2', flag: '🇸🇬'),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void pingAll() async {
    for (int i = 0; i < servers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() {
        servers[i].ping = Random().nextInt(150) + 20;
      });
    }
  }

  void selectServer(int index) {
    setState(() {
      if (selectedIndex == index) {
        servers[index].status = 0;
        selectedIndex = -1;
        isConnecting = false;
      } else {
        if (selectedIndex != -1) servers[selectedIndex].status = 0;
        selectedIndex = index;
        servers[index].status = 1;
        isConnecting = true;
      }
    });

    if (selectedIndex != -1) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && selectedIndex == index) {
          setState(() {
            servers[index].status = 2;
            isConnecting = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Confahub',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => _showAddServerSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 28),
            onPressed: pingAll,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Фоновые градиентные блобы
          _buildBackgroundBlobs(),

          // Основной контент
          CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 100)),

              // Статус подключения
              SliverToBoxAdapter(
                child: _buildConnectionStatus(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 30)),

              // Заголовок списка
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Серверы',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${servers.length} доступно',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Список серверов
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildServerCard(servers[index], index),
                    ),
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

  // Фоновые блобы
  Widget _buildBackgroundBlobs() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.4),
                    const Color(0xFF7C3AED).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF06B6D4).withOpacity(0.3),
                    const Color(0xFF06B6D4).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 400,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withOpacity(0.25),
                    const Color(0xFFEC4899).withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Статус подключения (большая кнопка сверху)
  Widget _buildConnectionStatus() {
    final isConnected = selectedIndex != -1 && servers[selectedIndex].status == 2;
    final serverName = isConnected ? servers[selectedIndex].name : 'Не подключено';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (selectedIndex != -1) {
                selectServer(selectedIndex);
              }
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isConnected
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                      ),
                boxShadow: [
                  BoxShadow(
                    color: (isConnected ? const Color(0xFF10B981) : const Color(0xFF7C3AED))
                        .withOpacity(0.5),
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
                            border: Border.all(
                              color: Colors.white.withOpacity(1 - _pulseController.value),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  Icon(
                    isConnected ? Icons.check : Icons.power_settings_new,
                    size: 60,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            serverName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isConnected ? 'Защищено' : 'Нажмите для подключения',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Карточка сервера с Liquid Glass
  Widget _buildServerCard(Server server, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => selectServer(index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withOpacity(isSelected ? 0.15 : 0.08),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF10B981).withOpacity(0.5)
                    : Colors.white.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              children: [
                // Флаг
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Text(
                      server.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Инфо
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        server.protocol,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Пинг и статус
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (server.ping > 0)
                      Text(
                        '${server.ping} ms',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: server.ping < 100
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: server.status == 2
                            ? const Color(0xFF10B981)
                            : server.status == 1
                                ? const Color(0xFFF59E0B)
                                : Colors.white.withOpacity(0.3),
                        boxShadow: server.status == 2
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Экран добавления сервера
  void _showAddServerSheet(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final protocolController = TextEditingController(text: 'VLESS');
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
                    'Добавить сервер',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildGlassTextField(nameController, 'Название (например: Германия #1)'),
                  const SizedBox(height: 12),
                  _buildGlassTextField(addressController, 'Адрес сервера (IP или домен)'),
                  const SizedBox(height: 12),
                  _buildGlassTextField(protocolController, 'Протокол (VLESS, Trojan, Hysteria2...)'),

                  const SizedBox(height: 16),
                  const Text(
                    'Флаг страны',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
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
                            color: selectedFlag == flag
                                ? const Color(0xFF7C3AED)
                                : Colors.white.withOpacity(0.1),
                            border: Border.all(
                              color: selectedFlag == flag
                                  ? const Color(0xFF7C3AED)
                                  : Colors.white.withOpacity(0.2),
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
                        if (nameController.text.isNotEmpty && addressController.text.isNotEmpty) {
                          setState(() {
                            servers.add(Server(
                              name: nameController.text,
                              protocol: protocolController.text,
                              address: addressController.text,
                              flag: selectedFlag,
                            ));
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Добавить сервер',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
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
}
