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
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: _navy)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
          onPressed: _submit,
          child: Text(isEdit ? 'Enregistrer' : 'OK'),
        ),
      ],
    );
  }
}
