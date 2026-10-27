import Coach
import SwiftUI

/// Écran principal : répond aux trois questions du jour. Contenu à venir.
struct TodayView: View {
    var body: some View {
        NavigationStack {
            List(DailyQuestion.allCases, id: \.self) { question in
                Section(question.title) {
                    Text("À venir")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Aujourd'hui")
        }
    }
}

private extension DailyQuestion {
    var title: LocalizedStringKey {
        switch self {
        case .whatToEat: "Que dois-je manger aujourd'hui ?"
        case .whichWorkout: "Quel entraînement dois-je effectuer ?"
        case .amIProgressing: "Est-ce que je progresse ?"
        }
    }
}

#Preview {
    TodayView()
}
