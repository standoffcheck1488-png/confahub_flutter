import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(const ConfahubApp());
}

class ConfahubApp extends StatelessWidget {
  const ConfahubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Confahub',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F13),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class Server {
  final String name;
  final String protocol;
  final String address;
  int ping;
  int status;

  Server(this.name, this.protocol, this.address, {this.ping = -1, this.status = 0});
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final List<Server> servers = [
    Server('Германия #1', 'VLESS Reality (HTTPS)', '8.8.8.8'),
    Server('Нидерланды #2', 'Hysteria2 (UDP)', '1.1.1.1'),
    Server('США #3', 'Trojan (HTTPS)', '9.9.9.9'),
  ];
  int selectedIndex = -1;

  void pingAll() async {
    for (int i = 0; i < servers.length; i++) {
      final randomPing = Random().nextInt(150) + 20;
      setState(() {
        servers[i].ping = randomPing;
      });
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  void selectServer(int index) {
    if (servers[index].ping == -1) return;
    setState(() {
      if (selectedIndex == index) {
        servers[selectedIndex].status = 0;
        selectedIndex = -1;
      } else {
        if (selectedIndex != -1) servers[selectedIndex].status = 0;
        selectedIndex = index;
        servers[index].status = 1;
      }
    });

    if (selectedIndex != -1) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && selectedIndex != -1) {
          setState(() {
            servers[selectedIndex].status = 2;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confahub', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: pingAll,
            tooltip: 'Пинг всех серверов',
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: servers.length,
        itemBuilder: (context, index) {
          final srv = servers[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              onTap: () => selectServer(index),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: srv.status == 2
                          ? Colors.greenAccent
                          : srv.status == 1
                              ? Colors.amberAccent
                              : Colors.redAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(srv.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '${srv.protocol}  |  ${srv.ping > 0 ? '${srv.ping} ms' : 'Пинг...'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const GlassCard({super.key, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
