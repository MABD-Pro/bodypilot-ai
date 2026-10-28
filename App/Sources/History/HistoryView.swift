import BodyPilotCore
import Charts
import ProgressInsights
import SwiftData
import SwiftUI
import Training

/// Historique : tout ce qui a été mesuré, soulevé, fait et mangé, jour par jour.
struct HistoryView: View {
    enum Section: String, CaseIterable, Identifiable {
        case measures = "Mesures"
        case strength = "Force"
        case sessions = "Séances"
        case meals = "Repas"
        var id: String { rawValue }
    }

    /// Mesure affichée dans « Mesures ».
    enum Measure: String, CaseIterable, Identifiable {
        case all = "Toutes les mesures"
        case weight = "Poids"
        case waist = "Tour de taille"
        case fat = "Taux de gras"
        var id: String { rawValue }
    }

    /// Ce que l'historique montre en s'ouvrant : une partie, ou un seul élément (une mesure,
    /// un exercice, un repas) touché sur l'écran Aujourd'hui.
    enum Focus: Equatable {
        case section(Section)
        case measure(Measure)
        case exercise(String)
        case meal(MealSlot)

        var section: Section {
            switch self {
            case .section(let section): section
            case .measure: .measures
            case .exercise: .strength
            case .meal: .meals
            }
        }
    }

    /// Entraînements et composition corporelle lus dans Santé par l'écran Aujourd'hui.
    var healthActivities: [ActivitySample] = []
    var compositions: [BodyCompositionEntry] = []
    /// Partie et élément ouverts au départ : ceux touchés sur l'écran Aujourd'hui.
    var focus: Focus = .section(.measures)

    @Query(sort: \WeightRecord.date, order: .reverse) private var weights: [WeightRecord]
    @Query(sort: \WaistRecord.date, order: .reverse) private var waists: [WaistRecord]
    @Query(sort: \LiftRecord.day, order: .reverse) private var lifts: [LiftRecord]
    @Query(sort: \DayLogRecord.day, order: .reverse) private var dayLogs: [DayLogRecord]
    /// `nil` tant que l'utilisateur n'a pas changé de partie.
    @State private var chosenSection: Section?
    @State private var chosenExercise: String?
    @State private var chosenMeasure: Measure?
    /// `nil` dans le menu : tous les repas.
    @State private var chosenSlot: MealSlot??

    private let calendar = Calendar.current

    private var section: Section {
        chosenSection ?? LaunchOptions.demoHistory.flatMap(Section.init(rawValue:)) ?? focus.section
    }

    private var exercise: String? {
        if let chosenExercise { return chosenExercise }
        if case .exercise(let name) = focus { return name }
        return nil
    }

    private var measure: Measure {
        if let chosenMeasure { return chosenMeasure }
        if case .measure(let measure) = focus { return measure }
        return .all
    }

    private var slot: MealSlot? {
        if let chosenSlot { return chosenSlot }
        if case .meal(let slot) = focus { return slot }
        return nil
    }

    /// Menu de filtre d'une partie, dans la couleur de la partie.
    private func filterMenu<Value: Hashable>(
        _ title: String, selection: Value, options: [(value: Value, label: String)], tint: Color, choose: @escaping @MainActor (Value) -> Void
    ) -> some View {
        Menu {
            Picker(title, selection: Binding(get: { selection }, set: choose)) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].label).tag(options[index].value)
                }
            }
        } label: {
            Label(options.first { $0.value == selection }?.label ?? title, systemImage: "chevron.up.chevron.down")
                .font(.headline)
                .foregroundStyle(tint)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Picker("Historique", selection: Binding(get: { section }, set: { chosenSection = $0 })) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                Group {
                    switch section {
                    case .measures: measures
                    case .strength: strength
                    case .sessions: sessions
                    case .meals: meals
                    }
                }
                .id(section)
                .transition(.opacity)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
            .animation(Theme.springy, value: section)
        }
        .background { AppBackground() }
        .navigationTitle("Historique")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Mesures

    private var scans: [WaistRecord] { waists.filter(\.isScan) }

    private struct MeasureDay {
        var day: Date
        var kg: Double?
        var waistCm: Double?
        var scanCm: Double?
        var fat: Double?
    }

    /// Pesées, tour de taille et composition, regroupés par jour ; seulement la mesure choisie.
    private var measureDays: [MeasureDay] {
        var byDay: [Date: MeasureDay] = [:]
        func update(_ date: Date, _ change: (inout MeasureDay) -> Void) {
            let day = calendar.startOfDay(for: date)
            var value = byDay[day] ?? MeasureDay(day: day)
            change(&value)
            byDay[day] = value
        }
        for weight in weights { update(weight.date) { if $0.kg == nil { $0.kg = weight.kg } } }
        for waist in waists where !waist.isScan { update(waist.date) { if $0.waistCm == nil { $0.waistCm = waist.cm } } }
        for scan in scans { update(scan.date) { if $0.scanCm == nil { $0.scanCm = scan.cm } } }
        for entry in compositions {
            guard let fat = entry.fatPercent else { continue }
            update(entry.date) { $0.fat = fat }
        }
        return byDay.values
            .map { day in
                var day = day
                if measure != .all && measure != .weight { day.kg = nil }
                if measure != .all && measure != .waist { day.waistCm = nil; day.scanCm = nil }
                if measure != .all && measure != .fat { day.fat = nil }
                return day
            }
            .filter { $0.kg != nil || $0.waistCm != nil || $0.scanCm != nil || $0.fat != nil }
            .sorted { $0.day > $1.day }
    }

    @ViewBuilder
    private var measures: some View {
        let days = measureDays
        filterMenu("Mesure", selection: measure, options: Measure.allCases.map { (value: $0, label: $0.rawValue) }, tint: Theme.progress) {
            chosenMeasure = $0
        }
        if days.isEmpty {
            empty("Aucune mesure pour l'instant", detail: "Tes pesées, ton tour de taille et ton taux de gras apparaîtront ici.")
        } else {
            if measure == .waist, waists.filter({ !$0.isScan }).count >= 2 {
                historyCard(title: "Tour de taille", symbol: "ruler", tint: Theme.progress) {
                    Chart(waists.filter { !$0.isScan }, id: \.date) { waist in
                        LineMark(x: .value("Jour", waist.date), y: .value("Tour de taille", waist.cm))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.progress)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                }
            }
            if measure == .fat, compositions.filter({ $0.fatPercent != nil }).count >= 2 {
                historyCard(title: "Taux de gras", symbol: "figure.arms.open", tint: Theme.progress) {
                    Chart(compositions.filter { $0.fatPercent != nil }, id: \.date) { entry in
                        LineMark(x: .value("Jour", entry.date), y: .value("Taux de gras", entry.fatPercent ?? 0))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.progress)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                }
            }
            if (measure == .all || measure == .weight), weights.count >= 2 {
                historyCard(title: "Poids", symbol: "scalemass.fill", tint: Theme.progress) {
                    Chart(weights, id: \.date) { weight in
                        LineMark(x: .value("Jour", weight.date), y: .value("Poids", weight.kg))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.progress)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                }
            }
            if !scans.isEmpty, measure == .all || measure == .waist { scanComparison }
            historyCard(title: "Jour par jour", symbol: "calendar", tint: Theme.progress) {
                ForEach(days, id: \.day) { day in
                    row(date: day.day, value: [
                        day.kg.map { "\($0.frenchOneDecimal) kg" },
                        day.waistCm.map { "taille \($0.frenchOneDecimal) cm" },
                        day.scanCm.map { "scan \($0.frenchOneDecimal) cm" },
                        day.fat.map { "gras \($0.frenchOneDecimal) %" },
                    ].compactMap { $0 }.joined(separator: " · "))
                }
            }
        }
    }

    /// Scan LiDAR (expérimental) comparé au ruban du même jour.
    private var scanComparison: some View {
        let tape = waists.filter { !$0.isScan }.map { (date: $0.date, cm: $0.cm) }
        let gap = WaistScan.meanGapCm(scans: scans.map { (date: $0.date, cm: $0.cm) }, tape: tape, calendar: calendar)
        return historyCard(title: "Scan LiDAR (expérimental)", symbol: "camera.metering.matrix", tint: Theme.progress) {
            Text(gap.map { "Écart moyen avec le ruban : \($0.frenchOneDecimal) cm." } ?? "Mesure aussi au ruban le jour du scan pour comparer.")
                .font(.headline)
            Text("Le scan remplacera le ruban seulement si l'écart reste sous \(WaistScan.adoptionThresholdCm.frenchCompact) cm pendant deux semaines. En attendant, ta tendance utilise le ruban.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Force

    private var exercises: [String] {
        var seen: [String] = []
        for lift in lifts where !seen.contains(lift.exercise) { seen.append(lift.exercise) }
        return seen
    }

    @ViewBuilder
    private var strength: some View {
        let names = exercises
        if names.isEmpty {
            empty("Aucune série notée", detail: "Touche un exercice pendant ta séance pour noter ta meilleure série : elle apparaîtra ici.")
        } else {
            let selected = exercise.flatMap { names.contains($0) ? $0 : nil } ?? names[0]
            let sets = lifts.filter { $0.exercise == selected }
            filterMenu("Exercice", selection: selected, options: names.map { (value: $0, label: $0) }, tint: Theme.training) {
                chosenExercise = $0
            }
            let weighted = sets.filter { ($0.kg ?? 0) > 0 }
            if weighted.count >= 2 {
                historyCard(title: "Max estimé", symbol: "chart.line.uptrend.xyaxis", tint: Theme.training) {
                    Chart(weighted, id: \.day) { lift in
                        LineMark(x: .value("Jour", lift.day), y: .value("Max estimé", StrengthProgress.score(lift.entry)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.training)
                        PointMark(x: .value("Jour", lift.day), y: .value("Max estimé", StrengthProgress.score(lift.entry)))
                            .foregroundStyle(Theme.training)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                    Text("1RM estimé (formule d'Epley) de ta meilleure série de chaque séance.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            historyCard(title: "Séries notées", symbol: "list.bullet", tint: Theme.training) {
                ForEach(sets, id: \.day) { lift in
                    row(date: lift.day, value: StrengthProgress.label(lift.entry) + (lift.isTest ? " · test" : ""))
                }
            }
        }
    }

    // MARK: - Séances

    @ViewBuilder
    private var sessions: some View {
        let days = SessionHistory.days(
            completed: dayLogs.filter(\.workoutDone).map { (day: $0.day, title: $0.doneWorkoutTitle) },
            samples: healthActivities,
            calendar: calendar
        )
        if days.isEmpty {
            empty("Aucune séance pour l'instant", detail: "Les séances cochées et les entraînements de Santé (Watch, cours collectifs) apparaîtront ici.")
        } else {
            historyCard(title: "Jour par jour", symbol: "figure.strengthtraining.traditional", tint: Theme.training) {
                ForEach(days) { day in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel(day.day))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(Array(day.entries.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: Theme.Spacing.s) {
                                Image(systemName: entry.fromHealth ? "heart.fill" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(entry.fromHealth ? Theme.protein : Theme.training)
                                Text(entry.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: Theme.Spacing.s)
                                Text([
                                    entry.minutes.map { "\(Int($0.rounded())) min" },
                                    entry.kcal.map { "\($0.frenchInteger) kcal" },
                                ].compactMap { $0 }.joined(separator: " · "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Repas

    @ViewBuilder
    private var meals: some View {
        let slots = slot.map { [$0] } ?? MealSlot.allCases
        let days = dayLogs.filter { log in slots.contains { mealText(log, $0) != nil } }
        let options: [(value: MealSlot?, label: String)] = [(value: nil, label: "Tous les repas")]
            + MealSlot.allCases.map { (value: Optional($0), label: $0.title) }
        filterMenu("Repas", selection: slot, options: options, tint: Theme.nutrition) { chosenSlot = .some($0) }
        if days.isEmpty {
            empty("Aucun repas noté", detail: "Les repas pris d'une touche ou décrits apparaîtront ici.")
        } else {
            historyCard(title: "Jour par jour", symbol: "fork.knife", tint: Theme.nutrition) {
                ForEach(days, id: \.day) { log in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayLabel(log.day))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        ForEach(slots, id: \.self) { slot in
                            if let text = mealText(log, slot) {
                                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                                    Image(systemName: slot.symbol)
                                        .font(.caption)
                                        .foregroundStyle(Theme.nutrition)
                                    Text(slot.title)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer(minLength: Theme.Spacing.s)
                                    Text(text)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    /// Repas décrit : ce qui a été mangé et ses calories ; sinon la saisie d'une touche.
    private func mealText(_ log: DayLogRecord, _ slot: MealSlot) -> String? {
        if let described = log.describedMeals[slot] {
            return "\(described.title) · \(described.macros.kcal.frenchInteger) kcal"
        }
        return log.mealIntakes[slot]?.label
    }

    // MARK: - Éléments communs

    private func historyCard<Content: View>(title: String, symbol: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        CoachCard(eyebrow: title, symbol: symbol, tint: tint) {
            // Des mois de lignes : seules celles à l'écran sont construites.
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.m) {
                content()
            }
        }
    }

    private func row(date: Date, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(dayLabel(date))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.s)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        if calendar.isDateInToday(date) { return "Aujourd'hui" }
        if calendar.isDateInYesterday(date) { return "Hier" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Theme.locale))
    }

    private func empty(_ title: String, detail: String) -> some View {
        CoachCard(eyebrow: "Historique", symbol: "clock.arrow.circlepath", tint: .secondary) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
