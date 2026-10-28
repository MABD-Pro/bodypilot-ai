import BodyPilotCore
import SwiftData
import SwiftUI
import Training

/// Cycle de 12 semaines : le commencer, voir où l'on en est, l'arrêter.
struct CycleSheet: View {
    @Bindable var profile: ProfileRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    if let week = profile.cycle?.week(on: .now, calendar: calendar) {
                        current(week)
                    } else {
                        intro
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .navigationTitle("Cycle de 12 semaines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Vers le CrossFit")
                .font(.display(28))
            Text("Trois phases de 4 semaines : base, puissance, conditioning. Dans chaque phase, la force monte 3 semaines, puis une semaine allégée laisse retomber la fatigue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            weekTable
            Text("Le coach du jour garde la main : fatigue, nuit courte ou genou sensible allègent la séance. Les charges partent de ton max, recalculé à chaque série notée.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                profile.cycle = TrainingCycle(program: .crossfit, startDate: calendar.startOfDay(for: .now))
                try? context.save()
                dismiss()
            } label: {
                Text("Commencer aujourd'hui")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
        }
    }

    private func current(_ week: CycleWeek) -> some View {
        let plan = StrengthCycle.prescription(for: week)
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Semaine \(week.number) sur \(TrainingCycle.weeks)")
                    .font(.display(28))
                Text(week.isDeload ? "Semaine allégée, phase \(week.phase) (\(week.phaseTitle))" : "Phase \(week.phase), \(week.phaseTitle)")
                    .font(.headline)
                    .foregroundStyle(Theme.training)
            }
            ProgressView(value: Double(week.number), total: Double(TrainingCycle.weeks))
                .tint(Theme.training)
            Text("Cette semaine : \(plan.sets) × \(plan.reps) à environ \(Int((plan.percentOfMax * 100).rounded())) % de ton max sur les mouvements principaux, \(plan.repsInReserve) répétitions en réserve.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            weekTable
            Button("Arrêter le cycle", role: .destructive) {
                profile.cycle = nil
                try? context.save()
                dismiss()
            }
            .buttonStyle(.glass)
        }
    }

    /// Les 4 semaines d'une phase, identiques d'une phase à l'autre.
    private var weekTable: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(1...TrainingCycle.weeksPerPhase, id: \.self) { number in
                let week = CycleWeek(program: .crossfit, number: number)
                let plan = StrengthCycle.prescription(for: week)
                HStack {
                    Text(week.isDeload ? "Semaine \(number), allégée" : "Semaine \(number)")
                        .font(.subheadline)
                    Spacer()
                    Text("\(plan.sets) × \(plan.reps) · ~\(Int((plan.percentOfMax * 100).rounded())) %")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }
}
