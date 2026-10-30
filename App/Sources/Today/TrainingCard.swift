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
    /// Dernière séance de force avant aujourd'hui (app ou Santé), pour pondérer les charges après une pause.
    var lastStrengthDay: Date?
    /// Matériel de salle : la saisie part d'une charge, sinon du poids du corps.
    var usesLoads = false
    var logLift: (LiftEntry) -> Void = { _ in }
    /// Poids et sexe, pour proposer une charge d'essai avant la première série notée.
    var bodyweightKg: Double?
    var sex: BiologicalSex = .male
    /// Test de cardio noté aujourd'hui.
    var cardioTestToday: CardioMeasure?
    var logCardioTest: (_ minutes: Double, _ heartRate: Int) -> Void = { _, _ in }
    /// Cycle de 12 semaines : semaine en cours, ou proposition d'en commencer un (salle).
    var cycleWeek: CycleWeek?
    var canStartCycle = false
    var manageCycle: () -> Void = {}
    /// Séances prévues cette semaine du cycle, et si elles ont été confirmées.
    var cycleSessions: (sessions: Int, confirmed: Bool)?
    var setCycleSessions: (Int) -> Void = { _ in }
    /// WOD de référence : temps noté aujourd'hui, et celui de la fois précédente.
    var benchmarkToday: Int?
    var previousBenchmark: Int?
    var logBenchmark: (Int) -> Void = { _ in }
    /// Paliers décalés pour la journée (kg par exercice).
    var loadShifts: [String: Double] = [:]
    var shiftLoads: (_ exercise: String, _ kg: Double) -> Void = { _, _ in }
    /// Séance retouchée pour la journée.
    var edits = SessionEdits()
    var editSession: (SessionEdits) -> Void = { _ in }
    var showHistory: (() -> Void)?

    @State private var isPreviewingWatch = false
    @State private var isLoggingCardioTest = false
    @State private var isLoggingBenchmark = false
    @State private var logging: LiftToLog?
    /// Fiche d'un atelier ou d'un exercice sans série à noter (traîneau, SkiErg…).
    @State private var station: StationItem?
    @State private var warmup: WarmupItem?
    @State private var celebration: String?
    /// Mode retouche : une touche sur un exercice ouvre ses séries, « Ajouter » en propose d'autres.
    @State private var isEditing = false
    @State private var editingExercise: ExerciseToEdit?
    @State private var isAddingExercise = false
    private let calendar = Calendar.current

    var body: some View {
        CoachCard(eyebrow: "Bouger", symbol: "figure.strengthtraining.functional", tint: Theme.training, history: showHistory) {
            if cycleWeek != nil || canStartCycle {
                cycleRow
            }
            if cycleWeek != nil, let cycleSessions {
                sessionsRow(cycleSessions)
            }
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

            if !workout.isStrengthTest && !workout.isCardioTest {
                editBar
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
                if workout.warmupMinutes > 0 {
                    ExerciseRow(
                        index: 0, name: "Échauffement", detail: "\(workout.warmupMinutes) min", isWarmup: true,
                        caption: ExerciseRow.Caption(text: "Voir les étapes", symbol: "list.bullet", tint: .secondary),
                        log: { warmup = WarmupItem(title: "Échauffement", minutes: workout.warmupMinutes, plan: warmupPlan(workout)) },
                        logHint: "Voir l'échauffement"
                    )
                }
                ForEach(Array(workout.exercises.enumerated()), id: \.offset) { index, exercise in
                    let toLog = liftToLog(exercise, isTest: workout.isStrengthTest)
                    ExerciseRow(
                        index: index + 1,
                        name: exercise.name,
                        detail: workout.isStrengthTest ? "5 rép." : workout.isCardioTest ? "1,6 km" : exercise.prescription,
                        isWarmup: false,
                        isSwapped: exercise.isSwapped,
                        caption: isEditing
                            ? ExerciseRow.Caption(text: "Modifier", symbol: "slider.horizontal.3", tint: Theme.training)
                            : toLog.map(caption) ?? exercise.recoveryCaption.map { ExerciseRow.Caption(text: $0, symbol: "figure.walk", tint: .secondary) },
                        swap: isEditing || exercise.alternatives.isEmpty ? nil : { swap(exercise.key) },
                        log: isEditing
                            ? { editingExercise = ExerciseToEdit(exercise: exercise) } as (() -> Void)?
                            : toLog.map { item -> () -> Void in { logging = item } } ?? stationAction(exercise.name),
                        logHint: isEditing ? "Modifier l'exercice" : toLog == nil ? "Voir la technique" : "Noter ta meilleure série"
                    )
                }
                if isEditing {
                    addExerciseMenu(workout)
                }
                if workout.cooldownMinutes >= 5 {
                    ExerciseRow(
                        index: workout.exercises.count + 1, name: "Retour au calme", detail: "\(workout.cooldownMinutes) min", isWarmup: true,
                        caption: ExerciseRow.Caption(text: "Voir les étapes", symbol: "list.bullet", tint: .secondary),
                        log: {
                            warmup = WarmupItem(
                                title: "Retour au calme", minutes: workout.cooldownMinutes,
                                plan: WarmupPlanner.cooldown(for: workout, atGym: usesLoads)
                            )
                        },
                        logHint: "Voir le retour au calme",
                        warmupSymbol: "wind"
                    )
                }
            }
            .sheet(item: $logging) { item in
                // Une feuille par exercice : l'état ne passe pas d'un exercice au suivant.
                LiftEntrySheet(item: item, save: { entry in save(entry) }, shiftLoads: { shiftLoads(item.exercise, $0) })
                    .id(item.id)
            }
            .sheet(item: $editingExercise) { item in
                ExerciseEditSheet(
                    exercise: item.exercise,
                    save: { volume in
                        var next = edits
                        next.volumes[item.exercise.key] = volume
                        editSession(next)
                    },
                    remove: {
                        var next = edits
                        next.removed.insert(item.exercise.key)
                        next.added.removeAll { $0 == item.exercise.key }
                        next.volumes[item.exercise.key] = nil
                        editSession(next)
                    }
                )
            }
            .sheet(item: $warmup) { item in
                WarmupSheet(item: item)
                    .id(item.id)
            }
            .sheet(item: $station) { item in
                StationSheet(exercise: item.id)
                    .id(item.id)
            }
            .sheet(isPresented: $isAddingExercise) {
                AddExerciseSheet(present: Set(workout.exercises.map(\.key))) { name in
                    var next = edits
                    next.removed.remove(name)
                    if !next.added.contains(name) { next.added.append(name) }
                    withAnimation(.snappy) { editSession(next) }
                }
            }
            .sensoryFeedback(.success, trigger: celebration) { _, new in new != nil }

            if workout.isCardioTest {
                cardioTestResult
            }
            if workout.isCycleBenchmark {
                benchmarkResult(isHyrox: workout.title == HyroxCycle.benchmarkTitle)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label(workout.intensityCue, systemImage: "gauge.with.dots.needle.33percent")
                if workout.isStrengthTest {
                    Label("Touche un exercice pour voir ses paliers et noter ta série de 5 la plus lourde.", systemImage: "chart.line.uptrend.xyaxis")
                } else if workout.hasStrength {
                    Label("Touche un exercice pour sa technique et pour noter ta meilleure série : le coach suit tes records et fait monter les charges.", systemImage: "trophy")
                }
                if !workout.isStrengthTest && !workout.isCardioTest {
                    Label("Machine prise ou matériel absent ? Touche \(Image(systemName: "arrow.triangle.2.circlepath")) pour changer d'exercice.", systemImage: "hand.tap")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let plan = training.watchPlan {
                // La séance déjà adaptée (temps, fatigue, genou) part sur la montre, guidée série par série.
                Button {
                    isPreviewingWatch = true
                    Telemetry.record(.watchPreviewOpened)
                    scheduleOnWatch(plan)
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

    /// Test de cardio : le noter, puis la forme cardio qui en découle.
    private var cardioTestResult: some View {
        Button {
            isLoggingCardioTest = true
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(symbol: cardioTestToday == nil ? "stopwatch" : "heart.fill", tint: cardioTestToday == nil ? Theme.training : Theme.progress, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    if let cardioTestToday {
                        Text("Forme cardio : \(cardioTestToday.vo2max.frenchOneDecimal) ml/kg/min")
                            .font(.subheadline.weight(.semibold))
                        Text("VO2max estimée par le test de marche. Touche pour corriger.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Noter mon test")
                            .font(.subheadline.weight(.semibold))
                        Text("Ton temps sur 1,6 km et ton pouls à l'arrivée.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
        .sheet(isPresented: $isLoggingCardioTest) {
            CardioTestSheet(save: logCardioTest)
        }
        .sensoryFeedback(.success, trigger: cardioTestToday?.vo2max)
    }

    /// WOD de référence ou test Hyrox : noter son temps, et le comparer à la fois précédente.
    private func benchmarkResult(isHyrox: Bool) -> some View {
        Button {
            isLoggingBenchmark = true
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(symbol: benchmarkToday == nil ? "stopwatch" : "flag.checkered", tint: benchmarkToday == nil ? Theme.training : Theme.progress, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    if let benchmarkToday {
                        Text("Ton temps : \(Self.clock(benchmarkToday))")
                            .font(.subheadline.weight(.semibold))
                        Text(previousBenchmark.map { previous in
                            let gain = previous - benchmarkToday
                            return gain > 0 ? "\(Self.clock(gain)) de mieux que la dernière fois (\(Self.clock(previous)))." : "La dernière fois : \(Self.clock(previous))."
                        } ?? "Première mesure : refais-le en fin de cycle pour comparer.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Noter mon temps")
                            .font(.subheadline.weight(.semibold))
                        Text(previousBenchmark.map { "La dernière fois : \(Self.clock($0))." } ?? (isHyrox ? "Du départ du premier kilomètre à l'arrivée du second." : "Du premier coup de rame au dernier rowing."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
        .sheet(isPresented: $isLoggingBenchmark) {
            BenchmarkTimeSheet(
                title: isHyrox ? HyroxCycle.benchmarkTitle : CycleConditioning.benchmarkTitle,
                detail: isHyrox ? "Ton temps pour 1 km, 50 wall balls et 1 km." : "Ton temps pour les 3 tours.",
                initial: benchmarkToday ?? previousBenchmark ?? 15 * 60, save: logBenchmark
            )
        }
        .sensoryFeedback(.success, trigger: benchmarkToday)
    }

    /// « 14 min 05 ».
    static func clock(_ seconds: Int) -> String {
        "\(seconds / 60) min \(String(format: "%02d", seconds % 60))"
    }

    /// Semaine du cycle (la semaine allégée se voit), ou de quoi en commencer un.
    private var cycleRow: some View {
        Button(action: manageCycle) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: cycleWeek?.isDeload == true ? "leaf.fill" : "chart.bar.fill")
                    .foregroundStyle(Theme.training)
                if let cycleWeek {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cycleWeek.program.title) · semaine \(cycleWeek.number) sur \(TrainingCycle.weeks)")
                            .font(.subheadline.weight(.semibold))
                        Text(cycleWeek.isDeload ? "Semaine allégée" : "Phase \(cycleWeek.phase), \(cycleWeek.phaseTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Commencer un cycle de 12 semaines")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer(minLength: Theme.Spacing.s)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// « Combien de séances cette semaine ? » : préremplie avec la moyenne récente, une touche
    /// pour confirmer ou changer. Le coach répartit force, fractionné et cardio en conséquence.
    private func sessionsRow(_ plan: (sessions: Int, confirmed: Bool)) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "calendar")
                    .foregroundStyle(Theme.training)
                Text(plan.confirmed ? "Séances cette semaine" : "Combien de séances cette semaine ?")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: Theme.Spacing.s)
                Menu {
                    ForEach(CycleSessionPlan.range, id: \.self) { count in
                        Button("\(count) séances") { setCycleSessions(count) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(plan.sessions)")
                            .monospacedDigit()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                .accessibilityLabel("\(plan.sessions) séances cette semaine, modifier")
            }
            if !plan.confirmed {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Proposé d'après tes dernières semaines.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: Theme.Spacing.s)
                    Button("C'est bon") { setCycleSessions(plan.sessions) }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.glassProminent)
                        .tint(Theme.training)
                }
                .transition(.opacity)
            }
        }
    }

    /// Pourquoi la séance est ainsi (récupération, genou, fatigue…), juste sous son titre.
    private var notes: some View {
        ForEach(training.notes, id: \.self) { note in
            CoachNote(text: note, tint: Theme.training)
        }
    }

    /// Retoucher la séance du jour, ou revenir à celle proposée.
    private var editBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                withAnimation(.snappy) { isEditing.toggle() }
            } label: {
                Label(isEditing ? "Terminé" : "Modifier la séance", systemImage: isEditing ? "checkmark.circle.fill" : "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.training)
            Spacer()
            if !edits.isEmpty {
                Button("Revenir à la proposition") {
                    withAnimation(.snappy) { editSession(SessionEdits()) }
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    /// Ouvre la liste des exercices à ajouter, rangée et cherchable.
    private func addExerciseMenu(_ workout: Workout) -> some View {
        Button {
            isAddingExercise = true
        } label: {
            Label("Ajouter un exercice", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.leading, 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.training)
    }

    /// Échauffement de la séance : les séries de montée visent la première charge du premier exercice lourd.
    private func warmupPlan(_ workout: Workout) -> WarmupPlan {
        let firstLift: (name: String, kg: Double)? = usesLoads
            ? workout.exercises.lazy.compactMap { exercise -> (name: String, kg: Double)? in
                guard let item = liftToLog(exercise, isTest: false),
                      let kg = item.wave.first?.kg ?? item.target?.kg ?? item.startingKg else { return nil }
                return (exercise.name, kg)
            }.first
            : nil
        return WarmupPlanner.warmup(for: workout, atGym: usesLoads, firstLift: firstLift)
    }

    /// Ouvre la fiche quand l'exercice en a une (ateliers Hyrox, traîneau…).
    private func stationAction(_ name: String) -> (() -> Void)? {
        guard ExerciseGuide.guide(for: name) != nil else { return nil }
        return { station = StationItem(id: name) }
    }

    /// Exercice de force aux répétitions : la meilleure série se note, pour suivre records et charges.
    private func liftToLog(_ exercise: WorkoutExercise, isTest: Bool) -> LiftToLog? {
        guard !exercise.isConditioning, case .reps(let planned) = exercise.volume else { return nil }
        let today = lifts.first { $0.exercise == exercise.name && calendar.isDateInToday($0.date) }
        let earlier = lifts.filter { !calendar.isDateInToday($0.date) }
        let guide = ExerciseGuide.guide(for: exercise.name)
        let startingKg = usesLoads ? bodyweightKg.flatMap { guide?.startingLoad(bodyweightKg: $0, sex: sex) } : nil
        let target = StrengthProgress.target(
            for: exercise.name, plannedReps: planned, percentOfMax: exercise.percentOfMax, history: earlier,
            lastStrengthDay: lastStrengthDay, on: .now, calendar: calendar
        )
        // Test refait : le premier essai part des dernières charges plutôt que de la charge d'essai.
        let firstAttemptKg = target?.kg ?? startingKg
        var wave: [RampStep] = exercise.wave.compactMap { set in
            StrengthProgress.target(
                for: exercise.name, plannedReps: set.reps, percentOfMax: set.percentOfMax, history: earlier,
                lastStrengthDay: lastStrengthDay, on: .now, calendar: calendar
            )?.kg.map { RampStep(reps: set.reps, kg: $0) }
        }
        // Sans max noté : la vague part de la charge d'essai prudente (prévue pour 6 répétitions).
        if !exercise.wave.isEmpty, wave.count != exercise.wave.count, let startingKg {
            wave = zip(exercise.wave, StrengthCycle.waveLoads(exercise.wave, startingKg: startingKg, reps: 6)).map { RampStep(reps: $0.reps, kg: $1) }
        }
        // Paliers décalés pour la journée : toutes les charges proposées bougent ensemble.
        let shift = loadShifts[exercise.name] ?? 0
        let shifted = { (kg: Double) in max(0, kg + shift) }
        let ramp = isTest ? firstAttemptKg.map { StrengthCalibration.ramp(for: exercise.name, firstAttemptKg: $0) } ?? [] : []
        return LiftToLog(
            exercise: exercise.name,
            plannedReps: planned,
            today: today,
            target: target.map { LiftTarget(kg: $0.kg.map(shifted), reps: $0.reps, isIncrease: $0.isIncrease) },
            isRecord: today.map { StrengthProgress.isRecord($0, previous: earlier) } ?? false,
            usesLoads: usesLoads,
            guide: guide,
            startingKg: startingKg.map(shifted),
            isTest: isTest,
            ramp: ramp.map { RampStep(reps: $0.reps, kg: shifted($0.kg)) },
            wave: wave.count == exercise.wave.count ? wave.map { RampStep(reps: $0.reps, kg: shifted($0.kg)) } : [],
            waveEndsWithMax: exercise.wave.last?.isPlus == true,
            backoffSets: exercise.backoffSets,
            loadShift: shift,
            shiftStep: guide?.barbell == true ? 2.5 : StrengthProgress.loadStep(for: wave.last?.kg ?? target?.kg ?? startingKg ?? 20),
            history: lifts.filter { $0.exercise == exercise.name }.sorted { $0.date > $1.date }
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
                text: "Vise \(StrengthProgress.label(kg: target.kg, reps: target.reps))\(item.waveEndsWithMax ? "+" : "")",
                symbol: target.isIncrease ? "arrow.up.right" : "scope",
                tint: target.isIncrease ? Theme.training : .secondary
            )
        }
        if let top = item.wave.last {
            return .init(text: "Essai : \(StrengthProgress.label(kg: top.kg, reps: top.reps))\(item.waveEndsWithMax ? "+" : "")", symbol: "scope", tint: .secondary)
        }
        if let start = item.startingKg {
            return .init(text: "Essai : \(StrengthProgress.label(kg: start, reps: item.plannedReps))", symbol: "scope", tint: .secondary)
        }
        return .init(text: item.usesLoads ? "Note ta charge" : "Note tes répétitions", symbol: "square.and.pencil", tint: .secondary)
    }

    /// La séance attend aussi sur la montre (app Exercice, rubrique planifiée) : la première
    /// touche demande l'autorisation de planifier, ensuite l'app la tient à jour toute seule.
    private func scheduleOnWatch(_ plan: WorkoutPlan?) {
        guard !LaunchOptions.demoData else { return }
        Task {
            // Déjà autorisé : l'écran Aujourd'hui a déjà planifié cette séance.
            guard await !WatchSchedule.isAuthorized() else { return }
            await WatchSchedule.replace(with: plan, ask: true)
        }
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
                Telemetry.record(.watchPreviewOpened)
                scheduleOnWatch(training.watchPlan)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let adjustments: Set<QuickAdjustment>
    let set: (Feeling) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Comment te sens-tu ?")
                .font(.headline)
            // Très grand texte : les trois choix s'empilent au lieu d'être tronqués.
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Theme.Spacing.s))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.s))
            layout {
                ForEach(Feeling.allCases, id: \.self) { feeling in
                    let isOn = isSelected(feeling)
                    Button {
                        set(feeling)
                    } label: {
                        Label(feeling.label, systemImage: feeling.symbol)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                    // Très grand texte : la durée passe sous le nom, qui garde toute la largeur.
                    if dynamicTypeSize.isAccessibilitySize { duration(option) }
                }
                Spacer(minLength: Theme.Spacing.s)
                if !dynamicTypeSize.isAccessibilitySize { duration(option) }
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

    @ViewBuilder
    private func duration(_ option: TrainingOption) -> some View {
        if option.day.estimatedMinutes > 0 {
            Text("\(option.day.estimatedMinutes) min")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
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
    /// Ouvre la saisie de la meilleure série, ou la fiche d'un atelier.
    var log: (() -> Void)?
    var logHint = "Noter ta meilleure série"
    /// Icône des lignes d'échauffement et de retour au calme.
    var warmupSymbol = "flame.fill"

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
                    Image(systemName: warmupSymbol)
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
                    .accessibilityHint(logHint)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

struct StationItem: Identifiable {
    let id: String
}

/// Fiche d'un atelier : technique et démonstration, en onglets, sans série à noter.
private struct StationSheet: View {
    let exercise: String

    @State private var tab: ExerciseTab = .technique

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                Text(exercise)
                    .font(.display(24))
                    .multilineTextAlignment(.center)
                Picker("Affichage", selection: $tab.animation(.snappy)) {
                    Text("Technique").tag(ExerciseTab.technique)
                    Text("Vidéo").tag(ExerciseTab.video)
                }
                .pickerStyle(.segmented)
                if tab == .video {
                    ExerciseSheetParts.video(for: exercise)
                } else if let guide = ExerciseGuide.guide(for: exercise) {
                    ExerciseSheetParts.technique(guide)
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
    }
}

struct WarmupItem: Identifiable {
    let title: String
    let minutes: Int
    let plan: WarmupPlan
    var id: String { title }
}

/// Échauffement ou retour au calme, étape par étape.
private struct WarmupSheet: View {
    let item: WarmupItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.title)
                        .font(.display(28))
                    Text("Environ \(item.minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(item.plan.blocks.enumerated()), id: \.element.id) { index, block in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("\(index + 1). \(block.title)")
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .kerning(0.6)
                            .foregroundStyle(Theme.carbs)
                        ForEach(block.steps) { step in
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                Image(systemName: symbol(step.kind))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Theme.carbs)
                                    .frame(width: 20)
                                Text(step.title)
                                    .font(.subheadline.weight(.semibold))
                                Spacer(minLength: Theme.Spacing.s)
                                Text(step.detail)
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(Theme.Spacing.m)
                            .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
                        }
                    }
                }
                ForEach(item.plan.notes, id: \.self) { note in
                    CoachNote(text: note, tint: Theme.carbs)
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
    }

    private func symbol(_ kind: WarmupStep.Kind) -> String {
        switch kind {
        case .pulse: "heart.fill"
        case .mobility: "figure.flexibility"
        case .ramp: "scalemass.fill"
        }
    }
}

/// Exercices à ajouter à la séance : la force, puis les ateliers, avec une recherche.
private struct AddExerciseSheet: View {
    /// Déjà dans la séance : pas proposés.
    let present: Set<String>
    let add: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.exercises, id: \.self) { name in
                            Button {
                                add(name)
                                dismiss()
                            } label: {
                                HStack {
                                    // Couleurs fixes : dans une List, un bouton teinte son texte.
                                    Text(name)
                                        .foregroundStyle(Color.primary)
                                    Spacer()
                                    Text(SessionEdits.addedExercise(name).prescription)
                                        .font(.subheadline)
                                        .monospacedDigit()
                                        .foregroundStyle(Color.secondary)
                                }
                                .contentShape(.rect)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Chercher un exercice")
            .navigationTitle("Ajouter un exercice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var sections: [(title: String, exercises: [String])] {
        SessionEdits.addableSections.compactMap { section in
            let names = section.exercises.filter {
                !present.contains($0) && (query.isEmpty || $0.localizedStandardContains(query))
            }
            return names.isEmpty ? nil : (section.title, names)
        }
    }
}

/// Exercice de la séance en cours de retouche.
struct ExerciseToEdit: Identifiable {
    let exercise: WorkoutExercise
    var id: String { exercise.key }
}

/// Séries et répétitions (ou durée) d'un exercice, pour la journée ; ou le retirer.
private struct ExerciseEditSheet: View {
    let exercise: WorkoutExercise
    let save: (SessionEdits.Volume) -> Void
    let remove: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sets: Int
    @State private var amount: Int

    init(exercise: WorkoutExercise, save: @escaping (SessionEdits.Volume) -> Void, remove: @escaping () -> Void) {
        self.exercise = exercise
        self.save = save
        self.remove = remove
        _sets = State(initialValue: exercise.wave.isEmpty ? exercise.sets : exercise.wave.count + exercise.backoffSets)
        switch exercise.volume {
        case .reps(let reps): _amount = State(initialValue: reps)
        case .seconds(let seconds): _amount = State(initialValue: seconds)
        }
    }

    private var isWave: Bool { !exercise.wave.isEmpty }
    private var isTimed: Bool {
        if case .seconds = exercise.volume { true } else { false }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Text(exercise.name)
                .font(.display(24))
                .multilineTextAlignment(.center)
            Stepper(value: $sets, in: (isWave ? exercise.wave.count : 1)...12) {
                HStack {
                    Text(isWave ? "Séries en tout" : "Séries")
                    Spacer()
                    Text("\(sets)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            if isWave {
                Text("5/3/1 : les 3 séries de la vague restent, tu règles les séries de 5 qui suivent.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Stepper(value: $amount, in: isTimed ? 10...3600 : 1...50, step: isTimed ? 15 : 1) {
                    HStack {
                        Text(isTimed ? "Durée" : "Répétitions")
                        Spacer()
                        Text(isTimed ? WorkoutExercise.duration(amount) : "\(amount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                save(SessionEdits.Volume(sets: sets, reps: isTimed ? nil : amount, seconds: isTimed ? amount : nil))
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
            Button("Retirer de la séance", systemImage: "minus.circle", role: .destructive) {
                remove()
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
        }
        .font(.subheadline.weight(.medium))
        .padding(Theme.Spacing.xxl)
        .adaptiveDetents(height: isWave ? 400 : 380)
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
    /// 5/3/1 : les séries de la vague (la dernière au max si `waveEndsWithMax`), puis les séries
    /// « First Set Last » à la charge de la première.
    var wave: [RampStep] = []
    var waveEndsWithMax = false
    var backoffSets = 0
    /// Décalage des paliers déjà appliqué aujourd'hui, et le pas d'un réglage.
    var loadShift = 0.0
    var shiftStep = 2.5
    /// Séries déjà notées pour cet exercice, de la plus récente à la plus ancienne.
    var history: [LiftEntry] = []
    var id: String { exercise }
}

/// Meilleure série en deux touches : charge et répétitions partent de l'objectif du jour.
/// Onglets de la fiche d'un exercice : la série à noter, la technique, la démonstration.
enum ExerciseTab: Hashable {
    case log, technique, video, history
}

private struct LiftEntrySheet: View {
    let item: LiftToLog
    let save: (LiftEntry) -> Void
    /// Décale les paliers proposés pour la journée (kg, total).
    var shiftLoads: (Double) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var withLoad: Bool
    @State private var kg: Double
    @State private var reps: Int
    /// Effort ressenti, une touche : la prochaine charge en tient compte.
    @State private var effort: SetEffort?
    @State private var tab: ExerciseTab = LaunchOptions.demoVideo ? .video : .log
    /// Décalage des paliers pour la journée ; `item` porte celui déjà appliqué à l'ouverture.
    @State private var shift: Double

    init(item: LiftToLog, save: @escaping (LiftEntry) -> Void, shiftLoads: @escaping (Double) -> Void = { _ in }) {
        self.item = item
        self.save = save
        self.shiftLoads = shiftLoads
        // 5/3/1 : la série à noter est la dernière de la vague (au max), pas l'objectif de progression.
        let waveTop = item.wave.last.map { LiftTarget(kg: $0.kg, reps: $0.reps, isIncrease: false) }
        let start = item.today.map { LiftTarget(kg: $0.kg, reps: $0.reps, isIncrease: false) } ?? waveTop ?? item.target
        let kg = start?.kg ?? (start == nil && item.usesLoads ? item.wave.last?.kg ?? item.startingKg ?? 20 : nil)
        _withLoad = State(initialValue: kg != nil)
        _kg = State(initialValue: kg ?? 10)
        _reps = State(initialValue: start?.reps ?? item.plannedReps)
        _shift = State(initialValue: item.loadShift)
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
        VStack(spacing: Theme.Spacing.l) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(item.exercise)
                    .font(.display(24))
                    .multilineTextAlignment(.center)
                Text(item.isTest
                    ? "Note ta série de 5 la plus lourde faite proprement : elle fixe tes charges de travail."
                    : "Ta meilleure série du jour. Prévu : \(item.plannedReps) répétition\(item.plannedReps > 1 ? "s" : "")\(item.waveEndsWithMax ? " ou plus" : "").")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Picker("Affichage", selection: $tab.animation(.snappy)) {
                Text("Série").tag(ExerciseTab.log)
                if item.guide != nil {
                    Text("Technique").tag(ExerciseTab.technique)
                }
                Text("Vidéo").tag(ExerciseTab.video)
                Text("Historique").tag(ExerciseTab.history)
            }
            .pickerStyle(.segmented)

            switch tab {
            case .log:
                logTab
            case .technique:
                if let guide = item.guide {
                    ExerciseSheetParts.technique(guide)
                }
            case .video:
                ExerciseSheetParts.video(for: item.exercise)
            case .history:
                historyTab
            }
        }
        .padding(Theme.Spacing.xxl)
    }

    /// Toutes les séries notées de l'exercice : le record en tête, puis séance par séance.
    @ViewBuilder
    private var historyTab: some View {
        if item.history.isEmpty {
            Text("Aucune série notée pour l'instant. Note ta meilleure série du jour dans « Série » : elle apparaîtra ici.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        } else {
            let record = StrengthProgress.record(for: item.exercise, in: item.history)
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if let record {
                    Label("Record : \(StrengthProgress.label(record.entry))", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.carbs)
                }
                ForEach(item.history, id: \.date) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Theme.locale)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: Theme.Spacing.s)
                        Text(StrengthProgress.label(entry) + (entry.isTest ? " · test" : ""))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var logTab: some View {
        VStack(spacing: Theme.Spacing.xl) {
            if !item.isTest, item.today == nil, item.target == nil, item.startingKg != nil {
                Text("Charge d'essai prudente : si tu pouvais faire plus de 3 répétitions de plus, monte la prochaine fois.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !item.ramp.isEmpty {
                ramp
            }
            if !item.wave.isEmpty {
                wave
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

            // Le test cherche la série la plus lourde : l'effort n'y a pas de sens.
            if !item.isTest {
                VStack(spacing: Theme.Spacing.s) {
                    Text("Comment était cette série ?")
                        .font(.subheadline.weight(.medium))
                    Picker("Effort", selection: $effort) {
                        ForEach(SetEffort.allCases, id: \.self) { effort in
                            Text(effort.title).tag(Optional(effort))
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(Self.effortHint(effort))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .sensoryFeedback(.selection, trigger: effort)
            }

            Button {
                save(LiftEntry(exercise: item.exercise, date: Calendar.current.storedDay(for: .now), kg: withLoad && kg > 0 ? kg : nil, reps: reps, isTest: item.isTest, effort: item.isTest ? nil : effort))
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
        }
    }

    static func effortHint(_ effort: SetEffort?) -> String {
        switch effort {
        case .easy: "3 répétitions ou plus en réserve : la charge monte la prochaine fois."
        case .right: "1 à 2 répétitions en réserve : l'effort visé."
        case .hard: "Plus rien en réserve : la charge attend, ou baisse un peu si la série n'est pas complète."
        case nil: "Facultatif : une touche aide le coach à régler la prochaine charge."
        }
    }

    /// Palier affiché : celui calculé à l'ouverture, plus le réglage fait dans la feuille.
    private func shifted(_ step: RampStep) -> RampStep {
        RampStep(reps: step.reps, kg: max(0, step.kg + shift - item.loadShift))
    }

    /// − / + : tous les paliers bougent ensemble, pour la journée.
    private var shiftControl: some View {
        HStack(spacing: Theme.Spacing.s) {
            shiftButton(symbol: "minus", by: -item.shiftStep)
            Text(shift == 0 ? "Ajuster" : "\(shift > 0 ? "+" : "−")\(abs(shift).frenchCompact) kg")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(shift == 0 ? Color.secondary : Theme.training)
                .frame(minWidth: 54)
                .contentTransition(.numericText(value: shift))
            shiftButton(symbol: "plus", by: item.shiftStep)
        }
    }

    private func shiftButton(symbol: String, by delta: Double) -> some View {
        Button {
            withAnimation(.snappy) {
                shift += delta
                if withLoad { kg = max(0, kg + delta) }
            }
            shiftLoads(shift)
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(delta > 0 ? "Paliers plus lourds" : "Paliers plus légers")
    }

    /// Montée en charge du test : échauffements, premier essai, puis essais plus lourds.
    private var ramp: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Label("Paliers", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(Theme.training)
                Spacer()
                shiftControl
            }
            ForEach(Array(item.ramp.map(shifted).enumerated()), id: \.offset) { index, step in
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
            if let attempt = item.ramp.last.map(shifted) {
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

    /// Séance 5/3/1 : les 3 séries qui montent, puis « First Set Last ».
    private var wave: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Label("5/3/1", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.training)
                Spacer()
                shiftControl
            }
            ForEach(Array(item.wave.map(shifted).enumerated()), id: \.offset) { index, step in
                let isMax = item.waveEndsWithMax && index == item.wave.count - 1
                HStack(spacing: Theme.Spacing.s) {
                    Text(isMax ? "Série \(index + 1), au max" : "Série \(index + 1)")
                        .font(.subheadline.weight(isMax ? .semibold : .regular))
                    Spacer()
                    Text(StrengthProgress.label(kg: step.kg, reps: step.reps) + (isMax ? "+" : ""))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if item.backoffSets > 0, let first = item.wave.first.map(shifted) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Puis \(item.backoffSets) séries")
                        .font(.subheadline)
                    Spacer()
                    Text(StrengthProgress.label(kg: first.kg, reps: StrengthCycle.backoffReps))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
            Text(item.waveEndsWithMax
                ? "Dernière série : autant de répétitions propres que possible, en gardant 1 répétition en réserve. Note-la : elle recalcule ton max."
                : "Semaine légère : 3 séries sans forcer, rien au maximum.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.training.opacity(0.08), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    private func counter(value: String, unit: String, numeric: Double, change: @escaping (Bool) -> Void) -> some View {
        HStack(spacing: Theme.Spacing.xl) {
            StepButton(symbol: "minus", label: "Diminuer", size: 50, font: .title3.weight(.bold)) { change(false) }
            SteppedValue(accessibilityValue: "\(value) \(unit)", decrease: { change(false) }, increase: { change(true) }) {
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
            }
            StepButton(symbol: "plus", label: "Augmenter", size: 50, font: .title3.weight(.bold)) { change(true) }
        }
    }
}

extension WorkoutExercise {
    /// Remplacé à la demande, et non par une règle de sécurité (celles-ci vident les variantes).
    var isSwapped: Bool { name != key && !alternatives.isEmpty }

    var prescription: String {
        // 5/3/1 : « 5-3-1+ · 5 × 5 ».
        if !wave.isEmpty {
            let steps = wave.map { "\($0.reps)" }.joined(separator: "-") + (wave.last?.isPlus == true ? "+" : "")
            return backoffSets > 0 ? "\(steps) · \(backoffSets) × \(StrengthCycle.backoffReps)" : steps
        }
        return switch volume {
        // Une seule série (test au chrono) : « 50 rép. » se lit mieux que « 1 × 50 ».
        case .reps(let reps) where sets == 1: "\(reps) rép."
        case .reps(let reps): "\(sets) × \(reps)"
        // Effort continu (marche inclinée, cardio tempo) : en minutes.
        case .seconds(let seconds) where sets == 1 && seconds >= 120: "\(Int((Double(seconds) / 60).rounded())) min"
        // Fractionné : la récupération passe sous le nom (recoveryCaption), le volume reste court.
        case .seconds(let seconds) where isConditioning && restSeconds > 0: "\(sets) × \(Self.duration(seconds))"
        // Tours enchaînés sans pause (WOD au chrono) : la durée n'est qu'un ordre d'idée, déjà
        // dans la durée de la séance ; un volume court laisse la place au contenu du tour.
        case .seconds where isConditioning && sets > 1: "\(sets) tours"
        case .seconds(let seconds): "\(sets) × \(Self.duration(seconds))"
        }
    }

    /// « 30 s », « 4 min », « 1 min 30 ».
    static func duration(_ seconds: Int) -> String {
        guard seconds >= 60 else { return "\(seconds) s" }
        return seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(seconds % 60)"
    }

    /// Cardio et marche inclinée, ajoutés après la force.
    var isConditioning: Bool { priority >= 4 }

    /// Marche inclinée, en côte, tranquille ou escalier (pas la marche du fermier, un atelier).
    var isWalking: Bool {
        let name = self.name.lowercased()
        return (name.contains("marche") && !name.contains("fermier")) || name.contains("escalier")
    }

    /// « Récupération 2 min » sous le nom d'un fractionné.
    var recoveryCaption: String? {
        guard isConditioning, sets > 1, restSeconds > 0, case .seconds = volume else { return nil }
        return "Récupération \(Self.duration(restSeconds))"
    }
}

extension Workout {
    /// « 4 exercices de force · cardio · marche inclinée ».
    var summary: String {
        switch title {
        case HyroxCycle.benchmarkTitle: return "course · wall balls"
        case HyroxCycle.qualityTitle: return "fractionné"
        case HyroxCycle.fundamentalsTitle: return "ateliers Hyrox"
        case HyroxCycle.easyRunTitle: return "course"
        default: break
        }
        let strength = exercises.filter { !$0.isConditioning }
        var parts: [String] = strength.isEmpty ? [] : ["\(strength.count) exercice\(strength.count > 1 ? "s" : "") de force"]
        // La marche se reconnaît à son nom (marche inclinée, en côte, escalier) : un atelier
        // ajouté (SkiErg, rameur) reste du cardio.
        let conditioning = exercises.filter(\.isConditioning)
        let walking = conditioning.filter(\.isWalking)
        if conditioning.count > walking.count { parts.append("cardio") }
        if !walking.isEmpty { parts.append("marche") }
        return parts.joined(separator: " · ")
    }
}

/// Test de marche : temps sur 1,6 km et pouls dès l'arrivée, en quelques touches.
private struct CardioTestSheet: View {
    let save: (_ minutes: Double, _ heartRate: Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 15
    @State private var seconds = 0
    @State private var heartRate = 130

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("Test de cardio")
                    .font(.display(24))
                Text("Ton temps sur 1,6 km et ton pouls à l'arrivée, lus sur la Watch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Temps")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(8...35, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    Picker("Secondes", selection: $seconds) {
                        ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("Pouls à l'arrivée")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Pouls", selection: $heartRate) {
                    ForEach(70...200, id: \.self) { Text("\($0) bpm").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }

            Button {
                save(Double(minutes) + Double(seconds) / 60, heartRate)
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
        }
        .padding(Theme.Spacing.xxl)
        .frame(maxHeight: .infinity, alignment: .top)
        .adaptiveDetents(height: 600, alsoLarge: true)
    }
}

/// Temps du WOD de référence, lu sur le chrono.
private struct BenchmarkTimeSheet: View {
    let title: String
    let detail: String
    let save: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int
    @State private var seconds: Int

    init(title: String, detail: String, initial: Int, save: @escaping (Int) -> Void) {
        self.title = title
        self.detail = detail
        self.save = save
        _minutes = State(initialValue: min(max(initial / 60, 5), 60))
        _seconds = State(initialValue: initial % 60 / 5 * 5)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.display(24))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutes) {
                    ForEach(5...60, id: \.self) { Text("\($0) min").tag($0) }
                }
                Picker("Secondes", selection: $seconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d s", $0)).tag($0) }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)

            Button {
                save(minutes * 60 + seconds)
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.training)
        }
        .padding(Theme.Spacing.xxl)
        .adaptiveDetents(height: 400)
    }
}

/// Technique et démonstration, partagées par la saisie d'une série et la fiche d'un atelier.
@MainActor
private enum ExerciseSheetParts {
    /// Vidéo choisie, lue dans la fiche ; YouTube reste à une touche si le lecteur ne charge pas.
    static func demonstration(_ embed: URL, exercise: String) -> some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.s) {
            DemonstrationPlayer(embedURL: embed)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background {
                    ZStack {
                        Color.black
                        ProgressView()
                            .tint(.white)
                    }
                }
                .clipShape(.rect(cornerRadius: Theme.Radius.inner))
            Link(destination: ExerciseDemonstration.url(for: exercise)) {
                Label("Ouvrir dans YouTube", systemImage: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.training)
            }
        }
    }

    /// Onglet Vidéo : la vidéo choisie, sinon une recherche YouTube.
    @ViewBuilder
    static func video(for exercise: String) -> some View {
        if let embed = ExerciseDemonstration.embedURL(for: exercise) {
            demonstration(embed, exercise: exercise)
        } else {
            Link(destination: ExerciseDemonstration.url(for: exercise)) {
                Label("Chercher une démonstration sur YouTube", systemImage: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.training)
            }
            .padding(.top, Theme.Spacing.l)
        }
    }

    /// Repères de technique, à lire à côté de la démonstration.
    static func technique(_ guide: ExerciseGuide) -> some View {
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
}
