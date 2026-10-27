// swift-tools-version: 6.2
import PackageDescription

// Modules de domaine BodyPilot.
// Règle : ces cibles n'importent ni SwiftUI ni SwiftData, pour rester testables
// sur Linux (CI) et indépendantes de l'interface. L'UI vit dans la cible App.
let package = Package(
    name: "BodyPilotKit",
    platforms: [
        .iOS(.v26),
        .macOS(.v26),
        .watchOS(.v26),
    ],
    products: [
        .library(name: "BodyPilotCore", targets: ["BodyPilotCore"]),
        .library(name: "AIRouter", targets: ["AIRouter"]),
        .library(name: "Nutrition", targets: ["Nutrition"]),
        .library(name: "Training", targets: ["Training"]),
        .library(name: "ProgressInsights", targets: ["ProgressInsights"]),
        .library(name: "Coach", targets: ["Coach"]),
    ],
    targets: [
        .target(name: "BodyPilotCore"),
        .target(name: "AIRouter", dependencies: ["BodyPilotCore"]),
        .target(name: "Nutrition", dependencies: ["BodyPilotCore", "AIRouter"]),
        .target(name: "Training", dependencies: ["BodyPilotCore"]),
        .target(name: "ProgressInsights", dependencies: ["BodyPilotCore"]),
        .target(name: "Coach", dependencies: ["BodyPilotCore", "AIRouter"]),

        .testTarget(name: "BodyPilotCoreTests", dependencies: ["BodyPilotCore"]),
        .testTarget(name: "AIRouterTests", dependencies: ["AIRouter"]),
        .testTarget(name: "NutritionTests", dependencies: ["Nutrition", "AIRouter"]),
        .testTarget(name: "TrainingTests", dependencies: ["Training"]),
        .testTarget(name: "ProgressInsightsTests", dependencies: ["ProgressInsights"]),
        .testTarget(name: "CoachTests", dependencies: ["Coach", "Nutrition", "Training", "ProgressInsights"]),
    ],
    swiftLanguageModes: [.v6]
)
