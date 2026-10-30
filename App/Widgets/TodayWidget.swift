import AppIntents
import SwiftUI
import WidgetKit

struct TodayEntry: TimelineEntry {
    var date: Date
    /// `nil` : l'app n'a pas encore préparé la journée.
    var snapshot: TodaySnapshot?
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: context.isPreview ? (SharedStore.snapshot ?? .preview) : current()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // À minuit le résumé de la veille ne vaut plus : le widget invite à ouvrir l'app.
        let midnight = Calendar.current.nextDate(after: .now, matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [TodayEntry(date: .now, snapshot: current())], policy: .after(midnight)))
    }

    private func current() -> TodaySnapshot? {
        SharedStore.snapshot.flatMap { $0.isCurrent() ? $0 : nil }
    }
}

/// Le jour en un coup d'œil : séance, calories restantes, prochain repas à cocher.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetBridgeReload.todayKind, provider: TodayProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aujourd'hui")
        .description("Ta séance, tes calories restantes et le prochain repas, à cocher d'une touche.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: medium(snapshot)
            case .accessoryRectangular: rectangular(snapshot)
            case .accessoryCircular: circular(snapshot)
            default: small(snapshot)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(WidgetTheme.nutrition)
                Text("Ouvre BodyPilot pour préparer ta journée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Écran d'accueil

    private func small(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            kcalBlock(snapshot)
            Spacer(minLength: 0)
            training(snapshot, compact: true)
            mealButton(snapshot)
        }
    }

    private func medium(_ snapshot: TodaySnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                kcalBlock(snapshot)
                Text("\(snapshot.proteinEaten) / \(snapshot.proteinTarget) g de protéines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                mealButton(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                training(snapshot, compact: false)
                Spacer(minLength: 0)
                workoutButton(snapshot)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func kcalBlock(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(snapshot.kcalLeft.frenchGrouped)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text("kcal restantes")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetTheme.nutrition)
        }
    }

    private func training(_ snapshot: TodaySnapshot, compact: Bool) -> some View {
        Label {
            Text(snapshot.trainingLine)
                .lineLimit(compact ? 1 : 2)
                .strikethrough(snapshot.workoutDone)
        } icon: {
            Image(systemName: snapshot.workoutDone ? "checkmark.circle.fill" : snapshot.trainingSymbol)
                .foregroundStyle(WidgetTheme.training)
        }
        .font(.caption.weight(.semibold))
    }

    @ViewBuilder
    private func mealButton(_ snapshot: TodaySnapshot) -> some View {
        if let meal = snapshot.nextMeal {
            Button(intent: TakeMealIntent(slot: meal.slot)) {
                Label("\(meal.name) pris", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WidgetTheme.nutrition)
            .accessibilityLabel("\(meal.name) pris comme prévu")
        } else {
            Label("Repas du jour notés", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetTheme.progress)
        }
    }

    @ViewBuilder
    private func workoutButton(_ snapshot: TodaySnapshot) -> some View {
        if snapshot.workoutTitle != nil, !snapshot.workoutDone {
            Button(intent: MarkWorkoutDoneIntent()) {
                Label("Séance faite", systemImage: "checkmark.seal")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WidgetTheme.training)
        } else if snapshot.workoutDone {
            Label("Séance cochée", systemImage: "checkmark.seal.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WidgetTheme.progress)
        }
    }

    // MARK: - Écran verrouillé

    private func rectangular(_ snapshot: TodaySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(snapshot.kcalLeft.frenchGrouped) kcal restantes")
                .font(.headline)
                .monospacedDigit()
            Text(snapshot.trainingLine)
                .font(.caption)
                .lineLimit(1)
            if let meal = snapshot.nextMeal {
                Text("Ensuite : \(meal.name.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
    }

    private func circular(_ snapshot: TodaySnapshot) -> some View {
        Gauge(value: Double(min(snapshot.kcalEaten, snapshot.kcalTarget)), in: 0...Double(max(snapshot.kcalTarget, 1))) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text("\(snapshot.kcalLeft)")
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityLabel("\(snapshot.kcalLeft) kcal restantes")
    }
}

extension TodaySnapshot {
    /// Journée type, pour la galerie des widgets.
    static var preview: TodaySnapshot {
        TodaySnapshot(
            day: .now, workoutTitle: "Full body A", trainingLine: "Full body A · 45 min", trainingSymbol: "dumbbell.fill",
            workoutDone: false, kcalTarget: 2_150, kcalEaten: 910, proteinTarget: 170, proteinEaten: 72,
            meals: [
                Meal(slot: "breakfast", name: "Petit-déjeuner", symbol: "sunrise.fill", kcal: 520, eaten: true),
                Meal(slot: "lunch", name: "Déjeuner", symbol: "sun.max.fill", kcal: 680, eaten: false),
            ]
        )
    }
}
