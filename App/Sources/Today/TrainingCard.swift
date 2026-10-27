import BodyPilotCore
import SwiftUI
import Training
import WorkoutKit

/// « Quel entraînement dois-je effectuer ? »
struct TrainingCard: View {
    let training: TrainingDay
    /// Remplace l'exercice (par sa clé) par la variante suivante.
    var swap: (String) -> Void = { _ in }
    var isDone = false
    var toggleDone: () -> Void = {}

    @State private var isPreviewingWatch = false

    var body: some View {
        CoachCard(eyebrow: "Bouger", symbol: "figure.strengthtraining.functional", tint: Theme.training) {
            switch training.kind {
            case .workout(let workout):
                workoutContent(workout)
            case .activeRest(let title, let minutes):
                restContent(title: title, minutes: minutes)
            }

            ForEach(training.notes, id: \.self) { note in
                CoachNote(text: note, tint: Theme.training)
            }
        }
    }

    private func workoutContent(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(workout.title)
                        .font(.display(28))
                    Text("\(workout.exercises.count) exercices · \(workout.exercises.map(\.sets).reduce(0, +)) séries")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DurationBadge(minutes: training.estimatedMinutes)
            }

            VStack(spacing: 0) {
                ExerciseRow(index: 0, name: "Échauffement", detail: "\(workout.warmupMinutes) min", isWarmup: true)
                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                    ExerciseRow(
                        index: index + 1,
                        name: exercise.name,
                        detail: exercise.prescription,
                        isWarmup: false,
                        isSwapped: exercise.isSwapped,
                        swap: exercise.alternatives.isEmpty ? nil : { swap(exercise.key) }
                    )
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(workout.intensityCue, systemImage: "gauge.with.dots.needle.33percent")
                Label("Machine prise ou matériel absent ? Touche \(Image(systemName: "arrow.triangle.2.circlepath")) pour changer d'exercice.", systemImage: "hand.tap")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let plan = workout.guided.watchPlan {
                // La séance déjà adaptée (temps, fatigue, genou) part sur la montre, guidée série par série.
                Button {
                    isPreviewingWatch = true
                } label: {
                    Label("Envoyer sur ma Watch", systemImage: "applewatch")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.training)
                .workoutPreview(plan, isPresented: $isPreviewingWatch)
            }

            Button(action: toggleDone) {
                Label(isDone ? "Séance faite" : "J'ai fait ma séance", systemImage: isDone ? "checkmark.seal.fill" : "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDone ? Theme.progress : .primary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .sensoryFeedback(.success, trigger: isDone) { _, done in done }
        }
    }

    private func restContent(title: String, minutes: Int) -> some View {
        HStack(spacing: Theme.Spacing.l) {
            IconBadge(symbol: "figure.walk", tint: Theme.training, size: 52)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.display(24))
                Text("Bouger un peu aide à récupérer et à garder le cap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            DurationBadge(minutes: minutes)
        }
    }
}

private struct DurationBadge: View {
    let minutes: Int

    var body: some View {
        VStack(spacing: 0) {
            Text("\(minutes)")
                .font(.display(26))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(minutes)))
            Text("min")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 64, height: 64)
        .glassEffect(.regular.tint(Theme.training.opacity(0.35)), in: .circle)
    }
}

private struct ExerciseRow: View {
    let index: Int
    let name: String
    let detail: String
    let isWarmup: Bool
    var isSwapped = false
    var swap: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ZStack {
                Circle()
                    .fill(isWarmup ? Theme.carbs.opacity(0.18) : Theme.training.opacity(0.14))
                if isWarmup {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.carbs)
                } else {
                    Text("\(index)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.training)
                }
            }
            .frame(width: 28, height: 28)

            Text(name)
                .font(.subheadline.weight(.medium))
                .contentTransition(.opacity)
            Spacer()
            Text(detail)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let swap {
                Button(action: swap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSwapped ? Theme.training : .secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remplacer \(name)")
            }
        }
        .padding(.vertical, 7)
    }
}

extension WorkoutExercise {
    /// Remplacé à la demande, et non par une règle de sécurité (celles-ci vident les variantes).
    var isSwapped: Bool { name != key && !alternatives.isEmpty }

    var prescription: String {
        switch volume {
        case .reps(let reps): "\(sets) × \(reps)"
        case .seconds(let seconds): "\(sets) × \(seconds) s"
        }
    }
}
