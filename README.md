# Horloge à Temps Organique (To)

**Horloge à Temps Organique (To)** est une application multiplateforme développée avec Flutter qui affiche et calcule l'heure solaire locale en temps réel, accompagnée d'un système complet d'alarmes personnalisables.

## Fonctionnalités principales

* **Calcul solaire astronomique (NOAA) :** Détermination précise du temps solaire local à partir des coordonnées géographiques de l'utilisateur (géolocalisation GPS ou saisie manuelle).
* **Affichage grand écran :** Interface claire et lisible conçue pour un usage quotidien sur ordinateur comme sur mobile.
* **Alarmes personnalisées :** Création et gestion d'alarmes avec sélection de fichiers audio locaux (sonneries personnalisées).
* **Paramètres sauvegardés :** Conservation automatique des préférences et de la configuration utilisateur entre les sessions.

## Plates-formes et distribution

* **Linux (`.deb` et `.AppImage`) :** Paquet installable pour Linux Mint/Ubuntu et exécutable portable.
* **Android (`.apk`) :** Package compilé (`app-release.apk`) compatible avec Android SDK 36+.
* **Windows (`.exe`) :** Compilation automatisée via **GitHub Actions** (`.github/workflows/build_windows.yml`).
