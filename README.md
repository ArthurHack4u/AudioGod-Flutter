# 🎧 AUDIO GOD - High Fidelity Equalizer

Aplicación móvil desarrollada en Flutter capaz de procesar audio y ecualizar frecuencias en tiempo real. Cuenta con una arquitectura híbrida para superar las limitaciones de sandboxing en iOS y Android.

## 📱 Características

* **Android:** Motor de Ecualización Global (afecta Spotify, YouTube, etc.) mediante inyección de Session ID.
* **iOS:** Motor nativo escrito en **Swift** (`AVAudioEngine`) para reproducción Bit-Perfect y EQ Paramétrico de 5 bandas.
* **Interfaz:** Diseño "Glassmorphism" (Liquid Glass) reactivo.
* **Persistencia:** Sistema de Singleton (`AudioBrain`) para mantener el estado de audio en background.

## 🛠 Tecnologías

* **Framework:** Flutter & Dart
* **Native iOS:** Swift (AVFoundation)
* **Native Android:** Kotlin (AudioFX Framework)
* **State Management:** Provider / Singleton Pattern

## 👥 Equipo de Desarrollo

Proyecto final presentado por:

| Nombre | Matrícula | Rol |
| :--- | :--- | :--- |
| **Moran Escalante Bryan Arturo** | 67406 | Lead Developer & Audio Engine |
| **Rafael Inurreta del Valle** | 62151 | UI/UX Design & Documentation |

---
© 2025 Audio God Project.