class AlarmModel {
  final String id;
  final String time; // Format "HH:MM"
  final String label;
  final String sound; // Chemin asset ("Sonneries/Flute.mp3") ou chemin fichier local
  final String duration; // "Arrêt après 20 sec" ou "Sonnerie continue"
  final bool once;
  bool active;
  final String type; // "Standard" ou "To"
  final Map<String, bool> days;

  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.sound,
    required this.duration,
    required this.once,
    this.active = true,
    required this.type,
    required this.days,
  });

  static Map<String, bool> defaultDays() => {
        'Lundi': false,
        'Mardi': false,
        'Mercredi': false,
        'Jeudi': false,
        'Vendredi': false,
        'Samedi': false,
        'Dimanche': false,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'label': label,
        'sound': sound,
        'duration': duration,
        'once': once,
        'active': active,
        'type': type,
        'days': days,
      };

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    final rawDays = Map<String, dynamic>.from(json['days'] ?? defaultDays());
    return AlarmModel(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      time: json['time'] ?? '08:00',
      label: json['label'] ?? 'Mon alarme',
      sound: json['sound'] ?? 'Sonneries/Flute.mp3',
      duration: json['duration'] ?? 'Arrêt après 20 sec',
      once: json['once'] ?? true,
      active: json['active'] ?? true,
      type: json['type'] ?? 'Standard',
      days: rawDays.map((k, v) => MapEntry(k, v == true)),
    );
  }
}