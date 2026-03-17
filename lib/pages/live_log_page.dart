// FALCON EYE — Live Debug Log Page
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/signal_engine.dart';

class LiveLogPage extends ConsumerWidget {
  const LiveLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final env = ref.watch(signalEngineProvider);
    final logs = env.log.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF010802),
      appBar: AppBar(
        title: const Text('ENGINE LOG',
            style: TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 2)),
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Waiting for data...',
              style: TextStyle(color: Color(0xFF2A5A2A), fontFamily: 'monospace')))
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (ctx, i) {
                final line = logs[i];
                Color col = const Color(0xFF3A9A3A);
                if (line.contains('error') || line.contains('Error')) col = const Color(0xFFFF4444);
                if (line.contains('Root') || line.contains('root')) col = const Color(0xFF00FF80);
                if (line.contains('BLE') || line.contains('WiFi')) col = const Color(0xFF00DCFF);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(line,
                      style: TextStyle(color: col, fontSize: 10.5, fontFamily: 'monospace')),
                );
              },
            ),
    );
  }
}
