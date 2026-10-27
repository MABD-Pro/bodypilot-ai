import BodyPilotCore
import Charts
import SwiftUI

/// « Est-ce que je progresse vers mon objectif ? »
struct ProgressCard: View {
    let trend: WeightTrend
    let message: String
    let profile: UserProfile
    let addWeight: () -> Void

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

            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if trend.points.count >= 2 {
                chart
                    .frame(height: 150)
            }

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
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
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
