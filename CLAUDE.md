# BodyPilot AI — consignes pour les agents

- Lire `docs/PRINCIPLES.md` avant toute décision : ils sont non négociables. Chaque fonctionnalité passe le critère de validation (section 3).
- Respecter les règles de `docs/ARCHITECTURE.md` : modules du package sans SwiftUI/SwiftData, Coach découplé via protocoles de BodyPilotCore, tout traitement IA via `AIRouter`.
- Le `.xcodeproj` est généré par XcodeGen : modifier `project.yml`, jamais le projet.
- Les conteneurs cloud n'ont pas de toolchain Swift : la CI GitHub est la vérification de référence (package : `swift build` / `swift test` sur Linux ; app : XcodeGen + `xcodebuild` sur macOS).
- Documentation et messages de commit en français.
