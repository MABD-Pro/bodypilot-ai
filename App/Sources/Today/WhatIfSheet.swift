import BodyPilotCore
import ProgressInsights
import SwiftUI

/// « Et si ? » : quelques calories ou quelques pas de plus, et la fourchette d'arrivée bouge.
/// Simulation seulement : les calories du plan restent réglées par le bilan de la semaine.
struct WhatIfSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [WeightEntry]
    let trend: WeightTrend
    let targetKg: Double
    let now: Date
    @State private var scenario: ProjectionScenario

    init(entries: [WeightEntry], trend: WeightTrend, targetKg: Double, now: Date, scenario: ProjectionScenario = .none) {
        self.entries = entries
        self.trend = trend
        self.targetKg = targetKg
        self.now = now
        _scenario = State(initialValue: scenario)
    }

    private func projection(_ scenario: ProjectionScenario) -> WeightProjection? {
        WeightProjector.project(entries: entries, trend: trend, targetKg: targetKg, scenario: scenario, on: now)
    }

    var body: some View {
        let base = projection(.none)
        let simulated = projection(scenario)
        NavigationStack {
            Form {
                Section {
                    row(title: "À ton rythme actuel", weekly: trend.weeklyChangeKg, projection: base)
                } footer: {
                    Text("Fourchette tirée de tes pesées des 3 dernières semaines : plus elles sont régulières, plus elle se resserre.")
                }
                Section("Et si…") {
                    Stepper(value: $scenario.kcalPerDay, in: ProjectionScenario.kcalRange, step: ProjectionScenario.kcalStep) {
                        LabeledContent("Calories par jour", value: scenario.kcalPerDay == 0 ? "comme aujourd'hui" : "\(scenario.kcalPerDay > 0 ? "+" : "")\(Double(scenario.kcalPerDay).frenchInteger)\u{00A0}kcal")
                    }
                    Stepper(value: $scenario.extraSteps, in: ProjectionScenario.stepsRange, step: ProjectionScenario.stepsStep) {
                        LabeledContent("Pas en plus par jour", value: scenario.extraSteps == 0 ? "aucun" : "+\(Double(scenario.extraSteps).frenchInteger)")
                    }
                }
                if !scenario.isNone {
                    Section {
                        row(title: "Avec ce changement", weekly: simulatedWeekly, projection: simulated)
                        if let gain = gainText(base: base, simulated: simulated) {
                            Text(gain)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.progress)
                        }
                        if let weekly = simulatedWeekly, let weight = trend.currentTrendKg, WeightProjection.isFast(weeklyKg: weekly, weightKg: weight) {
                            Label("Rythme élevé : plus de 1\u{00A0}% de ton poids par semaine. Garde tes protéines et tes séances de force, elles protègent ton muscle.", systemImage: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    } footer: {
                        Text("Estimation : 7\u{202F}700\u{00A0}kcal par kilo, 0,04\u{00A0}kcal par pas et par 100\u{00A0}kg, et seulement 80\u{00A0}% du changement compté, car le corps en compense une partie (faim, mouvements spontanés). Tes calories du plan ne changent pas : le bilan de la semaine s'en occupe.")
                    }
                }
            }
            .navigationTitle("Et si ?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: scenario)
        }
    }

    private var simulatedWeekly: Double? {
        trend.weeklyChangeKg.map { $0 + WeightProjector.scenarioWeeklyKg(scenario, weightKg: trend.currentTrendKg ?? targetKg) }
    }

    private func row(title: String, weekly: Double?, projection: WeightProjection?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let projection {
                Text("\(targetKg.frenchOneDecimal)\u{00A0}kg \(projection.preciseRangeText())")
                    .font(.headline)
            } else {
                Text("Pas de date à ce rythme")
                    .font(.headline)
            }
            if let weekly {
                Text("\(weekly.frenchSignedOneDecimal)\u{00A0}kg par semaine")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// « Environ 3 semaines plus tôt », sur le milieu de la fourchette.
    private func gainText(base: WeightProjection?, simulated: WeightProjection?) -> String? {
        guard let base, let simulated else { return nil }
        let weeks = Int((base.middle.timeIntervalSince(simulated.middle) / (7 * 86_400)).rounded())
        if weeks == 0 { return "À peu près la même date." }
        let count = abs(weeks)
        return "Environ \(count) semaine\(count > 1 ? "s" : "") plus \(weeks > 0 ? "tôt" : "tard")."
    }
}
