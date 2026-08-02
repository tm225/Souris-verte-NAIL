# Matrix Launcher

Launcher Android thème "Matrix" (pluie de code verte animée) avec verrouillage
de l'écran d'accueil par empreinte digitale et animation de déverrouillage
(décodage de texte façon hacker + accélération de la pluie + glitch).

⚠️ **Limite technique importante** : Android interdit à une application tierce
de remplacer l'écran de verrouillage du système (celui du bouton power). Cette
appli verrouille donc **son propre écran d'accueil** : dès qu'on revient dessus
(après avoir quitté une autre appli), le capteur d'empreinte est demandé.

## Installer et lancer l'appli comme launcher par défaut

1. Installe l'APK généré.
2. Appuie sur le bouton "Accueil" du téléphone → Android proposera de choisir
   un launcher par défaut → sélectionne **Matrix Launcher**.
3. Pour revenir au launcher d'origine : Paramètres → Applications →
   Application par défaut → Application d'accueil.

## Générer l'APK sur GitHub (CI/CD)

Ce dépôt contient un workflow GitHub Actions (`.github/workflows/build-apk.yml`)
qui compile automatiquement l'APK à chaque `push` sur `main`.

### Étapes pour déployer :

```bash
cd matrix-launcher
git init
git add .
git commit -m "Matrix Launcher - version initiale"
git branch -M main
git remote add origin https://github.com/<ton-user>/<ton-repo>.git
git push -u origin main
```

Une fois le push effectué :

1. Va dans l'onglet **Actions** de ton dépôt GitHub → le workflow "Build APK"
   se lance automatiquement.
2. À la fin du build (~3-5 min), tu trouveras :
   - L'APK en téléchargement dans l'onglet **Actions → (le run) → Artifacts**
   - Une **Release** créée automatiquement (`build-1`, `build-2`, ...) contenant
     l'APK directement téléchargeable depuis l'onglet **Releases**.

Tu peux aussi déclencher un build manuellement depuis l'onglet Actions
(bouton "Run workflow"), grâce à `workflow_dispatch`.

### Build signée pour publication (optionnel)

L'APK généré ici est une **build debug**, installable directement mais non
signée pour le Play Store. Pour une build release signée, il faudra générer
un keystore et l'ajouter en secret GitHub (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
etc.) — dis-moi si tu veux que je t'ajoute cette étape.

## Structure du projet

```
app/src/main/java/com/matrixlauncher/theme/
├── MainActivity.kt       # écran d'accueil, verrouillage, animations
├── LockManager.kt        # authentification biométrique (BiometricPrompt)
├── MatrixRainView.kt     # fond animé "pluie de code"
├── AppAdapter.kt         # grille des applications installées
└── AppInfo.kt            # modèle de données d'une app
```
