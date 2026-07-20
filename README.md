# Une Souris Verte — comptine interactive 3D

Jeu 3D pour enfant (3 ans) basé sur Godot 4.3. L'enfant tape sur l'élément
en surbrillance pour faire avancer la comptine "Une souris verte", étape
par étape, avec narration vocale en français (TTS natif de Godot/Android).

## Structure du projet

```
project.godot              → configuration du projet
scenes/Main.tscn           → scène principale (caméra, lumière, UI, decor)
scripts/Main.gd            → cœur de la logique : les 7 étapes de la comptine
scripts/GameState.gd       → singleton de progression (étape courante)
scripts/VoiceNarrator.gd   → singleton narration vocale (DisplayServer.tts_speak)
assets/                    → icône, environnement 3D par défaut
export_presets.cfg         → préréglage d'export Android
.github/workflows/         → compilation APK automatique via GitHub Actions
```

## Comment ça marche

Chaque étape de la comptine est définie dans `Main.gd` (tableau `STEPS`) :
un texte narré, une couleur de halo, et une fonction qui construit la scène
3D avec des primitives Godot (sphères, cylindres, capsules) — pas besoin
de modèles `.glb` externes pour démarrer. L'enfant tape sur l'objet en
surbrillance (halo lumineux pulsant) ; un raycast depuis la caméra détecte
le tap et déclenche la progression vers l'étape suivante.

Aucune progression automatique : si l'enfant ne tape pas, le halo pulse
plus fort après quelques secondes, mais le jeu attend toujours l'interaction.

## Compiler l'APK

### En local (si Godot est installé)
1. Ouvrir le projet dans Godot 4.3.
2. Éditeur → Gérer les modèles d'export → installer les templates Android.
3. Configurer un keystore Android dans Éditeur → Paramètres → Export → Android.
4. Projet → Exporter → Android → Exporter le projet.

### Automatiquement via GitHub Actions
Le workflow `.github/workflows/export-android.yml` se déclenche à chaque
push sur `main` (ou manuellement via l'onglet Actions → "Export Android
APK" → "Run workflow"). Il :
1. Télécharge Godot 4.3 headless + les templates d'export Android.
2. Génère un keystore de debug (signature automatique).
3. Exporte l'APK en mode debug.
4. Publie `souris-verte.apk` en artifact téléchargeable depuis l'onglet
   Actions du dépôt.

> Note : l'APK généré est signé avec un keystore **debug**, adapté aux
> tests et au sideload direct. Pour publier sur le Play Store, il faudra
> un keystore de release dédié (à ajouter en secret GitHub).

## Prochaines étapes possibles
- Remplacer les primitives par des modèles `.glb` low-poly plus détaillés.
- Ajouter des sons (couinement, plouf, éclaboussure) via `AudioStreamPlayer3D`.
- Ajouter d'autres comptines en dupliquant le tableau `STEPS`.
