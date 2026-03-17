import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stealth_service.dart';
import '../services/features_provider.dart';
import '../widgets/back_button_top_left.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  FALCON EYE V48.1 — COVERT MODE SCHEDULER
//  Automatically enters stealth mode based on time-of-day windows.
//  Each rule: start time, end time, active days → triggers stealth on/off.
// ═══════════════════════════════════════════════════════════════════════════════

class ScheduleRule {
  final String id;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final List<bool> activeDays; // Mon-Sun (7 days)
  final bool enabled;
  final String label;

  const ScheduleRule({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.activeDays,
    required this.enabled,
    required this.label,
  });

  bool isActiveNow() {
    final now = DateTime.now();
    final dayIdx = now.weekday - 1; // 0=Mon
    if (dayIdx < 0 || dayIdx >= activeDays.length) return false;
    if (!activeDays[dayIdx]) return false;
    final startMins = startTime.hour * 60 + startTime.minute;
    final endMins   = endTime.hour * 60 + endTime.minute;
    final nowMins   = now.hour * 60 + now.minute;
    if (startMins <= endMins) return nowMins >= startMins && nowMins < endMins;
    // Overnight rule (e.g. 22:00 to 06:00)
    return nowMins >= startMins || nowMins < endMins;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startH': startTime.hour, 'startM': startTime.minute,
    'endH': endTime.hour, 'endM': endTime.minute,
    'days': activeDays, 'enabled': enabled, 'label': label,
  };

  factory ScheduleRule.fromJson(Map<String, dynamic> j) => ScheduleRule(
    id: j['id'],
    startTime: TimeOfDay(hour: j['startH'], minute: j['startM']),
    endTime:   TimeOfDay(hour: j['endH'],   minute: j['endM']),
    activeDays: List<bool>.from(j['days']),
    enabled: j['enabled'],
    label: j['label'],
  );

  ScheduleRule copyWith({bool? enabled}) => ScheduleRule(
    id: id, startTime: startTime, endTime: endTime,
    activeDays: activeDays, enabled: enabled ?? this.enabled, label: label,
  );
}

class CovertSchedulerPage extends ConsumerStatefulWidget {
  const CovertSchedulerPage({super.key});
  @override
  ConsumerState<CovertSchedulerPage> createState() => _CovertSchedulerPageState();
}

class _CovertSchedulerPageState extends ConsumerState<CovertSchedulerPage> {
  static const _kPrefsKey = 'falcon_covert_schedule_v481';
  List<ScheduleRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      if (mounted) setState(() {
        _rules = list.map((e) => ScheduleRule.fromJson(e as Map<String, dynamic>)).toList();
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, jsonEncode(_rules.map((r) => r.toJson()).toList()));
  }

  Future<void> _addRule() async {
    TimeOfDay startT = const TimeOfDay(hour: 22, minute: 0);
    TimeOfDay endT   = const TimeOfDay(hour: 6,  minute: 0);
    final days = List<bool>.filled(7, true);

    final start = await showTimePicker(context: context, initialTime: startT);
    if (!mounted || start == null) return;
    startT = start;
    final end = await showTimePicker(context: context, initialTime: endT);
    if (!mounted || end == null) return;
    endT = end;

    final rule = ScheduleRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: startT, endTime: endT,
      activeDays: days, enabled: true,
      label: 'Rule ${_rules.length + 1}',
    );
    setState(() => _rules.add(rule));
    _save();
  }

  void _toggleRule(int i, bool val) {
    setState(() => _rules[i] = _rules[i].copyWith(enabled: val));
    _save();
  }

  void _deleteRule(int i) {
    setState(() => _rules.removeAt(i));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final color = ref.watch(featuresProvider).primaryColor;
    final stealth = ref.watch(stealthProtocolProvider);
    final activeRule = _rules.where((r) => r.enabled && r.isActiveNow()).firstOrNull;

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
              Text('COVERT SCHEDULER', style: TextStyle(color: color, fontSize: 13,
                  fontFamily: 'monospace', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              Text('AUTO STEALTH ACTIVATION BY TIME WINDOW',
                  style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')),
            ])),
            _badge(activeRule != null ? '◉ COVERT ACTIVE' : '○ IDLE',
                activeRule != null ? Colors.red : Colors.white38),
          ]),
        ),
        // ── Current status ───────────────────────────────────────────
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: activeRule != null
                ? const Color(0xFFFF2222).withValues(alpha: 0.5)
                : color.withValues(alpha: 0.2)),
            color: activeRule != null
                ? const Color(0xFFFF2222).withValues(alpha: 0.06)
                : color.withValues(alpha: 0.04),
          ),
          child: Row(children: [
            Icon(activeRule != null ? Icons.visibility_off : Icons.schedule,
                color: activeRule != null ? const Color(0xFFFF2222) : color, size: 14),
            const SizedBox(width: 8),
            Text(
              activeRule != null
                  ? 'STEALTH ACTIVE — Rule "${activeRule.label}"'
                  : 'No scheduled covert window active now',
              style: TextStyle(
                  color: activeRule != null ? const Color(0xFFFF2222) : color,
                  fontSize: 10, fontFamily: 'monospace'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        // ── Day-of-week header ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const SizedBox(width: 100),
            ...['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) => Expanded(
              child: Text(d, textAlign: TextAlign.center,
                  style: TextStyle(color: color.withValues(alpha: 0.5),
                      fontSize: 9, fontFamily: 'monospace')),
            )),
          ]),
        ),
        // ── Rules list ───────────────────────────────────────────────
        Expanded(
          child: _rules.isEmpty
              ? Center(child: Text('NO RULES — TAP + TO ADD',
                  style: TextStyle(color: color.withValues(alpha: 0.4),
                      fontFamily: 'monospace', letterSpacing: 2)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _rules.length,
                  itemBuilder: (_, i) => _RuleRow(
                    rule: _rules[i],
                    color: color,
                    isActive: _rules[i].isActiveNow(),
                    onToggle: (v) => _toggleRule(i, v),
                    onDelete: () => _deleteRule(i),
                  ),
                ),
        ),
        // ── Controls ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: GestureDetector(
              onTap: _addRule,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  color: color.withValues(alpha: 0.08),
                ),
                alignment: Alignment.center,
                child: Text('+ ADD RULE', style: TextStyle(color: color, fontFamily: 'monospace',
                    fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
              ),
            )),
          ]),
        ),
      ])),
    );
  }

  Widget _badge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Text(t, style: TextStyle(color: c, fontSize: 9, fontFamily: 'monospace')),
  );
}

class _RuleRow extends StatelessWidget {
  final ScheduleRule rule;
  final Color color;
  final bool isActive;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  const _RuleRow({required this.rule, required this.color, required this.isActive,
                  required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = isActive ? const Color(0xFFFF2222) : color;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: isActive ? 0.5 : 0.2)),
        color: c.withValues(alpha: 0.04),
      ),
      child: Row(children: [
        // Time window
        SizedBox(
          width: 100,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rule.label, style: TextStyle(color: c, fontSize: 10, fontFamily: 'monospace',
                fontWeight: FontWeight.bold)),
            Text('${rule.startTime.format(context)} – ${rule.endTime.format(context)}',
                style: TextStyle(color: c.withValues(alpha: 0.7), fontSize: 9, fontFamily: 'monospace')),
          ]),
        ),
        // Day toggles (read-only display)
        ...List.generate(7, (i) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 18,
            decoration: BoxDecoration(
              color: rule.activeDays[i] ? c.withValues(alpha: 0.25) : Colors.transparent,
              border: Border.all(color: rule.activeDays[i] ? c : Colors.white12),
            ),
          ),
        )),
        const SizedBox(width: 8),
        // Toggle
        Switch(
          value: rule.enabled,
          onChanged: onToggle,
          activeColor: c,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        // Delete
        GestureDetector(
          onTap: onDelete,
          child: const Icon(Icons.close, color: Colors.red, size: 16),
        ),
      ]),
    );
  }
}
