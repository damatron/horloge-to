import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
      theme: ThemeData(useMaterial3: true),
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

  bool _isGrandEcran = true;
  double _lat = SolarEngine.defaultLat;
  double _lon = SolarEngine.defaultLon;
  late SolarTimes _solarTimes;
  DateTime _lastSolarDate = DateTime.now();

  String _toTimeStr = '--:--:--';
  String _stdTimeStr = '--:--:--';
  int _dayOfYear = 1;
  String _lastTriggeredKey = '';

  List<AlarmModel> _alarms = [];
  Timer? _clockTimer;

  static const _weekdaysFr = {
    1: 'Lundi',
    2: 'Mardi',
    3: 'Mercredi',
    4: 'Jeudi',
    5: 'Vendredi',
    6: 'Samedi',
    7: 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    _solarTimes = SolarEngine.computeDailySolarTimes(DateTime.now(), lat: _lat, lon: _lon);
    _initData();
    _startClock();
  }

  Future<void> _initData() async {
    final loaded = await StorageService.loadAll();
    if (!mounted) return;
    setState(() {
      _consigneLeverCtrl.text = loaded.lever;
      _consigneCoucherCtrl.text = loaded.coucher;
      _alarms = loaded.alarms;
    });

    // Sur Android/iOS, tente de récupérer la position GPS réelle
    if (Platform.isAndroid || Platform.isIOS) {
      await _updateMobileGps();
    }
  }

  Future<void> _updateMobileGps() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() {
          _lat = pos.latitude;
          _lon = pos.longitude;
          _solarTimes = SolarEngine.computeDailySolarTimes(DateTime.now(), lat: _lat, lon: _lon);
        });
      }
    } catch (_) {
      // Conserve Québec (46.842, -71.362) en cas d'échec ou refus GPS
    }
  }

  void _startClock() {
    _tick();
    _clockTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final now = DateTime.now();

    // Recalcul quotidien automatique des éphémérides
    if (now.day != _lastSolarDate.day || now.month != _lastSolarDate.month || now.year != _lastSolarDate.year) {
      _lastSolarDate = now;
      _solarTimes = SolarEngine.computeDailySolarTimes(now, lat: _lat, lon: _lon);
    }

    final stdStr = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final consigneLever = ToConverter.parseHHMM(_consigneLeverCtrl.text, 6.0);
    final consigneCoucher = ToConverter.parseHHMM(_consigneCoucherCtrl.text, 19.0);

    final toStr = ToConverter.calculateToString(
      nowLocal: now,
      solar: _solarTimes,
      consigneLeverHours: consigneLever,
      consigneCoucherHours: consigneCoucher,
    );

    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

    setState(() {
      _stdTimeStr = stdStr;
      _toTimeStr = toStr;
      _dayOfYear = dayOfYear;
    });

    _checkAlarms(now, stdStr.substring(0, 5), toStr.substring(0, 5));
  }

  void _checkAlarms(DateTime now, String stdHM, String toHM) {
    final triggerKey = '${stdHM}_$toHM';
    if (triggerKey == _lastTriggeredKey) return;

    final todayName = _weekdaysFr[now.weekday] ?? 'Lundi';

    for (final alarm in _alarms) {
      if (!alarm.active) continue;
      final matchesTime = (alarm.type == 'Standard' && alarm.time == stdHM) ||
          (alarm.type == 'To' && alarm.time == toHM);
      if (matchesTime) {
        final shouldRing = alarm.once || (alarm.days[todayName] ?? false);
        if (shouldRing) {
          _lastTriggeredKey = triggerKey;
          if (alarm.once) {
            setState(() => alarm.active = false);
            StorageService.saveAlarms(_alarms);
          }
          _triggerAlarmPopup(alarm);
          break;
        }
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
            ),
            onPressed: () {
              _audioService.stop();
              Navigator.of(ctx).pop();
            },
            child: const Text('Arrêter / Fermer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _openAlarmDialog({AlarmModel? existing, int? editIndex}) async {
    final result = await showDialog<AlarmModel>(
      context: context,
      builder: (_) => AlarmDialog(existingAlarm: existing),
    );
    if (result != null) {
      setState(() {
        if (editIndex != null) {
          _alarms[editIndex] = result;
        } else {
          _alarms.add(result);
        }
      });
      await StorageService.saveAlarms(_alarms);
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _audioService.dispose();
    _consigneLeverCtrl.dispose();
    _consigneCoucherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGrandEcran) {
      return GrandEcranView(
        toTimeStr: _toTimeStr,
        stdTimeStr: _stdTimeStr,
        dayOfYear: _dayOfYear,
        onOpenSettings: () => setState(() => _isGrandEcran = false),
      );
    }

    return ParametresView(
      leverReelStr: _solarTimes.sunriseFormatted,
      coucherReelStr: _solarTimes.sunsetFormatted,
      consigneLeverCtrl: _consigneLeverCtrl,
      consigneCoucherCtrl: _consigneCoucherCtrl,
      stdTimeStr: _stdTimeStr,
      toTimeStr: _toTimeStr,
      alarms: _alarms,
      onConsignesChanged: () => StorageService.saveConsignes(
        _consigneLeverCtrl.text,
        _consigneCoucherCtrl.text,
      ),
      onBackToGrandEcran: () => setState(() => _isGrandEcran = true),
      onAddAlarm: () => _openAlarmDialog(),
      onEditAlarm: (idx) => _openAlarmDialog(existing: _alarms[idx], editIndex: idx),
      onDeleteAlarm: (idx) async {
        setState(() => _alarms.removeAt(idx));
        await StorageService.saveAlarms(_alarms);
      },
      onToggleAlarm: (idx, active) async {
        setState(() => _alarms[idx].active = active);
        await StorageService.saveAlarms(_alarms);
      },
    );
  }
}
