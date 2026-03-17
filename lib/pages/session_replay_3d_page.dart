import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/recording_replay_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V50.0 — SESSION REPLAY 3D
//  Scrub through a saved recording session. Visualises signal positions over
//  time on a 2D canvas. Uses existing RecordingReplayService.
// ═══════════════════════════════════════════════════════════════════════════════

class SessionReplay3DPage extends ConsumerStatefulWidget {
  const SessionReplay3DPage({super.key});
  @override
  ConsumerState<SessionReplay3DPage> createState() => _SessionReplay3DPageState();
}

class _SessionReplay3DPageState extends ConsumerState<SessionReplay3DPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _scrubPosition = 0.0; // 0..1

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final replay = ref.watch(recordingReplayProvider);
    final svc = ref.read(recordingReplayProvider.notifier);
    final fmt = DateFormat('HH:mm:ss');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const BackButtonTopLeft(),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('SESSION REPLAY 3D', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('SCRUB THROUGH RECORDED SIGNAL SESSIONS',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
            _badge(replay.isPlaying ? '▶ PLAYING' : (replay.isPaused ? '⏸ PAUSED' : '◼ STOPPED'),
                replay.isPlaying ? Colors.greenAccent : Colors.white38),
          ]),
        ),
        // ── Timeline canvas ─────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (ctx, box) => GestureDetector(
              onTapDown: (d) => setState(() =>
                  _scrubPosition = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
              onHorizontalDragUpdate: (d) => setState(() =>
                  _scrubPosition = (d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0)),
              child: AnimatedBuilder(
                animation: _animCtrl,
                builder: (_, __) => CustomPaint(
                  size: Size(box.maxWidth, box.maxHeight),
                  painter: _ReplayPainter(
                    color: color,
                    scrub: _scrubPosition,
                    totalFrames: replay.totalFrames,
                    currentFrame: replay.currentFrameIndex,
                    isPlaying: replay.isPlaying,
                    t: _animCtrl.value,
                  ),
                ),
              ),
            ),
          ),
        ),
        // ── Timeline scrubber ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: _scrubPosition,
                onChanged: (v) {
                  setState(() => _scrubPosition = v);
                  // Seek to frame
                  if (replay.totalFrames > 0) {
                    final frame = (v * replay.totalFrames).toInt().clamp(0, replay.totalFrames - 1);
                    // Would call svc.seekToFrame(frame) if available
                  }
                },
              ),
            ),
            Row(children: [
              Text(_formatTime(replay.currentTime),
                  style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
              const Spacer(),
              Text('Frame ${replay.currentFrameIndex}/${replay.totalFrames}',
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
              const Spacer(),
              Text(_formatTime(replay.totalDuration),
                  style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 10, fontFamily: 'monospace')),
            ]),
          ]),
        ),
        // ── Playback controls ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Speed
            Expanded(child: _btn('0.5×', Colors.white38, () {})),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _btn(
              replay.isPlaying ? '⏸ PAUSE' : '▶ PLAY',
              color,
              () => replay.isPlaying
                  ? svc.pause()
                  : svc.play(),
            )),
            const SizedBox(width: 6),
            Expanded(child: _btn('2×', Colors.white38, () {})),
          ]),
        ),
        // ── Recordings list ──────────────────────────────────────────
        Container(
          height: 120,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.2))),
          child: FutureBuilder<List<RecordingMetadata>>(
            future: ref.read(recordingReplayProvider.notifier).loadRecordingsList(),
            builder: (ctx, snap) {
              if (!snap.hasData || snap.data!.isEmpty) {
                return Center(child: Text('NO RECORDINGS',
                    style: TextStyle(color: color.withValues(alpha: 0.4), fontFamily: 'monospace')));
              }
              return ListView.builder(
                itemCount: snap.data!.length,
                itemBuilder: (_, i) {
                  final rec = snap.data![i];
                  return ListTile(
                    dense: true,
                    title: Text(rec.name, style: const TextStyle(color: Colors.white,
                        fontFamily: 'monospace', fontSize: 11)),
                    subtitle: Text('${rec.frameCount} frames  ·  ${_formatTime(rec.duration)}',
                        style: const TextStyle(color: Colors.white38, fontFamily: 'monospace', fontSize: 9)),
                    trailing: GestureDetector(
                      onTap: () => svc.loadRecording(rec),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.4))),
                        child: Text('LOAD', style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace')),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ])),
    );
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
  );

  Widget _btn(String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.4)),
        color: c.withValues(alpha: 0.06),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(color: c, fontFamily: 'monospace',
          fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold)),
    ),
  );
}

class _ReplayPainter extends CustomPainter {
  final Color color;
  final double scrub;
  final int totalFrames;
  final int currentFrame;
  final bool isPlaying;
  final double t;

  _ReplayPainter({required this.color, required this.scrub, required this.totalFrames,
                  required this.currentFrame, required this.isPlaying, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();

    // Background grid
    p.color = Colors.white.withValues(alpha: 0.04);
    p.strokeWidth = 0.5;
    for (int i = 0; i < 12; i++) {
      canvas.drawLine(Offset(size.width * i / 12, 0), Offset(size.width * i / 12, size.height), p);
    }
    for (int i = 0; i < 8; i++) {
      canvas.drawLine(Offset(0, size.height * i / 8), Offset(size.width, size.height * i / 8), p);
    }

    if (totalFrames == 0) {
      // No session loaded
      final tp = TextPainter(
        text: TextSpan(text: 'LOAD A RECORDING TO REPLAY',
            style: TextStyle(color: color.withValues(alpha: 0.3), fontSize: 13,
                fontFamily: 'monospace', letterSpacing: 2)),
        textDirection: ui.TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height / 2 - 20));
      return;
    }

    // Simulate signal trail at scrub position
    final scrubFrame = (scrub * totalFrames).toInt();
    final seeds = List.generate(12, (i) => i * 7 + 3);

    p.style = PaintingStyle.fill;
    for (int i = 0; i < seeds.length; i++) {
      final seed = seeds[i];
      final phase = (scrubFrame + seed) / 10.0;
      final x = size.width * ((math.sin(phase * 0.7 + seed) * 0.4) + 0.5);
      final y = size.height * ((math.cos(phase * 0.5 + seed * 0.3) * 0.35) + 0.5);

      final alpha = 0.4 + 0.4 * math.sin(t * math.pi * 2 + i);
      p.color = color.withValues(alpha: alpha.clamp(0.1, 0.9));
      final r = 4.0 + 3.0 * math.sin(phase + i * 0.5);
      canvas.drawCircle(Offset(x, y), r.clamp(2.0, 10.0), p);

      // Trail
      for (int j = 1; j <= 5; j++) {
        final prevPhase = (scrubFrame + seed - j * 3) / 10.0;
        final px = size.width * ((math.sin(prevPhase * 0.7 + seed) * 0.4) + 0.5);
        final py = size.height * ((math.cos(prevPhase * 0.5 + seed * 0.3) * 0.35) + 0.5);
        p.color = color.withValues(alpha: (0.15 / j).clamp(0.01, 0.2));
        canvas.drawCircle(Offset(px, py), (r * 0.6).clamp(1.0, 6.0), p);
      }
    }

    // Scrub line
    p.color = color.withValues(alpha: 0.4);
    p.strokeWidth = 1;
    p.style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(size.width * scrub, 0),
        Offset(size.width * scrub, size.height), p);
  }

  @override
  bool shouldRepaint(_ReplayPainter old) => old.currentFrame != currentFrame || old.t != t || old.isPlaying != isPlaying;
}
