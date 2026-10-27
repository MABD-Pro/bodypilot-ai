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

## Design

Design system dans `App/Sources/DesignSystem` : une couleur par question du jour (corail pour manger, bleu pour bouger, vert pour progresser), typographie SF arrondie, cartes en Liquid Glass sur un fond dégradé. L'icône et le logo de lancement sont générés par `scripts/generate_brand_assets.py`.

La CI capture les écrans clés sur simulateur avec des données de démo (`scripts/ci-screenshots.sh`) : artefact `captures` de chaque exécution. En local, les mêmes options de lancement fonctionnent dans le schéma Xcode : `-demoData YES`, `-demoOnboarding YES`, `-demoAdjustments tired,shortOnTime`.

## Structure

```
App/                     cible iOS SwiftUI
Packages/BodyPilotKit/   modules de domaine (Core, AIRouter, Nutrition, Training, ProgressInsights, Coach)
docs/                    principes, architecture, règles du coach
scripts/                 captures CI, génération de l'icône
project.yml              définition XcodeGen
```
