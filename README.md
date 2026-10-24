# 📸 BestCam — L'Appareil Photo iOS à Déclenchement Vocal Intelligent

[![Release](https://img.shields.io/github/v/release/je-tu-il/BestCam?color=blue&label=Version)](https://github.com/je-tu-il/BestCam/releases/latest)
[![Build iOS](https://github.com/je-tu-il/BestCam/actions/workflows/build.yml/badge.svg)](https://github.com/je-tu-il/BestCam/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Plateforme-iPhone%20%7C%20iPad%20(iOS%2017%2B)-blue.svg)](https://github.com/je-tu-il/BestCam/releases/latest)

> **BestCam** réinvente la prise de vue sur iPhone : déclenchez des photos et des vidéos à distance à la voix, sans toucher l'écran ni utiliser de télécommande Bluetooth. Idéal pour les photos de groupe, les selfies à distance, les vlogs et les prises de vue sur trépied !

---

## 📲 Téléchargement Direct & Installation

Téléchargez l'application prête à l'emploi sur la page [**Releases GitHub**](https://github.com/je-tu-il/BestCam/releases/latest) :

1. Téléchargez le fichier **`BestCam.ipa`**.
2. Installez-le avec votre outil de sideloading habituel :
   - 🍏 **AltStore / SideStore** : Onglet *My Apps* > bouton `+` > sélectionnez `BestCam.ipa`.
   - 💻 **Sideloadly** : Glissez `BestCam.ipa` et lancez l'installation en USB.
   - ⚡ **TrollStore** : Installation directe sans signature.

---

## ✨ Fonctionnalités Clés

- 🎙️ **Déclenchement Vocal Mains-Libres** :
  - Dites *"Photo"* ou *"Cheese"* pour capturer un cliché instantanément.
  - Dites *"Vidéo"* ou *"Enregistre"* pour lancer l'enregistrement vidéo.
  - Traitement vocal **100% local sur l'appareil** via `Speech.framework` (aucun son n'est envoyé sur internet).
- 📷 **Contrôle Précis de la Caméra** :
  - Bascule instantanée caméra avant / arrière.
  - Flash automatique, forcé ou désactivé.
  - Exposition et mise au point automatiques en continu.
- ⚡ **Architecture Déclarative & Légère** :
  - Projet généré automatiquement avec **XcodeGen** (`project.yml`).
  - Interface minimaliste SwiftUI pensée pour la vitesse.

---

## 🛠️ Stack Technique

- **Langage** : Swift 5.9+ / SwiftUI
- **Gestionnaire de projet** : [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- **Frameworks** : AVFoundation, Speech, Photos
- **Cible** : iOS 17.0+ (iPhone)
- **CI/CD** : GitHub Actions (compilation Release IPA sous macOS)

---

## 💻 Compilation avec Xcode

```bash
# Cloner le dépôt
git clone https://github.com/je-tu-il/BestCam.git
cd BestCam

# Installer XcodeGen si nécessaire
brew install xcodegen

# Générer le projet Xcode
xcodegen generate

# Ouvrir dans Xcode
open BestCam.xcodeproj
```

---

## 📄 Licence

Ce projet est distribué sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus d'informations.
