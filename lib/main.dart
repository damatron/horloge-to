import 'dart:async';
import 'package:flutter/material.dart';
import 'core/solar_engine.dart';
import 'core/to_converter.dart';
import 'models/alarm_model.dart';
import 'services/audio_service.dart';
import 'services/storage_service.dart';
import 'ui/views/grand_ecran_view.dart';
import 'ui/views/parametres_view.dart';
import 'ui/widgets/alarm_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HorlogeOrganiqueRoot());
}

class HorlogeOrganiqueRoot extends StatelessWidget {
  const HorlogeOrganiqueRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Horloge à Temps Organique (To)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF002266),
      ),
      home: const HorlogeHomePage(),
    );
  }
}

class HorlogeHomePage extends StatefulWidget {
  const HorlogeHomePage({super.key});

  @override
  State<HorlogeHomePage> createState() => _HorlogeHomePageState();
}

class _HorlogeHomePageState extends State<HorlogeHomePage> {
  final AudioService _audioService = AudioService();
  final TextEditingController _consigneLeverCtrl = TextEditingController(text: '06:00');
  final TextEditingController _consigneCoucherCtrl = TextEditingController(text: '19:00');

  Timer? _timer;
  DateTime _now = DateTime.now();
  List<AlarmModel> _alarms = [];
  String? _lastTriggeredMinuteKey;
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = DateTime.now();
      if (!mounted) return;
      setState(() {
        _now = current;
      });
      _checkAlarms(current);
    });
  }

  Future<void> _initData() async {
    final loaded = await StorageService.loadAll();
    if (!mounted) return;
    setState(() {
      _consigneLeverCtrl.text = loaded.lever;
      _consigneCoucherCtrl.text = loaded.coucher;
      _alarms = loaded.alarms;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _consigneLeverCtrl.dispose();
    _consigneCoucherCtrl.dispose();
    _audioService.dispose();
    super.dispose();
  }

  int _dayOfYear(DateTime dt) {
    return dt.difference(DateTime(dt.year, 1, 1)).inDays + 1;
  }

  String _formatStandardTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _currentToTime(DateTime dt, SolarTimes solar) {
    return ToConverter.calculateToString(
      nowLocal: dt,
      solar: solar,
      consigneLeverHours: ToConverter.parseHHMM(_consigneLeverCtrl.text, 6.0),
      consigneCoucherHours: ToConverter.parseHHMM(_consigneCoucherCtrl.text, 19.0),
    );
  }

  bool _isDayForAlarm(AlarmModel alarm, DateTime dt) {
    const dayNames = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    final todayName = dayNames[dt.weekday - 1];
    final hasSelectedDays = alarm.days.values.any((selected) => selected);
    if (!hasSelectedDays) return true;
    return alarm.days[todayName] == true;
  }

  void _checkAlarms(DateTime dt) {
    final hhmmStandard =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final solar = SolarEngine.computeDailySolarTimes(dt);
    final toFull = _currentToTime(dt, solar);
    final hhmmTo = toFull.substring(0, 5);
    final minuteKey = '${dt.year}-${dt.month}-${dt.day} $hhmmStandard|$hhmmTo';

    if (_lastTriggeredMinuteKey == minuteKey) return;

    for (final alarm in _alarms) {
      if (!alarm.active || !_isDayForAlarm(alarm, dt)) continue;
      final matches = alarm.type == 'To'
          ? alarm.time == hhmmTo
          : alarm.time == hhmmStandard;

      if (matches) {
        _lastTriggeredMinuteKey = minuteKey;
        if (alarm.once) {
          alarm.active = false;
          StorageService.saveAlarms(_alarms);
        }
        _triggerAlarmPopup(alarm);
        break;
      }
    }
  }

  void _triggerAlarmPopup(AlarmModel alarm) {
    _audioService.playAlarm(alarm.sound, alarm.duration);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF4B8),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          '⏰ ALARME !',
          style: TextStyle(color: Color(0xFF002266), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Nom : ${alarm.label}\n'
          'Heure : ${alarm.time} (${alarm.type})\n'
          'Mode : ${alarm.duration}',
          style: const TextStyle(fontSize: 15, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF002266),
              surfaceTintColor: Colors.transparent,
            ),
            onPressed: () {
              _audioService.stop();
              Navigator.of(ctx).pop();
            },
            child: const Text('Arrêter', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveConsignes() async {
    await StorageService.saveConsignes(
      _consigneLeverCtrl.text.trim(),
      _consigneCoucherCtrl.text.trim(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addAlarm() async {
    final result = await showDialog<AlarmModel>(
      context: context,
      builder: (ctx) => const AlarmDialog(),
    );
    if (result == null) return;
    setState(() {
      _alarms.add(result);
    });
    await StorageService.saveAlarms(_alarms);
  }

  Future<void> _editAlarm(int index) async {
    if (index < 0 || index >= _alarms.length) return;
    final result = await showDialog<AlarmModel>(
      context: context,
      builder: (ctx) => AlarmDialog(existingAlarm: _alarms[index]),
    );
    if (result == null) return;
    setState(() {
      _alarms[index] = result;
    });
    await StorageService.saveAlarms(_alarms);
  }

  Future<void> _deleteAlarm(int index) async {
    if (index < 0 || index >= _alarms.length) return;
    setState(() {
      _alarms.removeAt(index);
    });
    await StorageService.saveAlarms(_alarms);
  }

  Future<void> _toggleAlarm(int index, bool active) async {
    if (index < 0 || index >= _alarms.length) return;
    setState(() {
      _alarms[index].active = active;
    });
    await StorageService.saveAlarms(_alarms);
  }

  @override
  Widget build(BuildContext context) {
    final solar = SolarEngine.computeDailySolarTimes(_now);
    final toStr = _currentToTime(_now, solar);
    final stdStr = _formatStandardTime(_now);

    if (_showSettings) {
      return ParametresView(
        leverReelStr: solar.sunriseFormatted,
        coucherReelStr: solar.sunsetFormatted,
        consigneLeverCtrl: _consigneLeverCtrl,
        consigneCoucherCtrl: _consigneCoucherCtrl,
        stdTimeStr: stdStr,
        toTimeStr: toStr,
        alarms: _alarms,
        onConsignesChanged: _saveConsignes,
        onBackToGrandEcran: () {
          setState(() {
            _showSettings = false;
          });
        },
        onAddAlarm: _addAlarm,
        onEditAlarm: _editAlarm,
        onDeleteAlarm: _deleteAlarm,
        onToggleAlarm: _toggleAlarm,
      );
    }

    return GrandEcranView(
      toTimeStr: toStr,
      stdTimeStr: stdStr,
      dayOfYear: _dayOfYear(_now),
      onOpenSettings: () {
        setState(() {
          _showSettings = true;
        });
      },
    );
  }
}
