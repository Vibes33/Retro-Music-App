📖 README — Retro Music App

🎵 Description

Retro Music App est une application iOS minimaliste et moderne qui permet d’importer, gérer et écouter sa musique locale, avec une expérience fluide inspirée d’Apple Music mais construite 100% en SwiftUI.
Elle propose un mini-player persistant, une gestion complète de la lecture (progression, pause/reprise, précédent/suivant), et une vue lecteur plein écran avec un design type iOS 26 liquid glass.

⸻

🚀 Fonctionnalités actuelles

✅ Import de fichiers audio dans une base locale (CoreData/SwiftData).

✅ Affichage des morceaux sous forme de rectangles cliquables.

✅ Suppression sécurisée avec alerte de confirmation.

✅ Mini-player :
	•	Progress bar en temps réel.
	•	Boutons Play/Pause, Next, Previous.
	•	Tap → ouvre la sheet lecteur.
✅ Support multi-formats audio (MP3, WAV, AAC ...).

✅ Lecteur plein écran (FullPlayerSheet) :
	•	Titre et artiste du morceau en cours.
	•	Artwork affiché en grand (même radius que la maquette).
	•	Barre de progression + temps écoulé/restant.
	•	Scrubbing (on peut avancer/reculer).
	•	Boutons ⏮ / ▶︎/⏸ / ⏭ avec états désactivés si indispo.
	•	Repeat One (lecture en boucle d’un titre).

✅ Intégration système iOS :
	•	Lecture en arrière-plan (Background Audio activé).
	•	Contrôles depuis Lock Screen et Dynamic Island (Play/Pause/Next/Previous, scrubbing).
	•	Compatibilité AirPods (tap gestures → RemoteCommandCenter).

⸻

🛠️ Technologies utilisées
	•	Swift 6.2
	•	SwiftUI pour l’UI déclarative.
	•	AVFoundation / AVAudioPlayer pour la lecture audio.
	•	SwiftData pour la persistance locale (titres importés, métadonnées).
	•	MediaPlayer (MPNowPlayingInfoCenter, MPRemoteCommandCenter) pour l’intégration système (lockscreen / dynamic island).
	•	Xcode 26 (target iOS 26).

⸻

📂 Architecture
	•	AudioLibrary.swift → gestion des fichiers importés et suppression.
	•	Models.swift → modèles SwiftData (Track, Tag…).
	•	PlayerManager.swift → moteur de lecture (ObservableObject).
	•	MusicView.swift → liste des morceaux + mini-player + sheet lecteur.
	•	FullPlayerSheet.swift → lecteur plein écran (glass style).
	•	RetroApp.swift → injection des dépendances (PlayerManager, AudioLibrary).

⸻

🗺️ Roadmap (ce qu’il reste à faire)

🔲 Mode Shuffle / Repeat All
🔲 Playlists (création et gestion de listes personnalisées).
🔲 Recherche & filtres avancés dans la bibliothèque.
🔲 Animations plus riches (liquid glass, transitions fluides).
🔲 Export/backup de la base locale.
🔲 Dark/Light mode custom plus poussé.

⸻

📸 Aperçu

![HomeView](https://github.com/Vibes33/Retro-Music-App/blob/main/IMG_1437.PNG)

⸻

👤 Auteur

Développé par Ryan Delépine (@Vibes33).

⸻
