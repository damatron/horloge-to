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
