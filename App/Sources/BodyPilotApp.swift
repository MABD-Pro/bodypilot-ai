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
        container = AppContainer.make()
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
            if let profile = profiles.first {
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
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.easeInOut(duration: 0.45)) { showsSplash = false }
        }
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
