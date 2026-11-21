import 'solar_engine.dart';

class ToConverter {
  /// Convertit une chaîne "HH:MM" en heures décimales
  static double parseHHMM(String hhmm, double fallback) {
    try {
      final parts = hhmm.trim().split(':');
      if (parts.length != 2) return fallback;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      if (h < 0 || h > 23 || m < 0 || m > 59) return fallback;
      return h + m / 60.0;
    } catch (_) {
      return fallback;
    }
  }

  /// Calcule l'heure To formatée en "HH:MM:SS"
  static String calculateToString({
    required DateTime nowLocal,
    required SolarTimes solar,
    required double consigneLeverHours,
    required double consigneCoucherHours,
  }) {
    final double currentH = nowLocal.hour +
        nowLocal.minute / 60.0 +
        nowLocal.second / 3600.0 +
        nowLocal.millisecond / 3600000.0;

    final double leverR = solar.sunriseHours;
    final double coucherR = solar.sunsetHours;
    final double leverLendemainR = solar.nextSunriseHours;

    double toHours;

    // Segment JOUR : [Lever Réel -> Coucher Réel] => [Consigne Lever -> Consigne Coucher]
    if (currentH >= leverR && currentH <= coucherR) {
      final double dureeJourR = coucherR - leverR;
      double dureeJourP = consigneCoucherHours - consigneLeverHours;
      if (dureeJourP <= 0) dureeJourP += 24.0;

      if (dureeJourR > 0) {
        toHours = consigneLeverHours + (currentH - leverR) * (dureeJourP / dureeJourR);
      } else {
        toHours = consigneLeverHours;
      }
    }
    // Segment NUIT : [Coucher Réel -> Lever Réel Lendemain] => [Consigne Coucher -> Consigne Lever]
    else {
      final double totalNuitR = (24.0 - coucherR) + leverLendemainR;
      double totalNuitP = (24.0 - consigneCoucherHours) + consigneLeverHours;
      if (totalNuitP <= 0) totalNuitP += 24.0;

      final double ecouleNuit = currentH > coucherR
          ? (currentH - coucherR)
          : ((24.0 - coucherR) + currentH);

      if (totalNuitR > 0) {
        toHours = consigneCoucherHours + ecouleNuit * (totalNuitP / totalNuitR);
      } else {
        toHours = consigneCoucherHours;
      }
    }

    toHours = toHours % 24.0;
    if (toHours < 0) toHours += 24.0;

    int toH = toHours.floor();
    double remMinutes = (toHours - toH) * 60.0;
    int toM = remMinutes.floor();
    int toS = ((remMinutes - toM) * 60.0).floor();

    if (toS >= 60) {
      toS = 0;
      toM += 1;
    }
    if (toM >= 60) {
      toM = 0;
      toH = (toH + 1) % 24;
    }

    return '${toH.toString().padLeft(2, '0')}:'
        '${toM.toString().padLeft(2, '0')}:'
        '${toS.toString().padLeft(2, '0')}';
  }
}
