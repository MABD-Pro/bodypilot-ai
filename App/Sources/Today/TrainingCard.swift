import BodyPilotCore
import Coach
import ProgressInsights
import SwiftUI
import Training
import WorkoutKit

/// « Quel entraînement dois-je effectuer ? »
struct TrainingCard: View {
    let training: TrainingDay
    /// Les propositions du jour ; `nil` : la séance seule.
    var options: TrainingOptions?
    var choice: TrainingChoice?
    var choose: (TrainingChoice) -> Void = { _ in }
    /// Ajustements du jour, pour l'état de « Comment te sens-tu ? ».
    var adjustments: Set<QuickAdjustment> = []
    var setFeeling: (Feeling) -> Void = { _ in }
    /// Remplace l'exercice (par sa clé) par la variante suivante.
    var swap: (String) -> Void = { _ in }
    var isDone = false
    var toggleDone: () -> Void = {}
    /// Ce qui a vraiment été fait cette semaine (séances cochées et activités de Santé).
    var week: WeekActivity?
    var healthLinked = false
    /// Meilleures séries notées, toutes séances confondues.
    var lifts: [LiftEntry] = []
    /// Matériel de salle : la saisie part d'une charge, sinon du poids du corps.
    var usesLoads = false
    var logLift: (LiftEntry) -> Void = { _ in }
    /// Poids et sexe, pour proposer une charge d'essai avant la première série notée.
    var bodyweightKg: Double?
    var sex: BiologicalSex = .male

    @State private var isPreviewingWatch = false
    @State private var logging: LiftToLog?
    @State private var celebration: String?
    private let calendar = Calendar.current

    var body: some View {
        CoachCard(eyebrow: "Bouger", symbol: "figure.strengthtraining.functional", tint: Theme.training) {
            if let options {
                FeelingPicker(adjustments: adjustments, set: setFeeling)
                OptionsPicker(options: options, choice: choice ?? options.recommended, choose: choose)
                    .id("options")
            }

            switch training.kind {
            case .workout(let workout):
                workoutContent(workout)
            case .activeRest(let title, let minutes):
                restContent(title: title, minutes: minutes)
            case .rest:
                fullRestContent
            }

            if let week {
                WeekSection(week: week, healthLinked: healthLinked)
                    .id("week")
            }
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

            notes

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
                    let toLog = liftToLog(exercise, isTest: workout.isStrengthTest)
                    ExerciseRow(
                        index: index + 1,
                        name: exercise.name,
                        detail: workout.isStrengthTest ? "5 rép." : exercise.prescription,
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
                if workout.isStrengthTest {
                    Label("Touche un exercice pour voir ses paliers et noter ta série de 5 la plus lourde.", systemImage: "chart.line.uptrend.xyaxis")
                } else if workout.hasStrength {
                    Label("Touche un exercice pour sa technique et pour noter ta meilleure série : le coach suit tes records et fait monter les charges.", systemImage: "trophy")
                }
                if !workout.isStrengthTest {
                    Label("Machine prise ou matériel absent ? Touche \(Image(systemName: "arrow.triangle.2.circlepath")) pour changer d'exercice.", systemImage: "hand.tap")
                }
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

    /// Pourquoi la séance est ainsi (récupération, genou, fatigue…), juste sous son titre.
    private var notes: some View {
        ForEach(training.notes, id: \.self) { note in
            CoachNote(text: note, tint: Theme.training)
        }
    }

    /// Exercice de force aux répétitions : la meilleure série se note, pour suivre records et charges.
    private func liftToLog(_ exercise: WorkoutExercise, isTest: Bool) -> LiftToLog? {
        guard !exercise.isConditioning, case .reps(let planned) = exercise.volume else { return nil }
        let today = lifts.first { $0.exercise == exercise.name && calendar.isDateInToday($0.date) }
        let earlier = lifts.filter { !calendar.isDateInToday($0.date) }
        let guide = ExerciseGuide.guide(for: exercise.name)
        let startingKg = usesLoads ? bodyweightKg.flatMap { guide?.startingLoad(bodyweightKg: $0, sex: sex) } : nil
        let target = StrengthProgress.target(for: exercise.name, plannedReps: planned, history: earlier)
        // Test refait : le premier essai part des dernières charges plutôt que de la charge d'essai.
        let firstAttemptKg = target?.kg ?? startingKg
        return LiftToLog(
            exercise: exercise.name,
            plannedReps: planned,
            today: today,
            target: target,
            isRecord: today.map { StrengthProgress.isRecord($0, previous: earlier) } ?? false,
            usesLoads: usesLoads,
            guide: guide,
            startingKg: startingKg,
            isTest: isTest,
            ramp: isTest ? firstAttemptKg.map { StrengthCalibration.ramp(for: exercise.name, firstAttemptKg: $0) } ?? [] : []
        )
    }

    private func caption(_ item: LiftToLog) -> ExerciseRow.Caption {
        if item.isTest {
            if let today = item.today {
                return .init(text: "Test noté : \(StrengthProgress.label(today))", symbol: "checkmark", tint: Theme.progress)
            }
            if let first = item.ramp.last {
                return .init(text: "Essai à \(first.kg.frenchCompact) kg", symbol: "chart.line.uptrend.xyaxis", tint: Theme.training)
            }
            return .init(text: "Note ta série de 5 la plus lourde", symbol: "square.and.pencil", tint: .secondary)
        }
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
                    Text("Bouger un peu, même court, garde le rythme.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                DurationBadge(minutes: minutes)
            }
            notes
            restActions
        }
    }

    /// Repos complet : rien à faire, sinon bien récupérer.
    private var fullRestContent: some View {
        HStack(spacing: Theme.Spacing.l) {
            IconBadge(symbol: "bed.double.fill", tint: Theme.training, size: 52)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Repos")
                    .font(.display(24))
                Text("Sommeil, protéines et un peu de marche si l'envie te prend : les muscles se construisent aussi au repos.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Marche (séance ratée, très peu de temps) : elle part sur la montre.
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
    }
}

/// Ressenti du matin, en une touche.
enum Feeling: CaseIterable {
    case great, sore, tired

    var label: String {
        switch self {
        case .great: "En forme"
        case .sore: "Courbatures"
        case .tired: "Fatigué"
        }
    }

    var symbol: String {
        switch self {
        case .great: "sun.max.fill"
        case .sore: "figure.cooldown"
        case .tired: "battery.25percent"
        }
    }
}

/// « Comment te sens-tu ? » : le coach en tient compte pour sa recommandation.
private struct FeelingPicker: View {
    let adjustments: Set<QuickAdjustment>
    let set: (Feeling) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Comment te sens-tu ?")
                .font(.headline)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(Feeling.allCases, id: \.self) { feeling in
                    let isOn = isSelected(feeling)
                    Button {
                        set(feeling)
                    } label: {
                        Label(feeling.label, systemImage: feeling.symbol)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .padding(.horizontal, 6)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.s)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(isOn ? .regular.tint(Theme.training).interactive() : .regular.interactive(), in: .capsule)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }

    private func isSelected(_ feeling: Feeling) -> Bool {
        switch feeling {
        case .great: !adjustments.contains(.tired) && !adjustments.contains(.sore)
        case .sore: adjustments.contains(.sore)
        case .tired: adjustments.contains(.tired)
        }
    }
}

/// « Aujourd'hui, au choix » : 2 ou 3 activités et le repos, la recommandée marquée.
private struct OptionsPicker: View {
    let options: TrainingOptions
    let choice: TrainingChoice
    let choose: (TrainingChoice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Aujourd'hui, au choix")
                .font(.headline)
            VStack(spacing: 0) {
                ForEach(options.options, id: \.choice) { option in
                    row(option)
                    if option.choice != options.options.last?.choice { Divider() }
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
            // La raison n'accompagne que la recommandation : un autre choix est celui de l'utilisateur.
            if choice == options.recommended {
                CoachNote(text: options.reason, tint: Theme.training)
            }
        }
        .sensoryFeedback(.selection, trigger: choice)
    }

    private func row(_ option: TrainingOption) -> some View {
        let isChosen = option.choice == choice
        return Button {
            choose(option.choice)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: option.choice.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(option.choice.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.title)
                        .font(.subheadline.weight(isChosen ? .semibold : .regular))
                    if option.choice == options.recommended {
                        Text("Recommandé")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.training)
                    }
                }
                Spacer(minLength: Theme.Spacing.s)
                if option.day.estimatedMinutes > 0 {
                    Text("\(option.day.estimatedMinutes) min")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChosen ? Theme.training : Color.secondary.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}

extension TrainingChoice {
    var symbol: String {
        switch self {
        case .strength: "dumbbell.fill"
        case .conditioning: "heart.fill"
        case .light: "figure.walk"
        case .rest: "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case .strength: Theme.training
        case .conditioning: Theme.progress
        case .light: Theme.nutrition
        case .rest: Color.secondary
        }
    }
}

extension TrainingOption {
    var title: String {
        switch day.kind {
        case .workout(let workout): workout.title
        case .activeRest(let title, _): title
        case .rest: "Repos"
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

extension Calendar {
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
    /// Test du calibrage : paliers d'échauffement puis premier essai.
    var isTest = false
    var ramp: [RampStep] = []
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
    @State private var showsTechnique = false
    @State private var showsVideo = LaunchOptions.demoVideo
    @State private var detent: PresentationDetent = LaunchOptions.demoVideo ? .large : .medium

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
        ScrollViewReader { proxy in
            ScrollView {
                content
            }
            .onChange(of: showsVideo) { _, shown in
                guard shown else { return }
                detent = .large
                Task {
                    // Le temps que le lecteur apparaisse et que la feuille s'agrandisse.
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(.snappy) { proxy.scrollTo("video", anchor: .bottom) }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large], selection: $detent)
        .sensoryFeedback(.increase, trigger: kg)
        .sensoryFeedback(.increase, trigger: reps)
    }

    private var content: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(item.exercise)
                    .font(.display(24))
                    .multilineTextAlignment(.center)
                Text(item.isTest
                    ? "Note ta série de 5 la plus lourde faite proprement : elle fixe tes charges de travail."
                    : "Ta meilleure série du jour. Prévu : \(item.plannedReps) répétitions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if item.guide != nil {
                    Button {
                        withAnimation(.snappy) { showsTechnique.toggle() }
                    } label: {
                        Label(showsTechnique ? "Masquer la technique" : "Voir la technique", systemImage: "figure.strengthtraining.traditional")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.training)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.xs)
                }
                if ExerciseDemonstration.embedURL(for: item.exercise) != nil {
                    Button {
                        withAnimation(.snappy) { showsVideo.toggle() }
                    } label: {
                        Label(showsVideo ? "Masquer la démonstration" : "Voir une démonstration", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.training)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: ExerciseDemonstration.url(for: item.exercise)) {
                        Label("Chercher une démonstration", systemImage: "magnifyingglass")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.training)
                    }
                }
                if !item.isTest, item.today == nil, item.target == nil, item.startingKg != nil {
                    Text("Charge d'essai prudente : si tu pouvais faire plus de 3 répétitions de plus, monte la prochaine fois.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if !item.ramp.isEmpty {
                ramp
            }

            if showsTechnique, let guide = item.guide {
                technique(guide)
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                save(LiftEntry(exercise: item.exercise, date: Calendar.current.startOfDay(for: .now), kg: withLoad && kg > 0 ? kg : nil, reps: reps, isTest: item.isTest))
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)

            // Sous la saisie : la vidéo ne repousse pas la série à noter.
            if showsVideo, let embed = ExerciseDemonstration.embedURL(for: item.exercise) {
                demonstration(embed)
                    .id("video")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(Theme.Spacing.xxl)
    }

    /// Montée en charge du test : échauffements, premier essai, puis essais plus lourds.
    private var ramp: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("Paliers", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(Theme.training)
            ForEach(Array(item.ramp.enumerated()), id: \.offset) { index, step in
                let isAttempt = index == item.ramp.count - 1
                HStack(spacing: Theme.Spacing.s) {
                    Text(isAttempt ? "Essai" : "Palier \(index + 1)")
                        .font(.subheadline.weight(isAttempt ? .semibold : .regular))
                    Spacer()
                    Text(StrengthProgress.label(kg: step.kg, reps: step.reps))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if let attempt = item.ramp.last {
                Text("Si les 5 sont faciles, ajoute \(StrengthCalibration.attemptIncrement(for: item.exercise, from: attempt.kg).frenchCompact) kg et recommence, 2 min 30 de repos entre deux essais. Arrête quand la 5e répétition devient difficile ou que la technique se dégrade.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.training.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    /// Vidéo choisie, lue dans la fiche ; YouTube reste à une touche si le lecteur ne charge pas.
    private func demonstration(_ embed: URL) -> some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
            DemonstrationPlayer(embedURL: embed)
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(.rect(cornerRadius: Theme.Radius.inner))
            Link(destination: ExerciseDemonstration.url(for: item.exercise)) {
                Label("Ouvrir dans YouTube", systemImage: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.training)
            }
        }
    }

    /// Repères de technique, à lire à côté de la démonstration.
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
        var parts: [String] = strength.isEmpty ? [] : ["\(strength.count) exercice\(strength.count > 1 ? "s" : "") de force"]
        let conditioning = exercises.filter(\.isConditioning).count
        if conditioning >= 1 { parts.append("cardio") }
        if conditioning >= 2 { parts.append("marche") }
        return parts.joined(separator: " · ")
    }
}
