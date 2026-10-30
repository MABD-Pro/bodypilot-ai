import ActivityKit
import AppIntents
import BodyPilotCore
import SwiftUI
import WidgetKit

/// Séance en cours : écran verrouillé et Dynamic Island.
struct WorkoutActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(attributes: context.attributes, progress: context.state.progress)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let progress = context.state.progress
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(WidgetTheme.training)
                        .font(.title3)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    RestOrElapsed(progress: progress, startedAt: context.attributes.startedAt)
                        .font(.title3.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(progress.current?.name ?? context.attributes.title)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        SetLabel(progress: progress)
                        Spacer()
                        Button(intent: CompleteSetIntent()) {
                            Label("Série faite", systemImage: "checkmark")
                        }
                        .tint(WidgetTheme.training)
                    }
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(WidgetTheme.training)
            } compactTrailing: {
                RestOrElapsed(progress: progress, startedAt: context.attributes.startedAt, compact: true)
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(WidgetTheme.training)
            }
        }
    }
}

private struct WorkoutLockScreenView: View {
    let attributes: WorkoutActivityAttributes
    let progress: SessionProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(attributes.title, systemImage: "dumbbell.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.training)
                    .lineLimit(1)
                Spacer()
                Text(attributes.startedAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70, alignment: .trailing)
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progress.current?.name ?? "Séance terminée")
                        .font(.headline)
                        .lineLimit(1)
                    SetLabel(progress: progress)
                    if let next = progress.next {
                        Text("Ensuite : \(next.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                RestOrElapsed(progress: progress, startedAt: nil)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
            }
            ProgressView(value: progress.fractionDone)
                .tint(WidgetTheme.training)
            HStack(spacing: 8) {
                Button(intent: CompleteSetIntent()) {
                    Label("Série faite", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WidgetTheme.training)
                Button(intent: SkipExerciseIntent()) {
                    Image(systemName: "forward.fill")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Exercice suivant")
                Button(intent: FinishWorkoutIntent()) {
                    Image(systemName: "flag.checkered")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Terminer la séance")
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

/// « Série 2 sur 4 · 3 × 10 ».
private struct SetLabel: View {
    let progress: SessionProgress

    var body: some View {
        if let current = progress.current {
            Text("Série \(progress.setNumber) sur \(current.sets) · \(current.detail)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

/// Le repos qui décompte s'il y en a un, sinon rien (ou la durée de la séance en compact).
private struct RestOrElapsed: View {
    let progress: SessionProgress
    let startedAt: Date?
    var compact = false

    var body: some View {
        if let end = progress.restEndsAt, end > .now {
            Text(timerInterval: Date.now...end, countsDown: true)
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.nutrition)
                .frame(maxWidth: compact ? 44 : 90, alignment: .trailing)
                .accessibilityLabel("Repos")
        } else if let startedAt {
            Text(startedAt, style: .timer)
                .monospacedDigit()
                .frame(maxWidth: compact ? 44 : 90, alignment: .trailing)
        }
    }
}
