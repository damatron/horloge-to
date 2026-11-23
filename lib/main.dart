==> lib/main.dart <==
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

==> lib/ui/views/grand_ecran_view.dart <==
import 'package:flutter/material.dart';

class GrandEcranView extends StatelessWidget {
  final String toTimeStr;
  final String stdTimeStr;
  final int dayOfYear;
  final VoidCallback onOpenSettings;

  const GrandEcranView({
    super.key,
    required this.toTimeStr,
    required this.stdTimeStr,
    required this.dayOfYear,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E1E1E);
    const mintAccent = Color(0xFF00FFAA);

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'HORLOGE À TEMPS ORGANIQUE (TO)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: mintAccent,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Column(
                  children: [
                    const Text(
                      'Heure To :',
                      style: TextStyle(fontSize: 16, color: Color(0xFFCCCCCC)),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        toTimeStr,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 84,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Heure Standard Système :',
                      style: TextStyle(fontSize: 15, color: Color(0xFFCCCCCC)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      stdTimeStr,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 32,
                        color: mintAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Jour de l'année : $dayOfYear",
                      style: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mintAccent,
                      foregroundColor: bgDark,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Paramètres Solaires & Alarmes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

==> lib/ui/views/parametres_view.dart <==
import 'package:flutter/material.dart';
import '../../models/alarm_model.dart';

class ParametresView extends StatelessWidget {
  final String leverReelStr;
  final String coucherReelStr;
  final TextEditingController consigneLeverCtrl;
  final TextEditingController consigneCoucherCtrl;
  final String stdTimeStr;
  final String toTimeStr;
  final List<AlarmModel> alarms;
  final VoidCallback onConsignesChanged;
  final VoidCallback onBackToGrandEcran;
  final VoidCallback onAddAlarm;
  final void Function(int index) onEditAlarm;
  final void Function(int index) onDeleteAlarm;
  final void Function(int index, bool active) onToggleAlarm;

  const ParametresView({
    super.key,
    required this.leverReelStr,
    required this.coucherReelStr,
    required this.consigneLeverCtrl,
    required this.consigneCoucherCtrl,
    required this.stdTimeStr,
    required this.toTimeStr,
    required this.alarms,
    required this.onConsignesChanged,
    required this.onBackToGrandEcran,
    required this.onAddAlarm,
    required this.onEditAlarm,
    required this.onDeleteAlarm,
    required this.onToggleAlarm,
  });

  static const _cream = Color(0xFFFFF4B8);
  static const _navy = Color(0xFF002266);

  String _formatDays(AlarmModel a) {
    if (a.once) return 'Une seule fois';
    final activeDays = a.days.entries.where((e) => e.value).map((e) => e.key.substring(0, 3)).toList();
    if (activeDays.length == 7) return 'Tous les jours';
    return activeDays.isEmpty ? 'Aucun jour' : activeDays.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final activeAlarms = alarms.where((a) => a.active).toList();

    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre supérieure responsive
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navy),
                        onPressed: onAddAlarm,
                        child: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                        onPressed: onBackToGrandEcran,
                        child: const Text('Grand Écran', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                    'Système : $stdTimeStr  |  To : $toTimeStr',
                    style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bloc Paramètres Solaires & Consignes
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _navy.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paramètres Solaires & Consignes',
                      style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Text('Soleil Lever Réel : $leverReelStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        Text('Soleil Coucher Réel : $coucherReelStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: consigneLeverCtrl,
                            onChanged: (_) => onConsignesChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Consigne Lever (HH:MM)',
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: consigneCoucherCtrl,
                            onChanged: (_) => onConsignesChanged(),
                            decoration: const InputDecoration(
                              labelText: 'Consigne Coucher (HH:MM)',
                              filled: true,
                              fillColor: Colors.white,
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Liste des alarmes
              Expanded(
                child: alarms.isEmpty
                    ? const Center(
                        child: Text(
                          "Aucune alarme programmée. Cliquez sur '+' pour en ajouter.",
                          style: TextStyle(color: Colors.black54, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: alarms.length,
                        itemBuilder: (context, idx) {
                          final alarm = alarms[idx];
                          return Card(
                            color: Colors.white.withValues(alpha: 0.8),
                            child: ListTile(
                              leading: Checkbox(
                                value: alarm.active,
                                activeColor: _navy,
                                onChanged: (val) => onToggleAlarm(idx, val ?? true),
                              ),
                              title: Text(
                                '${alarm.time}  -  ${alarm.label}',
                                style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('${_formatDays(alarm)}  •  [${alarm.type}]'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: _navy),
                                    tooltip: 'Éditer',
                                    onPressed: () => onEditAlarm(idx),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Color(0xFFD90000)),
                                    tooltip: 'Supprimer',
                                    onPressed: () => onDeleteAlarm(idx),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Résumé des prochaines alarmes
              const Divider(color: _navy),

==> lib/ui/widgets/alarm_dialog.dart <==
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../models/alarm_model.dart';

class AlarmDialog extends StatefulWidget {
  final AlarmModel? existingAlarm;

  const AlarmDialog({super.key, this.existingAlarm});

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  late TextEditingController _timeCtrl;
  late TextEditingController _labelCtrl;
  late TextEditingController _soundCtrl;
  late String _type;
  late String _duration;
  late bool _once;
  late Map<String, bool> _days;

  static const _navy = Color(0xFF002266);
  static const _cream = Color(0xFFFFF4B8);

  @override
  void initState() {
    super.initState();
    final a = widget.existingAlarm;
    _timeCtrl = TextEditingController(text: a?.time ?? '08:00');
    _labelCtrl = TextEditingController(text: a?.label ?? 'Mon alarme');
    _soundCtrl = TextEditingController(text: a?.sound ?? 'Sonneries/Flute.mp3');
    _type = a?.type ?? 'Standard';
    _duration = a?.duration ?? 'Arrêt après 20 sec';
    _once = a?.once ?? true;
    _days = a != null ? Map<String, bool>.from(a.days) : AlarmModel.defaultDays();
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _labelCtrl.dispose();
    _soundCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg'],
    );
    if (result.isNotEmpty && result.single.path != null) {
      setState(() {
        _soundCtrl.text = result.single.path!;
      });
    }
  }

  void _submit() {
    final rawTime = _timeCtrl.text.trim();
    final validFormat = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').hasMatch(rawTime);
    if (!validFormat) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une heure valide au format HH:MM (ex: 08:30).')),
      );
      return;
    }

    final alarm = AlarmModel(
      id: widget.existingAlarm?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      time: rawTime,
      label: _labelCtrl.text.trim().isEmpty ? 'Mon alarme' : _labelCtrl.text.trim(),
      sound: _soundCtrl.text.trim(),
      duration: _duration,
      once: _once,
      active: true,
      type: _type,
      days: _days,
    );
    Navigator.of(context).pop(alarm);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingAlarm != null;

    return AlertDialog(
      backgroundColor: _cream,
      title: Text(
        isEdit ? "Éditer l'alarme" : "Programmer une alarme",
        style: const TextStyle(color: _navy, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "⚠ ATTENTION : Ne pas utiliser le mode 'Type: To' pour les rendez-vous synchronisés.",
                style: TextStyle(color: Color(0xFFD90000), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _timeCtrl,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Heure (HH:MM)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navy),
                    onPressed: () => setState(() => _type = _type == 'Standard' ? 'To' : 'Standard'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text('Type : $_type', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description / Nom',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _soundCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Fichier Sonnerie (.mp3)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navy),
                    onPressed: _pickAudioFile,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Parcourir...'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navy),
                onPressed: () => setState(() {
                  _duration = _duration == 'Arrêt après 20 sec'
                      ? 'Sonnerie continue'
                      : 'Arrêt après 20 sec';
                }),
                child: Text('Mode : $_duration', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('Une seule fois', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
                value: _once,
                activeColor: _navy,
                onChanged: (val) {
                  setState(() {
                    _once = val ?? true;
                    if (_once) {
                      _days.updateAll((_, __) => false);
                    }
                  });
                },
              ),
              Wrap(
                spacing: 8,
                children: _days.keys.map((day) {
                  return FilterChip(
                    label: Text(day),
                    selected: _days[day]!,
                    selectedColor: _navy,
                    labelStyle: TextStyle(color: _days[day]! ? Colors.white : _navy),
                    onSelected: (selected) {
                      setState(() {
                        _days[day] = selected;
                        _once = !_days.values.any((v) => v);

