# Journaux, plantages et statistiques d'usage

## Ce qui est en place

- **Journaux (`os.Logger`)** : `AppLog` (App/Sources/Diagnostics/AppLog.swift), une catégorie par domaine (`persistence`, `health`, `backup`, `telemetry`). Ils restent sur l'appareil, lisibles dans Console.app avec le filtre `subsystem:com.mabdpro.bodypilot`. Une valeur personnelle s'écrit en `privacy: .private`. Rien n'est recopié vers Crashlytics.
- **Firebase Crashlytics** : rapports de plantage, plus quelques erreurs sans plantage (base locale illisible, enregistrement Siri raté) réduites à leur domaine et leur code.
- **Firebase Analytics** : seulement les événements de `UsageEvent` (BodyPilotCore), sans aucun paramètre.

## Règles non négociables

1. **Consentement d'abord.** La collecte est coupée dans l'Info.plist (`FIREBASE_ANALYTICS_COLLECTION_ENABLED`, `FirebaseCrashlyticsCollectionEnabled` à `false`). Elle ne s'allume qu'après « Accepter » sur l'écran du premier lancement (`ConsentView`). Refuser est aussi simple qu'accepter (deux boutons identiques). Le choix se change dans Mon profil > Confidentialité ; couper efface les rapports pas encore envoyés et réinitialise l'identifiant Analytics.
2. **Aucune donnée de santé** (App Store 5.1.3) : ni valeur de Santé, ni poids, mensuration, repas, séance, charge, sommeil, cycle, ni ajustement qui décrit l'état physique (fatigue, douleur, courbatures), ni texte saisi. Un événement dit seulement qu'une fonction a servi. Les événements n'ont pas de paramètre et pas de propriété utilisateur.
3. **Pas de publicité ni de suivi** : consentement publicitaire toujours refusé, pas d'IDFA ni de mesure de conversion publicitaire (produit `FirebaseAnalyticsCore`, qui n'embarque ni `GoogleAdsOnDeviceConversion` ni `IdentitySupport`), pas d'IDFV, pas de SKAdNetwork, pas de rapport d'écrans automatique. Donc pas de demande App Tracking Transparency.
4. **Démo et CI n'envoient rien** : une option `-demo…` au lancement laisse Firebase éteint (`-demoConsent YES` affiche l'écran de consentement pour les captures).

Ajouter un événement = ajouter un cas à `UsageEvent` et vérifier qu'il respecte la règle 2.

## Événements

| Nom | Quand |
|---|---|
| `onboarding_completed` | Inscription terminée |
| `meal_described` | Repas décrit (texte, photo ou repris) enregistré |
| `watch_preview_opened` | « Envoyer sur ma Watch » touché |
| `weekly_checkin_applied` | Proposition du bilan de la semaine appliquée |
| `cycle_started` | Cycle d'entraînement démarré |

## GoogleService-Info.plist

Il n'est pas versionné (`.gitignore`). On le dépose dans `App/Config/GoogleService-Info.plist` ; une phase de build le copie dans l'app s'il existe. Sans lui, l'app et la CI compilent et Firebase n'est pas démarré. Le fichier vient de la console Firebase : projet « BodyPilot », app iOS `com.mabdpro.bodypilot`.

Une seconde phase envoie les symboles (dSYM) à Crashlytics quand le plist est là, sauf pour le simulateur. Un plantage survenu pendant que Xcode est attaché (⌘R) est intercepté par le débogueur : pour tester, lancer l'app depuis l'écran d'accueil.

## App Store Connect (confidentialité)

À déclarer, collectées sans lien avec l'identité et non utilisées pour le suivi : Données de plantage, Données de performance, Autres données de diagnostic (Crashlytics) ; Interaction avec le produit (Analytics). Le manifeste de confidentialité de Firebase est fourni par le SDK.
