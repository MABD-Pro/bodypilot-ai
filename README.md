# BodyPilot AI

Coach personnel iOS pour la nutrition, l'entraînement et la progression. **Coach-first, pas tracking-first** : à l'ouverture, l'app répond à « que manger », « quel entraînement », « est-ce que je progresse », et s'adapte en une phrase (« je n'ai que 20 minutes », « je mange au restaurant »…).

- [Principes fondateurs](docs/PRINCIPLES.md) (non négociables)
- [Architecture](docs/ARCHITECTURE.md)

## Stack

Swift 6, SwiftUI, local-first, backend léger, IA hybride via un routeur de coût (déterministe > embarqué > cloud éco > cloud avancé).

## Démarrer

Prérequis : Xcode 26 ou plus récent (iOS 26 minimum), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open BodyPilot.xcodeproj
```

Le `.xcodeproj` est généré depuis `project.yml` et n'est pas versionné. Choisis ton équipe de signature dans Xcode (ou renseigne `DEVELOPMENT_TEAM` dans `project.yml`).

Tests des modules de domaine, sans Xcode :

```sh
cd Packages/BodyPilotKit
swift test
```

## Structure

```
App/                     cible iOS SwiftUI
Packages/BodyPilotKit/   modules de domaine (Core, AIRouter, Nutrition, Training, ProgressInsights, Coach)
docs/                    principes et architecture
project.yml              définition XcodeGen
```
