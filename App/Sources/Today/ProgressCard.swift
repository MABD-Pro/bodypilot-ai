import BodyPilotCore
import Charts
import Coach
import ProgressInsights
import SwiftUI
import Training

/// Lien avec l'app Santé : pesées lues, repas mangés envoyés.
enum HealthLink {
    case unavailable
    case off
    case on
}

/// Pas du jour, objectif et moyenne des 14 jours précédents (Santé).
struct StepsToday: Equatable {
    let today: Int
    let goal: Int
    let average: Double?
}

/// « Est-ce que je progresse vers mon objectif ? »
struct ProgressCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let trend: WeightTrend
    let message: String
    let profile: UserProfile
    let health: HealthLink
    let checkIn: CalorieSuggestion?
    let waistCm: Double?
    /// Variation sur 4 semaines (cm).
    let waistChange: Double?
    /// Taux de gras et masse maigre de la balance (Santé), si mesurés.
    var composition: BodyCompositionChange?
    /// Records de force, les plus récents d'abord.
    var records: [PersonalRecord] = []
    /// Dernière forme cardio (Watch ou test de marche) et zone de cardio modéré.
    var cardio: CardioMeasure?
    var cardioZone: ClosedRange<Int>?
    /// Sommeil de la nuit passée, lu dans Santé.
    var sleepHours: Double?
    var steps: StepsToday?
    /// Phase choisie par le coach : perte de gras, équilibre ou légère prise.
    var phase: BodyPhase = .fatLoss
    /// 12 semaines de déficit : une semaine à l'équilibre est proposée.
    var maintenanceOffer = false
    var acceptMaintenance: () -> Void = {}
    var dismissMaintenance: () -> Void = {}
    let addWeight: () -> Void
    let addWaist: () -> Void
    let acceptCheckIn: () -> Void
    let dismissCheckIn: () -> Void
    let connectHealth: () -> Void
    let disconnectHealth: () -> Void
    /// Historique, ouvert sur ce qui a été touché : le poids, le tour de taille, un record…
    let showHistory: (HistoryView.Focus) -> Void
    /// Bilan des 7 derniers jours : calories, nutriments, activité et conseils.
    var showReview: (() -> Void)?

    var body: some View {
        CoachCard(eyebrow: "Progresser", symbol: "chart.line.downtrend.xyaxis", tint: Theme.progress) {
            // Très grand texte : la variation passe sous le poids, qui garde sa ligne.
            let header = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            header {
                if let current = trend.currentTrendKg {
                    Button { showHistory(.measure(.weight)) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Text(current.frenchOneDecimal)
                                .font(.display(44))
                                .monospacedDigit()
                                .lineLimit(1)
                                .contentTransition(.numericText(value: current))
                            Text("kg")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Voir l'historique des pesées")
                } else {
                    Text("Première pesée")
                        .font(.display(28))
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                if let weekly = trend.weeklyChangeKg {
                    Tag(text: "\(weekly.frenchSignedOneDecimal) kg/sem.", symbol: weekly < 0 ? "arrow.down.right" : "arrow.up.right", tint: trend.status.tint)
                }
            }

            if maintenanceOffer {
                offerBox(
                    title: "Une semaine à l'équilibre ?", symbol: "pause.circle.fill",
                    message: "12 semaines de déficit : une semaine à ta dépense calme la faim et la fatigue. Elle ne fait pas perdre plus de gras, mais aide à tenir sur la durée. Tu reprends ensuite là où tu en étais.",
                    acceptTitle: "Oui, une semaine", accept: acceptMaintenance, dismiss: dismissMaintenance
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
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

            waistRow

            if let composition {
                compositionRow(composition)
            }

            if !records.isEmpty {
                recordsRow
            }

            cardioRow

            if trend.points.count >= 2 {
                chart
                    .frame(height: 150)
            }

            healthRow

            if let showReview {
                Button(action: showReview) {
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(symbol: "calendar.badge.checkmark", tint: Theme.progress, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mes 7 derniers jours")
                                .font(.subheadline.weight(.semibold))
                            Text("Calories, nutriments, séances et conseils du coach")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Theme.Spacing.s)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(Theme.Spacing.m)
                    .background(Theme.progress.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.inner))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .id("review")
            }

            Button { showHistory(.section(.measures)) } label: {
                Label("Historique : mesures, force, séances, repas", systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.m)
                    .background(Theme.progress.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.inner))
                    .foregroundStyle(Theme.progress)
            }
            .buttonStyle(.plain)

            HStack {
                if let target = profile.targetWeightKg {
                    Label {
                        if phase != .maintenance, let date = trend.estimatedTargetDate {
                            Text("\(phase.title) · \(target.frenchOneDecimal) kg vers \(date.formatted(.dateTime.month(.wide).year().locale(Theme.locale)))")
                        } else {
                            Text("\(phase.title) · objectif \(target.frenchOneDecimal) kg")
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
        offerBox(title: "Bilan de la semaine", symbol: "calendar.badge.checkmark", message: suggestion.message, acceptTitle: "Appliquer", accept: acceptCheckIn, dismiss: dismissCheckIn)
    }

    /// Une proposition du coach : deux réponses, aucune obligation.
    private func offerBox(title: String, symbol: String, message: String, acceptTitle: String, accept: @escaping () -> Void, dismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.progress)
            Text(message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Button(action: accept) {
                    Text(acceptTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
                Button(action: dismiss) {
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

    /// Tour de taille : en recomposition, c'est lui qui montre que le gras part quand le poids stagne.
    private var waistRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            // Sans mesure, la rangée ouvre la saisie ; ensuite, l'historique du tour de taille.
            Button { waistCm == nil ? addWaist() : showHistory(.measure(.waist)) } label: {
                HStack(spacing: Theme.Spacing.m) {
                    IconBadge(symbol: "ruler", tint: Theme.progress, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        if let waistCm {
                            Text("Tour de taille \(waistCm.frenchOneDecimal) cm")
                                .font(.subheadline.weight(.semibold))
                            if let waistChange {
                                Text("\(waistChange > 0 ? "+" : "")\(waistChange.frenchOneDecimal) cm en 4 semaines")
                                    .font(.footnote)
                                    .foregroundStyle(waistChange < 0 ? Theme.progress : .secondary)
                            } else {
                                Text("Une mesure par semaine suffit.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Mesure ton tour de taille")
                                .font(.subheadline.weight(.semibold))
                            Text("Au nombril, le matin. Il montre le gras perdu quand le poids bouge peu.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            Button(action: addWaist) {
                Image(systemName: "plus")
                    .font(.footnote.weight(.bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(Theme.progress.opacity(0.25)).interactive(), in: .circle)
            .accessibilityLabel("Ajouter un tour de taille")
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    /// Balance à impédance : la tendance sur 4 semaines compte, pas la mesure d'un jour.
    private func compositionRow(_ composition: BodyCompositionChange) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(symbol: "figure.arms.open", tint: Theme.progress, size: 36)
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                if let fat = composition.fatPercent {
                    compositionLine(
                        title: "Masse grasse \(fat.frenchOneDecimal) % (moyenne 7 jours)",
                        change: composition.fatChangePoints.map { "\($0 > 0 ? "+" : "")\($0.frenchOneDecimal) point\(abs($0) >= 2 ? "s" : "") en 4 semaines" },
                        good: (composition.fatChangePoints ?? 0) < 0
                    )
                }
                if let lean = composition.leanKg {
                    compositionLine(
                        title: "Masse maigre \(lean.frenchOneDecimal) kg (moyenne 7 jours)",
                        change: composition.leanChangeKg.map { "\($0 > 0 ? "+" : "")\($0.frenchOneDecimal) kg en 4 semaines" },
                        good: (composition.leanChangeKg ?? 0) >= 0
                    )
                }
                Text("Balance dans Santé. Muscles, eau et os comptent dans la masse maigre ; seule la tendance est fiable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
        .contentShape(.rect)
        .onTapGesture { showHistory(.measure(.fat)) }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Voir l'historique du taux de gras")
    }

    private func compositionLine(title: String, change: String?, good: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text(change ?? "Tendance après deux semaines de mesures.")
                .font(.footnote)
                .foregroundStyle(change != nil && good ? Theme.progress : .secondary)
        }
    }

    /// Force : en déficit, des charges qui tiennent ou montent montrent que le muscle est gardé.
    private var recordsRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Mes records", systemImage: "trophy.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.carbs)
            ForEach(records.prefix(4), id: \.entry.exercise) { record in
                Button { showHistory(.exercise(record.entry.exercise)) } label: {
                    HStack {
                        Text(record.entry.exercise)
                            .font(.subheadline)
                        Spacer(minLength: Theme.Spacing.s)
                        Text(StrengthProgress.label(record.entry))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    /// Forme cardio : la VO2max de la Watch ou du test de marche, et la zone qui en découle.
    private var cardioRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(symbol: "heart.circle.fill", tint: Theme.protein, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                if let cardio {
                    Text("Forme cardio \(cardio.vo2max.frenchOneDecimal) ml/kg/min")
                        .font(.subheadline.weight(.semibold))
                    Text("\(cardio.source == .watch ? "Apple Watch" : "Test de marche"), \(cardio.date.formatted(.dateTime.day().month(.wide).locale(Theme.locale)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Forme cardio à mesurer")
                        .font(.subheadline.weight(.semibold))
                    Text("La Watch l'estime pendant tes marches dehors. Sinon, un test de marche de 1,6 km sera proposé un jour de cardio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let cardioZone {
                    Text("Cardio modéré : \(cardioZone.lowerBound) à \(cardioZone.upperBound) bpm")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.protein)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    static func hours(_ value: Double) -> String {
        let total = Int((value * 60).rounded())
        return total % 60 == 0 ? "\(total / 60) h" : "\(total / 60) h \(String(format: "%02d", total % 60))"
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
                        Text("Relier à Santé")
                            .font(.subheadline.weight(.semibold))
                        Text("Pesées, séances de la Watch et cours collectifs, sommeil et forme cardio arrivent tout seuls. Tes repas mangés partent dans Santé.")
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
                Button("Ne plus relier à Santé", systemImage: "heart.slash", role: .destructive, action: disconnectHealth)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Relié à Santé : pesées, séances, sommeil, forme cardio et repas", systemImage: "heart.fill")
                    if let sleepHours {
                        Label("Nuit dernière : \(Self.hours(sleepHours))", systemImage: "bed.double.fill")
                    }
                    if let steps {
                        Label(Self.stepsLine(steps), systemImage: steps.today >= steps.goal ? "checkmark.circle.fill" : "shoeprints.fill")
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            }
        }
    }

    /// « 4 200 pas sur 7 500 aujourd'hui (moyenne 6 500) »
    static func stepsLine(_ steps: StepsToday) -> String {
        let done = Double(steps.today).frenchInteger
        let goal = Double(steps.goal).frenchInteger
        let average = steps.average.map { " (moyenne \(StepActivity.displayed($0).frenchInteger))" } ?? ""
        return steps.today >= steps.goal
            ? "\(done) pas aujourd'hui, objectif de \(goal) atteint\(average)"
            : "\(done) pas sur \(goal) aujourd'hui\(average)"
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
