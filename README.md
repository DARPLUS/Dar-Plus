# dar_plus

## Exécuter Android depuis OneDrive

Gardez le projet à son emplacement actuel. Pour éviter les fichiers intermédiaires Gradle verrouillés par OneDrive, construisez l’APK dans `%LOCALAPPDATA%`, puis lancez cet APK sur l’émulateur. Dans PowerShell, depuis la racine du projet :

```powershell
$env:DARPLUS_BUILD_DIR = Join-Path $env:LOCALAPPDATA 'DarPlusBuild'
flutter build apk --debug --target-platform android-x64
$apk = Join-Path $env:DARPLUS_BUILD_DIR 'app\outputs\flutter-apk\app-debug.apk'
flutter run -d emulator-5554 --use-application-binary $apk
```

Le dossier du projet ne bouge pas. Remplacez `emulator-5554` par l’identifiant affiché par `flutter devices` si nécessaire. Pour un appareil physique, adaptez `android-x64` à son architecture.

La connexion Google sur Android nécessite aussi que le fournisseur Google soit activé dans Firebase Authentication, que l’empreinte SHA-1 de l’application soit enregistrée dans les paramètres Firebase, et qu’un nouveau `google-services.json` contenant le client OAuth Web soit téléchargé dans `android/app`.

## Dar Plus AI

Dar Plus AI utilise Firebase AI Logic avec Gemini, Firebase Authentication, Cloud Firestore, App Check et les traductions existantes. Après récupération des dépendances, activez Firebase AI Logic dans la console Firebase et vérifiez que les règles Firestore sont déployées :

```powershell
flutter pub get
firebase deploy --only firestore:rules
```

Les utilisateurs doivent être authentifiés pour utiliser l'assistant. Les conversations sont enregistrées sous `users/{uid}/ai_conversations` et les règles Firestore limitent leur accès à leur propriétaire. Les recommandations ne proviennent que des professionnels approuvés dans Firestore; aucune donnée de démonstration ni aucun tarif de remplacement n'est utilisé.

En développement, App Check utilise le fournisseur de débogage : enregistrez son jeton affiché par l'application dans la console Firebase. En production, configurez le fournisseur App Check correspondant à chaque plateforme (Play Integrity, App Attest/DeviceCheck ou reCAPTCHA v3 sur le Web) et activez l'application des règles après validation. Pour construire le Web, fournissez la clé de site reCAPTCHA publique :

```powershell
flutter build web --dart-define=DARPLUS_RECAPTCHA_V3_SITE_KEY=<site-key>
```

La clé de site reCAPTCHA est publique; ne placez aucune clé secrète dans le code Flutter. La configuration des fournisseurs et l'activation de Firebase AI Logic doivent être effectuées dans la console Firebase du projet.

## Paiements Sandbox et commissions

Le parcours de réservation ouvre le paiement uniquement après l'acceptation du professionnel. Les paiements en ligne du projet sont actuellement une **simulation Sandbox** : aucune transaction Konnect réelle, aucun webhook de passerelle et aucun partage ou reversement automatique aux professionnels ne sont actifs. Les commissions sont donc un ledger comptable de démonstration; un transfert réel nécessite un prestataire et un compte marchand autorisés pour les paiements marketplace.

Les fonctions Cloud Functions calculent la commission à partir du tarif de la réservation dans Firestore, du taux configuré et de la remise validée côté serveur. Le taux initial est de 10 %, modifiable par un Super Admin uniquement, avec une plage autorisée de 0 à 30 %. Les paiements confirmés créent un document dans `payments` et, pour une prestation, une entrée dans `platform_commissions`; une notification détaillée est envoyée aux comptes Admin et Super Admin. L'interface professionnelle n'affiche que les paiements et commissions du professionnel connecté.

Après l'acceptation d'une réservation, le client et le professionnel peuvent échanger des messages en temps réel dans `bookings/{bookingId}/messages`. Les règles Firestore autorisent uniquement ces deux participants à lire et envoyer des messages et bloquent l'accès avant acceptation.

### Tester les paiements avec Firebase Emulator Suite

Le projet peut tester les paiements sans déployer de Cloud Function ni activer la facturation Firebase. Ce mode utilise le projet local isolé `demo-darplus-local`; il ne se connecte pas aux ressources Firebase de production.

1. Dans une première fenêtre PowerShell, démarrez les émulateurs Auth, Firestore et Functions :

```powershell
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
firebase emulators:start --only auth,firestore,functions --project demo-darplus-local
```

2. Dans une deuxième fenêtre PowerShell, créez un client, un professionnel approuvé, un Super Admin et une réservation déjà acceptée dans Firestore Emulator. Le script refuse de s'exécuter hors d'un projet `demo-*` avec les émulateurs Auth et Firestore actifs.

```powershell
$env:GCLOUD_PROJECT = 'demo-darplus-local'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
npm --prefix functions run seed:emulator
```

Le script affiche des mots de passe temporaires pour les comptes locaux `client@local.test` et `pro@local.test`. Utilisez-les uniquement avec les émulateurs.

3. Construisez puis installez l'APK sur les deux appareils en activant explicitement le mode local :

```powershell
$env:DARPLUS_BUILD_DIR = Join-Path $env:LOCALAPPDATA 'DarPlusBuildEmulator'
flutter build apk --debug --target-platform android-x64 --dart-define=DARPLUS_USE_FIREBASE_EMULATORS=true
$apk = Join-Path $env:DARPLUS_BUILD_DIR 'app\outputs\flutter-apk\app-debug.apk'
flutter run -d emulator-5554 --use-application-binary $apk --no-resident
flutter run -d emulator-5556 --use-application-binary $apk --no-resident
```

Connectez le client sur un émulateur, ouvrez la réservation `demo-payment-booking` dans **Réservations** et testez le paiement Sandbox. Le deuxième compte permet de vérifier les écrans du professionnel. Fermez les émulateurs Firebase dans leur fenêtre PowerShell avec `Ctrl+C` lorsque le test est terminé.

### Installation et déploiement

1. Activez Cloud Functions, Firestore, Firebase Authentication et App Check dans le projet Firebase. Les profils utilisateurs doivent avoir un champ `role` parmi `client`, `professionnel`, `admin` ou `super_admin`.
2. Depuis la racine du dépôt, installez les dépendances et lancez les tests locaux :

```powershell
flutter pub get
npm --prefix functions install
npm --prefix functions test
```

3. Configurez et validez App Check pour les plateformes de l'application. Les fonctions de paiement refusent les appels sans jeton App Check valide.
4. Après validation des paramètres Firebase et de l'environnement Sandbox, déployez :

```powershell
firebase deploy --only functions,firestore:rules
```

Les fonctions ciblent Node.js 20. Les tests `npm --prefix functions test` vérifient le calcul, les taux 0/5/10 %, les remises, les rôles et les états Sandbox, mais ne remplacent pas un test de bout en bout avec les émulateurs Firebase ni les tests d'intégration d'une véritable passerelle. N'activez pas de paiements réels avant l'implémentation et la vérification serveur du prestataire, notamment son webhook signé et son mécanisme de versement.

