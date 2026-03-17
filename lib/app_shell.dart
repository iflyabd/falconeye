// FALCON EYE — App Shell with real bottom navigation
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/real_radar_page.dart';
import 'pages/signal_detail_page.dart';
import 'pages/live_log_page.dart';
import 'pages/environment_scan_page.dart';
import 'services/signal_engine.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _tab = 0;

  static const _pages = [
    RealRadarPage(),
    SignalDetailPage(),
    EnvironmentScanPage(),
    LiveLogPage(),
  ];

  static const _tabs = [
    BottomNavigationBarItem(icon: Icon(Icons.radar), label: '3D RADAR'),
    BottomNavigationBarItem(icon: Icon(Icons.wifi), label: 'SIGNALS'),
    BottomNavigationBarItem(icon: Icon(Icons.view_in_ar), label: 'ENVIRON'),
    BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'LOG'),
  ];

  @override
  Widget build(BuildContext context) {
    // Start the engine on first frame
    ref.watch(signalEngineProvider);

    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF00FF80),
        unselectedItemColor: const Color(0xFF2A4A2A),
        selectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 8, letterSpacing: 1),
        unselectedLabelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 8),
        items: _tabs,
      ),
    );
  }
}
