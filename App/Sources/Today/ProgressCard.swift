import BodyPilotCore
import Charts
import Coach
import ProgressInsights
import SwiftUI

/// Lien avec l'app Santé pour les pesées.
enum HealthLink {
    case unavailable
    case off
    case on
}

/// « Est-ce que je progresse vers mon objectif ? »
struct ProgressCard: View {
    let trend: WeightTrend
    let message: String
    let profile: UserProfile
    let health: HealthLink
    let checkIn: CalorieSuggestion?
    let consistency: WeeklyConsistency
    let addWeight: () -> Void
    let acceptCheckIn: () -> Void
    let dismissCheckIn: () -> Void
    let connectHealth: () -> Void
    let disconnectHealth: () -> Void

    var body: some View {
        CoachCard(eyebrow: "Progresser", symbol: "chart.line.downtrend.xyaxis", tint: Theme.progress) {
            HStack(alignment: .firstTextBaseline) {
                if let current = trend.currentTrendKg {
                    Text(current.frenchOneDecimal)
                        .font(.display(44))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: current))
                    Text("kg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Première pesée")
                        .font(.display(28))
                }
                Spacer()
                if let weekly = trend.weeklyChangeKg {
                    Tag(text: "\(weekly > 0 ? "+" : "")\(weekly.frenchOneDecimal) kg/sem.", symbol: weekly < 0 ? "arrow.down.right" : "arrow.up.right", tint: trend.status.tint)
                }
            }

            // Le bilan reprend le constat de la tendance : on ne le répète pas au-dessus.
            if let checkIn {
                checkInBox(checkIn)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(message)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            consistencyRow

            if trend.points.count >= 2 {
                chart
                    .frame(height: 150)
            }

            healthRow

            HStack {
                if let target = profile.targetWeightKg {
                    Label {
                        if let date = trend.estimatedTargetDate {
                            Text("\(target.frenchOneDecimal) kg vers \(date.formatted(.dateTime.month(.wide).year().locale(Theme.locale)))")
                        } else {
                            Text("Objectif \(target.frenchOneDecimal) kg")
                        }
                    } icon: {
                        Image(systemName: "flag.checkered")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: addWeight) {
                    Label("Pesée", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
            }
        }
    }

    /// Bilan de la semaine : une proposition claire, deux réponses, aucune obligation.
    private func checkInBox(_ suggestion: CalorieSuggestion) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("Bilan de la semaine", systemImage: "calendar.badge.checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.progress)
            Text(suggestion.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Button(action: acceptCheckIn) {
                    Text("Appliquer")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
                Button(action: dismissCheckIn) {
                    Text("Pas maintenant")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.progress.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    /// Régularité de la semaine : une pastille par séance prévue, pleine quand elle est faite.
    private var consistencyRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                HStack(spacing: 5) {
                    ForEach(0..<max(consistency.planned, consistency.done), id: \.self) { index in
                        Circle()
                            .fill(index < consistency.done ? Theme.training : Theme.training.opacity(0.15))
                            .frame(width: 12, height: 12)
                    }
                }
                Text("\(consistency.done)/\(consistency.planned) séances")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if consistency.streakWeeks > 1 {
                    Tag(text: "\(consistency.streakWeeks) sem.", symbol: "flame.fill", tint: Theme.carbs)
                }
            }
            .accessibilityElement(children: .combine)
            Text(consistency.message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
        .animation(Theme.springy, value: consistency)
    }

    /// Proposer Santé tant qu'il n'est pas branché ; ensuite, un simple rappel discret.
    @ViewBuilder
    private var healthRow: some View {
        switch health {
        case .unavailable:
            EmptyView()
        case .off:
            Button(action: connectHealth) {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(symbol: "heart.fill", tint: Theme.protein, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Importer mes pesées depuis Santé")
                            .font(.subheadline.weight(.semibold))
                        Text("Ta balance connectée remplit le suivi pour toi.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Theme.Spacing.m)
                .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        case .on:
            Menu {
                Button("Ne plus importer depuis Santé", systemImage: "heart.slash", role: .destructive, action: disconnectHealth)
            } label: {
                Label("Pesées importées depuis Santé", systemImage: "heart.fill")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Un repère par semaine, sans le coller au bord droit où il serait tronqué.
    private var weeklyTicks: [Date] {
        guard let first = trend.points.first?.date, let last = trend.points.last?.date else { return [] }
        return stride(from: 0, through: 35, by: 7).compactMap { offset -> Date? in
            let tick = first.addingTimeInterval(Double(offset) * 86_400)
            return last.timeIntervalSince(tick) > 3 * 86_400 ? tick : nil
        }
    }

    private var chart: some View {
        let values = trend.points.flatMap { [$0.measuredKg, $0.trendKg] }
        let low = (values.min() ?? 0) - 0.5
        let high = (values.max() ?? 0) + 0.5

        return Chart {
            ForEach(trend.points, id: \.date) { point in
                PointMark(x: .value("Jour", point.date), y: .value("Pesée", point.measuredKg))
                    .symbolSize(18)
                    .foregroundStyle(Theme.progress.opacity(0.35))
            }
            ForEach(trend.points, id: \.date) { point in
                AreaMark(x: .value("Jour", point.date), yStart: .value("Bas", low), yEnd: .value("Tendance", point.trendKg))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(colors: [Theme.progress.opacity(0.28), Theme.progress.opacity(0)], startPoint: .top, endPoint: .bottom)
                    )
                LineMark(x: .value("Jour", point.date), y: .value("Tendance", point.trendKg))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundStyle(Theme.progress)
            }
        }
        .chartYScale(domain: low...high)
        .chartXAxis {
            AxisMarks(values: weeklyTicks) { _ in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Theme.locale))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel()
            }
        }
    }
}

extension ProgressStatus {
    var tint: Color {
        switch self {
        case .onTrack: Theme.progress
        case .tooFast, .wrongDirection: Theme.nutrition
        case .stalled, .notEnoughData: .secondary
        }
    }
}
