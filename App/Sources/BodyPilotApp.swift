import Coach
import Nutrition
import ProgressInsights
import SwiftData
import SwiftUI
import Training

@main
struct BodyPilotApp: App {
    private let container: ModelContainer

    init() {
        container = AppContainer.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

/// Accueil tant qu'il n'y a pas de profil, puis l'écran Aujourd'hui.
struct RootView: View {
    @Query(sort: \ProfileRecord.createdAt) private var profiles: [ProfileRecord]
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            if let failure = AppContainer.openFailure {
                StoreErrorView(details: failure)
            } else if let profile = profiles.first {
                TodayView(profileRecord: profile)
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            } else {
                OnboardingView()
                    .transition(.opacity)
            }

            if showsSplash {
                SplashView()
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
                    .zIndex(1)
            }
        }
        .animation(Theme.springy, value: profiles.isEmpty)
        .task {
            // Table Ciqual lue pendant l'écran de chargement : la première description de repas reste instantanée.
            Task.detached(priority: .utility) { MealTextParser.preload() }
            guard !LaunchOptions.demoHoldSplash else { return }
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeInOut(duration: 0.45)) { showsSplash = false }
        }
    }
}

/// La base locale ne s'ouvre pas : on le dit, sans créer un nouveau profil par-dessus.
struct StoreErrorView: View {
    let details: String

    var body: some View {
        ContentUnavailableView {
            Label("Tes données ne s'ouvrent pas", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Rien n'a été effacé. Mets l'app à jour ou redémarre l'iPhone, puis rouvre BodyPilot. Si le problème continue, garde ce message : il aide à trouver la cause.")
        } actions: {
            Text(details)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)
        }
        .padding()
    }
}

/// L'app assemble le coach avec les implémentations locales des modules.
enum CoachFactory {
    static let coach = DailyCoach(
        nutrition: MealPlanner(),
        training: TrainingPlanner(),
        progress: WeightTrendAnalyzer()
    )
}
