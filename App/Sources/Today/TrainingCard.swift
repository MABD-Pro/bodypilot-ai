import BodyPilotCore
import ProgressInsights
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
    /// Jours de séance de cette semaine (1 = dimanche … 7 = samedi).
    var weekDays: [Int] = []
    var toggleWeekDay: (Int) -> Void = { _ in }
    /// Ce qui a vraiment été fait cette semaine (séances cochées et activités de Santé).
    var week: WeekActivity?
    var healthLinked = false
    /// Un jour de repos, l'envie de bouger donne une séance en plus.
    var wantsToTrain: (() -> Void)?
    /// Séance en plus en cours : retour possible à la marche prévue.
    var cancelExtraSession: (() -> Void)?
    /// Planifie la semaine sur la Watch ; `false` si l'autorisation est refusée.
    var planWeekOnWatch: (() async -> Bool)?
    /// Meilleures séries notées, toutes séances confondues.
    var lifts: [LiftEntry] = []
    /// Matériel de salle : la saisie part d'une charge, sinon du poids du corps.
    var usesLoads = false
    var logLift: (LiftEntry) -> Void = { _ in }
    /// Poids et sexe, pour proposer une charge d'essai avant la première série notée.
    var bodyweightKg: Double?
    var sex: BiologicalSex = .male
    /// Séances et marches des prochains jours.
    var upcoming: [UpcomingDay] = []

    @State private var isPreviewingWatch = false
    @State private var logging: LiftToLog?
    @State private var celebration: String?
    private let calendar = Calendar.current
    @State private var watchWeek: WatchWeekState = .idle

    private enum WatchWeekState { case idle, sending, sent, refused }

    var body: some View {
        CoachCard(eyebrow: "Bouger", symbol: "figure.strengthtraining.functional", tint: Theme.training) {
            WeekStrip(selected: weekDays, toggle: toggleWeekDay)

            switch training.kind {
            case .workout(let workout):
                workoutContent(workout)
            case .activeRest(let title, let minutes):
                restContent(title: title, minutes: minutes)
            }

            ForEach(training.notes, id: \.self) { note in
                CoachNote(text: note, tint: Theme.training)
            }

            if !upcoming.isEmpty {
                UpcomingSection(days: upcoming)
                    .id("upcoming")
            }

            if let week {
                WeekSection(week: week, healthLinked: healthLinked)
                    .id("week")
            }

            if let planWeekOnWatch, WatchSchedule.isSupported {
                watchWeekButton(planWeekOnWatch)
            }
        }
    }

    private func watchWeekButton(_ plan: @escaping () async -> Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                watchWeek = .sending
                Task { watchWeek = await plan() ? .sent : .refused }
            } label: {
                Label(watchWeek == .sent ? "Semaine planifiée sur ta Watch" : "Planifier ma semaine sur la Watch",
                      systemImage: watchWeek == .sent ? "checkmark.circle.fill" : "applewatch.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .disabled(watchWeek == .sending)
            .sensoryFeedback(.success, trigger: watchWeek) { _, state in state == .sent }
            Text(watchWeekCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var watchWeekCaption: String {
        switch watchWeek {
        case .refused: "Autorise BodyPilot dans Réglages > Confidentialité > Santé pour planifier sur la montre."
        case .sent: "Séances et marches des jours de repos sont dans l'app Exercice de ta montre, jour par jour."
        default: "Séances et marches des jours de repos, jusqu'à dimanche. Touche à nouveau après un changement."
        }
    }

    private func workoutContent(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(workout.title)
                        .font(.display(28))
                    Text(workout.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                DurationBadge(minutes: training.estimatedMinutes)
            }

            if let cancelExtraSession {
                Button(action: cancelExtraSession) {
                    Label("Séance en plus · revenir à la marche", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.training)
                }
                .buttonStyle(.plain)
            }

            if let celebration {
                Label(celebration, systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.carbs)
                    .padding(Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.carbs.opacity(0.14), in: .rect(cornerRadius: Theme.Radius.inner))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                ExerciseRow(index: 0, name: "Échauffement", detail: "\(workout.warmupMinutes) min", isWarmup: true)
                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                    let toLog = liftToLog(exercise)
                    ExerciseRow(
                        index: index + 1,
                        name: exercise.name,
                        detail: exercise.prescription,
                        isWarmup: false,
                        isSwapped: exercise.isSwapped,
                        caption: toLog.map(caption),
                        swap: exercise.alternatives.isEmpty ? nil : { swap(exercise.key) },
                        log: toLog.map { item -> () -> Void in { logging = item } }
                    )
                }
            }
            .sheet(item: $logging) { item in
                LiftEntrySheet(item: item) { entry in save(entry) }
            }
            .sensoryFeedback(.success, trigger: celebration) { _, new in new != nil }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(workout.intensityCue, systemImage: "gauge.with.dots.needle.33percent")
                Label("Touche un exercice pour sa technique et pour noter ta meilleure série : le coach suit tes records et fait monter les charges.", systemImage: "trophy")
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

    /// Exercice de force aux répétitions : la meilleure série se note, pour suivre records et charges.
    private func liftToLog(_ exercise: WorkoutExercise) -> LiftToLog? {
        guard !exercise.isConditioning, case .reps(let planned) = exercise.volume else { return nil }
        let today = lifts.first { $0.exercise == exercise.name && calendar.isDateInToday($0.date) }
        let earlier = lifts.filter { !calendar.isDateInToday($0.date) }
        let guide = ExerciseGuide.guide(for: exercise.name)
        return LiftToLog(
            exercise: exercise.name,
            plannedReps: planned,
            today: today,
            target: StrengthProgress.target(for: exercise.name, plannedReps: planned, history: earlier),
            isRecord: today.map { StrengthProgress.isRecord($0, previous: earlier) } ?? false,
            usesLoads: usesLoads,
            guide: guide,
            startingKg: usesLoads ? bodyweightKg.flatMap { guide?.startingLoad(bodyweightKg: $0, sex: sex) } : nil
        )
    }

    private func caption(_ item: LiftToLog) -> ExerciseRow.Caption {
        if let today = item.today {
            return item.isRecord
                ? .init(text: "Record ! \(StrengthProgress.label(today))", symbol: "trophy.fill", tint: Theme.carbs)
                : .init(text: "Noté : \(StrengthProgress.label(today))", symbol: "checkmark", tint: Theme.progress)
        }
        if let target = item.target {
            return .init(
                text: "Vise \(StrengthProgress.label(kg: target.kg, reps: target.reps))",
                symbol: target.isIncrease ? "arrow.up.right" : "scope",
                tint: target.isIncrease ? Theme.training : .secondary
            )
        }
        if let start = item.startingKg {
            return .init(text: "Essai : \(StrengthProgress.label(kg: start, reps: item.plannedReps))", symbol: "scope", tint: .secondary)
        }
        return .init(text: item.usesLoads ? "Note ta charge" : "Note tes répétitions", symbol: "square.and.pencil", tint: .secondary)
    }

    private func save(_ entry: LiftEntry) {
        let earlier = lifts.filter { !calendar.isDateInToday($0.date) }
        logLift(entry)
        guard StrengthProgress.isRecord(entry, previous: earlier) else { return }
        withAnimation(Theme.springy) {
            celebration = "Nouveau record : \(entry.exercise), \(StrengthProgress.label(entry))"
        }
        Task {
            try? await Task.sleep(for: .seconds(5))
            withAnimation(Theme.springy) { celebration = nil }
        }
    }

    private func restContent(title: String, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
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
            restActions
        }
    }

    /// Jour de repos : la marche part sur la montre, ou une séance en plus si l'envie est là.
    @ViewBuilder
    private var restActions: some View {
        // L'un sous l'autre, pleine largeur : les libellés restent entiers sur tous les écrans.
        let buttons = VStack(spacing: Theme.Spacing.s) { restButtons }
        if let plan = training.watchPlan {
            buttons.workoutPreview(plan, isPresented: $isPreviewingWatch)
        } else {
            buttons
        }
    }

    @ViewBuilder
    private var restButtons: some View {
        if training.watchPlan != nil {
            Button {
                isPreviewingWatch = true
            } label: {
                Label("Sur ma Watch", systemImage: "applewatch")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
        }
        if let wantsToTrain {
            Button(action: wantsToTrain) {
                Label("Envie de bouger", systemImage: "bolt.heart")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
        }
    }
}

/// « Ma semaine » : minutes bougées par jour, puis le détail des activités.
private struct WeekSection: View {
    let week: WeekActivity
    let healthLinked: Bool

    private let calendar = Calendar.current
    /// Une heure remplit la barre ; au-delà, elle reste pleine.
    private let fullBarMinutes = 60.0

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ma semaine")
                    .font(.headline)
                Text(week.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(zip(week.days, week.minutesPerDay)), id: \.0) { day, minutes in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            Capsule().fill(Theme.training.opacity(0.1))
                            Capsule()
                                .fill(Theme.training.gradient)
                                .frame(height: minutes > 0 ? max(8, 56 * min(minutes / fullBarMinutes, 1)) : 0)
                        }
                        .frame(height: 56)
                        Text(calendar.initialWeekdayLetters(locale: Theme.locale)[calendar.component(.weekday, from: day) - 1])
                            .font(.caption2.weight(calendar.isDateInToday(day) ? .bold : .medium))
                            .foregroundStyle(calendar.isDateInToday(day) ? Theme.training : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(calendar.weekdayNames(locale: Theme.locale)[calendar.component(.weekday, from: day) - 1]) : \(WeekActivityAnalyzer.duration(minutes))")
                }
            }
            .animation(Theme.springy, value: week.minutesPerDay)

            VStack(spacing: 0) {
                ForEach(week.entries.prefix(6)) { entry in
                    HStack(spacing: Theme.Spacing.m) {
                        IconBadge(symbol: entry.kind.symbol, tint: Theme.training, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.title)
                                .font(.subheadline.weight(.medium))
                            Text(detail(of: entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if entry.fromHealth {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.protein)
                                .accessibilityLabel("Enregistré dans Santé")
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            if !healthLinked {
                Text("Relie Santé dans Progresser pour voir aussi les activités de ta Watch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func detail(of entry: WeekActivityEntry) -> String {
        let weekday = calendar.weekdayNames(locale: Theme.locale)[calendar.component(.weekday, from: entry.start) - 1]
        var parts = [weekday.capitalizingFirstLetter, WeekActivityAnalyzer.duration(entry.minutes)]
        if let kcal = entry.kcal, kcal >= 1 { parts.append("\(kcal.frenchInteger) kcal") }
        return parts.joined(separator: " · ")
    }
}

/// Les 7 jours de la semaine en cours : une touche ajoute ou retire une séance, pour cette semaine.
private struct WeekStrip: View {
    let selected: [Int]
    let toggle: (Int) -> Void

    private let calendar = Calendar.current

    var body: some View {
        let today = calendar.component(.weekday, from: .now)
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: 6) {
                ForEach(calendar.orderedWeekdays, id: \.self) { weekday in
                    let isOn = selected.contains(weekday)
                    Button {
                        toggle(weekday)
                    } label: {
                        Text(calendar.initialWeekdayLetters(locale: Theme.locale)[weekday - 1])
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .foregroundStyle(isOn ? Color.white : (weekday == today ? Theme.training : .secondary))
                            .background(isOn ? Theme.training : Theme.training.opacity(0.08), in: .circle)
                            .overlay {
                                if weekday == today {
                                    Circle().strokeBorder(Theme.training, lineWidth: 2).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(calendar.weekdayNames(locale: Theme.locale)[weekday - 1])
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text("Tes jours de séance cette semaine. Touche un jour pour l'ajouter ou le retirer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

extension Calendar {
    /// Jours de la semaine dans l'ordre local (lundi d'abord en France).
    var orderedWeekdays: [Int] {
        (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
    }

    func initialWeekdayLetters(locale: Locale) -> [String] {
        var calendar = self
        calendar.locale = locale
        return calendar.veryShortStandaloneWeekdaySymbols
    }

    func weekdayNames(locale: Locale) -> [String] {
        var calendar = self
        calendar.locale = locale
        return calendar.standaloneWeekdaySymbols
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
    var caption: Caption?
    var swap: (() -> Void)?
    /// Ouvre la saisie de la meilleure série.
    var log: (() -> Void)?

    struct Caption {
        let text: String
        let symbol: String
        let tint: Color
    }

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

            if let log {
                Button(action: log) { label }
                    .buttonStyle(.plain)
                    .accessibilityHint("Noter ta meilleure série")
            } else {
                label
            }
            Spacer(minLength: Theme.Spacing.s)
            // Le volume reste sur une ligne : c'est le nom qui passe à la ligne si la place manque.
            Text(detail)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
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
            } else {
                // Même place réservée : les volumes restent alignés d'une ligne à l'autre.
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 7)
    }

    private var label: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.subheadline.weight(.medium))
                .contentTransition(.opacity)
            if let caption {
                Label(caption.text, systemImage: caption.symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(caption.tint)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

/// Exercice dont on note la meilleure série.
struct LiftToLog: Identifiable {
    let exercise: String
    let plannedReps: Int
    let today: LiftEntry?
    let target: LiftTarget?
    let isRecord: Bool
    let usesLoads: Bool
    let guide: ExerciseGuide?
    /// Charge d'essai prudente, tant qu'aucune série n'est notée.
    let startingKg: Double?
    var id: String { exercise }
}

/// Meilleure série en deux touches : charge et répétitions partent de l'objectif du jour.
private struct LiftEntrySheet: View {
    let item: LiftToLog
    let save: (LiftEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var withLoad: Bool
    @State private var kg: Double
    @State private var reps: Int

    init(item: LiftToLog, save: @escaping (LiftEntry) -> Void) {
        self.item = item
        self.save = save
        let start = item.today.map { LiftTarget(kg: $0.kg, reps: $0.reps, isIncrease: false) } ?? item.target
        let kg = start?.kg ?? (start == nil && item.usesLoads ? item.startingKg ?? 20 : nil)
        _withLoad = State(initialValue: kg != nil)
        _kg = State(initialValue: kg ?? 10)
        _reps = State(initialValue: start?.reps ?? item.plannedReps)
    }

    var body: some View {
        ScrollView {
            content
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .sensoryFeedback(.increase, trigger: kg)
        .sensoryFeedback(.increase, trigger: reps)
    }

    private var content: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(item.exercise)
                    .font(.display(24))
                    .multilineTextAlignment(.center)
                Text("Ta meilleure série du jour. Prévu : \(item.plannedReps) répétitions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if item.today == nil, item.target == nil, item.startingKg != nil {
                    Text("Charge d'essai prudente : si tu pouvais faire plus de 3 répétitions de plus, monte la prochaine fois.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Toggle("Avec une charge", isOn: $withLoad.animation(.snappy))
                .font(.subheadline.weight(.medium))
                .tint(Theme.training)

            if withLoad {
                counter(value: kg.frenchCompact, unit: item.guide?.perDumbbell == true ? "kg par haltère" : "kg", numeric: kg) { up in
                    let step = StrengthProgress.loadStep(for: up ? kg : max(kg - 1, 0))
                    kg = max(0, ((kg + (up ? step : -step)) * 10).rounded() / 10)
                }
            }
            counter(value: "\(reps)", unit: "répétitions", numeric: Double(reps)) { up in
                reps = max(1, reps + (up ? 1 : -1))
            }

            Button {
                save(LiftEntry(exercise: item.exercise, date: Calendar.current.startOfDay(for: .now), kg: withLoad && kg > 0 ? kg : nil, reps: reps))
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)

            if let guide = item.guide {
                technique(guide)
            }
        }
        .padding(Theme.Spacing.xxl)
    }

    /// Repères de technique, en attendant les démonstrations animées.
    private func technique(_ guide: ExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("Technique", systemImage: "figure.strengthtraining.traditional")
                .font(.headline)
                .foregroundStyle(Theme.training)
            Text(guide.muscles)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            ForEach(Array(guide.cues.enumerated()), id: \.offset) { index, cue in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.training)
                        .frame(width: 18)
                    Text(cue)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.training.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func counter(value: String, unit: String, numeric: Double, change: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: Theme.Spacing.xl) {
            step(symbol: "minus") { change(false) }
            VStack(spacing: 0) {
                Text(value)
                    .font(.display(44))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: numeric))
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 130)
            step(symbol: "plus") { change(true) }
        }
    }

    private func step(symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy, action)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonRepeatBehavior(.enabled)
    }
}

extension WorkoutExercise {
    /// Remplacé à la demande, et non par une règle de sécurité (celles-ci vident les variantes).
    var isSwapped: Bool { name != key && !alternatives.isEmpty }

    var prescription: String {
        switch volume {
        case .reps(let reps): "\(sets) × \(reps)"
        // Effort continu (marche inclinée, cardio tempo) : en minutes.
        case .seconds(let seconds) where sets == 1 && seconds >= 120: "\(Int((Double(seconds) / 60).rounded())) min"
        // Fractionné : effort puis récupération.
        case .seconds(let seconds) where isConditioning && restSeconds > 0: "\(sets) × \(seconds) s / \(restSeconds) s"
        case .seconds(let seconds): "\(sets) × \(seconds) s"
        }
    }

    /// Cardio et marche inclinée, ajoutés après la force.
    var isConditioning: Bool { priority >= 4 }
}

extension Workout {
    /// « 4 exercices de force · cardio · marche inclinée ».
    var summary: String {
        let strength = exercises.filter { !$0.isConditioning }
        var parts = ["\(strength.count) exercices de force"]
        let conditioning = exercises.filter(\.isConditioning).count
        if conditioning >= 1 { parts.append("cardio") }
        if conditioning >= 2 { parts.append("marche") }
        return parts.joined(separator: " · ")
    }
}

/// Un jour à venir : séance ou marche, déjà calculée par le coach.
struct UpcomingDay: Identifiable {
    let date: Date
    let training: TrainingDay
    var id: Date { date }
}

/// « Les prochains jours » : ce qui attend, jour par jour ; une touche déplie les exercices.
private struct UpcomingSection: View {
    let days: [UpcomingDay]

    @State private var expanded: Set<Date> = []
    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Les prochains jours")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(days) { day in
                    row(day)
                    if day.id != days.last?.id { Divider() }
                }
            }
        }
    }

    private func row(_ day: UpcomingDay) -> some View {
        let isOpen = expanded.contains(day.date)
        let workout: Workout? = if case .workout(let workout) = day.training.kind { workout } else { nil }
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button {
                guard workout != nil else { return }
                withAnimation(Theme.springy) {
                    if isOpen { expanded.remove(day.date) } else { expanded.insert(day.date) }
                }
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    Text(calendar.weekdayNames(locale: Theme.locale)[calendar.component(.weekday, from: day.date) - 1].capitalizingFirstLetter)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 84, alignment: .leading)
                    IconBadge(symbol: workout == nil ? "figure.walk" : "dumbbell.fill", tint: workout == nil ? Theme.progress : Theme.training, size: 26)
                    Text(title(day))
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.s)
                    Text("\(day.training.estimatedMinutes) min")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .opacity(workout == nil ? 0 : 1)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isOpen, let workout {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.offset) { _, exercise in
                        HStack {
                            Text(exercise.name)
                                .font(.footnote)
                            Spacer(minLength: Theme.Spacing.s)
                            Text(exercise.prescription)
                                .font(.footnote.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
                }
                .padding(.leading, 84 + Theme.Spacing.m)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
    }

    private func title(_ day: UpcomingDay) -> String {
        switch day.training.kind {
        case .workout(let workout): workout.title
        case .activeRest(let title, _): title
        }
    }
}
