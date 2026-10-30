# Architecture

Voir [PRINCIPLES.md](PRINCIPLES.md) pour les exigences qui la motivent.

## Vue d'ensemble

```
App (SwiftUI, cible iOS)                ← UI, HealthKit, SwiftData, StoreKit, App Intents
 ├── BodyPilotWidgets (extension)       widgets, Centre de contrôle (App/Widgets)
 ├── App/Shared                         résumé du jour et intents, compilés dans les deux cibles
 └── Packages/BodyPilotKit (Swift Package, Swift 6)
      ├── BodyPilotCore     types partagés, protocoles        (aucune dépendance)
      ├── AIRouter          routage des traitements IA         → BodyPilotCore
      ├── Nutrition         programme alimentaire, repas       → BodyPilotCore, AIRouter
      ├── Training          programme sportif, séances         → BodyPilotCore
      ├── ProgressInsights  poids, mensurations, records       → BodyPilotCore
      └── Coach             orchestration, ajustements du jour → BodyPilotCore, AIRouter
```

## Règles

- **Modules découplés.** Nutrition, Training et ProgressInsights ne se connaissent pas. Le Coach les consomme via des protocoles déclarés dans BodyPilotCore ; l'App injecte les implémentations.
- **Domaine sans UI.** Les modules du package n'importent ni SwiftUI ni SwiftData. Ils restent testables sur Linux (CI) et réutilisables pour l'Apple Watch. La persistance (SwiftData) et les frameworks système vivent dans l'App, derrière des protocoles.
- **Schéma versionné.** La base SwiftData suit `SchemaV1` et `BodyPilotMigrationPlan` (App/Sources/Persistence/SchemaVersions.swift). Toute modification d'un modèle ajoute une version et une étape de migration ; une base qui ne s'ouvre pas affiche un écran d'erreur, jamais un plantage ni un effacement.
- **Jours enregistrés à midi.** Un jour (journal, série, test, début de cycle) s'enregistre à midi local (`Calendar.storedDay`), pour rester le même jour en voyage.
- **Local-first.** Les identifiants (`EntityID`) sont générés sur l'appareil. Le stockage local est la source de vérité ; la synchronisation viendra plus tard avec une gestion explicite des conflits.
- **Coût IA maîtrisé.** Toute demande passe par `AIRouter`, qui choisit le niveau le moins coûteux capable de la traiter (déterministe > embarqué > cloud éco > cloud avancé) et refuse le cloud quand le budget est atteint. Chaque appel à un modèle passe par `AIRouter.run`, qui produit un `AIUsageRecord` (niveau, tokens, coût, latence, succès) rangé dans un `AIUsageLedger` : l'app garde les 500 derniers sur l'iPhone (`AIUsageStore`, fichier `ai-usage.json`), et le budget cloud se compte sur le mois en cours. Fonctionnalités mesurées : `command-parsing`, `meal-description`, `meal-photo`, `meal-photo-labels`.
- **Widgets sans base.** L'extension n'ouvre jamais SwiftData. L'app écrit un résumé du jour (`TodaySnapshot`) dans le groupe d'apps `group.com.mabdpro.bodypilot` ; une touche sur un widget ou un bouton du Centre de contrôle dépose une action (`WidgetAction`), que l'app applique à son retour au premier plan (`WidgetBridge.applyPending`).
- **Diagnostics sous consentement.** Journaux `os.Logger` locaux (`AppLog`) ; Crashlytics et Analytics éteints tant que l'utilisateur n'a pas accepté, sans aucune donnée de santé (voir [TELEMETRY.md](TELEMETRY.md)). Firebase n'est importé que par l'App.
- **Fournisseurs remplaçables.** Aucun SDK de fournisseur IA dans les modules de domaine. Les appels cloud passeront par le backend (proxy), jamais avec une clé dans l'app.

## Cibles

- iOS 26 minimum (watchOS 26 pour la future app Watch).
- Apple Foundation Models : disponibilité vérifiée à l'exécution via `SystemLanguageModel.default.availability`, car iOS 26 tourne aussi sur des iPhone sans Apple Intelligence (ou avec Apple Intelligence désactivée). Si le modèle est indisponible, le niveau `onDevice` est retiré des niveaux disponibles du routeur, qui se replie sur le suivant.
- iPhone uniquement pour l'instant ; Apple Watch prévue.

## Décisions ouvertes

- Backend (auth, sync, proxy IA, quotas) : à comparer selon coût total, sécurité, maintenance.
- SwiftData ou Core Data : SwiftData par défaut, à confirmer quand la synchronisation sera conçue.
