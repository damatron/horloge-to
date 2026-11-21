import 'dart:math' as math;

class SolarTimes {
  final double sunriseHours; // Ex: 6.817 pour 06:49
  final double sunsetHours;  // Ex: 16.200 pour 16:12
  final double nextSunriseHours;

  const SolarTimes({
    required this.sunriseHours,
    required this.sunsetHours,
    required this.nextSunriseHours,
  });

  String get sunriseFormatted => formatHoursToHHMM(sunriseHours);
  String get sunsetFormatted => formatHoursToHHMM(sunsetHours);

  static String formatHoursToHHMM(double hours) {
    double totalMinutes = (hours * 60.0) % 1440.0;
    if (totalMinutes < 0) totalMinutes += 1440.0;
    int h = (totalMinutes ~/ 60) % 24;
    int m = (totalMinutes % 60).round();
    if (m == 60) {
      m = 0;
      h = (h + 1) % 24;
    }
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class SolarEngine {
  // Coordonnées par défaut : Québec
  static const double defaultLat = 46.842;
  static const double defaultLon = -71.362;

  /// Calcule l'heure décimale (0.0 à 24.0) du lever et du coucher pour une date donnée
  static ({double sunrise, double sunset}) _calculateForDate(
    DateTime date,
    double lat,
    double lon,
  ) {
    final int dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final double tzOffset = date.timeZoneOffset.inSeconds / 3600.0;

    // Formules astronomiques NOAA
    final double gamma = 2 * math.pi / 365.0 * (dayOfYear - 1 + (12 - 12) / 24.0);
    final double eqtime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));

    final double decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final double latRad = lat * math.pi / 180.0;
    const double zenith = 90.833 * math.pi / 180.0;

    double cosHa = (math.cos(zenith) / (math.cos(latRad) * math.cos(decl))) -
        math.tan(latRad) * math.tan(decl);
    cosHa = cosHa.clamp(-1.0, 1.0);
    final double haDeg = math.acos(cosHa) * 180.0 / math.pi;

    final double sunriseMin = 720.0 - 4.0 * (lon + haDeg) - eqtime + (tzOffset * 60.0);
    final double sunsetMin = 720.0 - 4.0 * (lon - haDeg) - eqtime + (tzOffset * 60.0);

    return (
      sunrise: (sunriseMin / 60.0) % 24.0,
      sunset: (sunsetMin / 60.0) % 24.0,
    );
  }

  static SolarTimes computeDailySolarTimes(
    DateTime now, {
    double lat = defaultLat,
    double lon = defaultLon,
  }) {
    final today = _calculateForDate(now, lat, lon);
    final tomorrow = _calculateForDate(now.add(const Duration(days: 1)), lat, lon);

    return SolarTimes(
      sunriseHours: today.sunrise,
      sunsetHours: today.sunset,
      nextSunriseHours: tomorrow.sunrise,
    );
  }
}
