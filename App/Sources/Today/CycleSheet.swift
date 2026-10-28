import BodyPilotCore
import SwiftData
import SwiftUI
import Training

/// Cycle de 12 semaines : le commencer, voir où l'on en est, l'arrêter.
struct CycleSheet: View {
    @Bindable var profile: ProfileRecord

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var program: CycleProgram = LaunchOptions.demoHyrox ? .hyrox : .crossfit
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
            Picker("Objectif", selection: $program.animation(.snappy)) {
                Text("CrossFit").tag(CycleProgram.crossfit)
                Text("Hyrox").tag(CycleProgram.hyrox)
            }
            .pickerStyle(.segmented)
            Text(program == .hyrox ? "Vers un premier Hyrox" : "Vers le CrossFit")
                .font(.display(28))
            Text(program == .hyrox
                ? "8 km de course entre 8 ateliers : la course passe au premier plan, avec une progression prudente. Phase 1 : courir-marcher ; phase 2 : courir en continu ; phase 3 : courir fatigué, entre les ateliers. La force reste, en 2 séances au plus, au service des ateliers."
                : "Trois phases de 4 semaines : base, puissance, conditioning. Dans chaque phase, la force monte 3 semaines en 5/3/1, puis une semaine allégée laisse retomber la fatigue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
            weekTable(program)
            phases(program)
            Text("Mouvements à la barre en 5/3/1 : 3 séries qui montent, la dernière au maximum de répétitions propres (1 en réserve), puis 5 × 5 à la charge de la première. Les pourcentages portent sur un max d'entraînement à 90 % de ton max, recalculé à chaque série notée. Le coach du jour garde la main : fatigue, nuit courte ou genou sensible allègent la séance.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                profile.cycle = TrainingCycle(program: program, startDate: calendar.storedDay(for: .now))
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
            Text("Cette semaine, à la barre : \(Self.waveText(week)) du max d'entraînement\(week.isDeload ? ", rien au maximum." : ", la dernière série au maximum, puis 5 × 5.")")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            weekTable(week.program)
            phases(week.program)
            Button("Arrêter le cycle", role: .destructive) {
                profile.cycle = nil
                try? context.save()
                dismiss()
            }
            .buttonStyle(.glass)
        }
    }

    /// Les 4 semaines d'une phase, identiques d'une phase à l'autre.
    private func weekTable(_ program: CycleProgram) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(1...TrainingCycle.weeksPerPhase, id: \.self) { number in
                let week = CycleWeek(program: program, number: number)
                HStack {
                    Text(week.isDeload ? "Semaine \(number), allégée" : "Semaine \(number)")
                        .font(.subheadline)
                    Spacer()
                    Text(Self.waveText(week))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
            }

    /// « 5 à 65 %, 5 à 75 %, 5+ à 85 % », en pourcentages du max d'entraînement.
    static func waveText(_ week: CycleWeek) -> String {
        StrengthCycle.wave(for: week).map { set in
            "\(set.reps)\(set.isPlus ? "+" : "") à \(Int((set.percentOfMax / StrengthCycle.trainingMaxShare * 100).rounded())) %"
        }.joined(separator: ", ")
    }

    /// Les 3 phases, qui reprennent ces 4 semaines avec des charges recalculées.
    private func phases(_ program: CycleProgram) -> some View {
        Text(program == .hyrox
            ? "Force : ces 4 semaines dans chaque phase. Course facile, séance de qualité (rameur, puis 1 km à allure Hyrox, puis course enchaînée) et fondamentaux des ateliers montent de semaine en semaine. Test 1 km + 50 wall balls + 1 km en semaines 1 et 11."
            : "Phase 1, base : semaines 1 à 4 · phase 2, puissance : 5 à 8 · phase 3, conditioning : 9 à 12. Chaque phase reprend ces 4 semaines, avec des charges recalculées sur ton max.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
