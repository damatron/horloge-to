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
              const Text(
                'Prochaines Alarmes :',
                style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                activeAlarms.isEmpty
                    ? 'Aucune alarme active.'
                    : activeAlarms
                        .take(3)
                        .map((a) => '• ${a.time} (${a.type}) - ${a.label} [${_formatDays(a)}]')
                        .join('\n'),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
