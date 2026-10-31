import BodyPilotCore
import Coach
import Nutrition
import ProgressInsights
import SwiftData
import SwiftUI
import Training
import WorkoutKit

/// Écran principal : répond aux trois questions du jour et s'adapte en une touche.
struct TodayView: View {
    let profileRecord: ProfileRecord

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("healthWeightSync") private var healthSync = false
    @AppStorage(CoachNotifications.enabledKey) private var coachReminders = true
    /// Jour du dernier débrief du soir (enregistré ou écarté), au format 2026-10-30.
    @AppStorage("eveningDebriefDay") private var eveningDebriefDone = ""
    /// Débrief traité pendant ce lancement (la démo ignore le jour enregistré).
    @State private var eveningDebriefHandled = false
    @State private var isShowingEatingCareHelp = false
    /// Change à chaque choix sur la carte du garde-fou, pour la recalculer.
    @State private var eatingCareRevision = 0
    @Query(sort: \WeightRecord.date) private var weights: [WeightRecord]
    @Query private var dayLogs: [DayLogRecord]
    @Query(filter: #Predicate<WaistRecord> { !$0.isScan }, sort: \WaistRecord.date) private var waists: [WaistRecord]
    @Query(sort: \LiftRecord.day) private var liftRecords: [LiftRecord]
    @Query(sort: \CardioTestRecord.day) private var cardioTests: [CardioTestRecord]
    @State private var isAddingWaist = false
    @State private var describing: MealToDescribe?
    @State private var isAddingWeight = false
    @State private var isEditingProfile = false
    @State private var isManagingData = false
    @State private var isEditingPrivacy = false
    @State private var isShowingGuides = LaunchOptions.demoGuides
    @State private var isManagingCycle = false
    @State private var isAnsweringScreening = false
    @State private var isShowingHistory = LaunchOptions.demoHistory != nil
    @State private var isShowingReview = LaunchOptions.demoReview != nil
    @State private var isShowingWhatIf = LaunchOptions.demoWhatIf != nil
    @State private var isShowingGroceries = LaunchOptions.demoGroceries
    /// Données du jour pour « Mes 7 derniers jours », partagées par référence.
    @State private var reviewContext = WeekReviewContext()
    /// Ce que l'historique montre en s'ouvrant : la partie ou l'élément touché.
    @State private var historyFocus = HistoryView.Focus.section(.measures)
    /// Entraînements lus dans Santé (Watch, autres apps), pour la semaine et la régularité.
    @State private var healthActivities: [ActivitySample] = []
    /// Sommeil de la nuit passée, lu dans Santé.
    @State private var sleepHours: Double?
    /// Sommeil moyen des 7 dernières nuits (Santé).
    @State private var averageSleepHours: Double?
    /// Forme cardio estimée par la Watch et pouls au repos, lus dans Santé.
    @State private var watchCardio: CardioMeasure?
    @State private var restingHeartRate: Double?
    /// Premiers jours des dernières règles, lus dans Santé (femmes seulement).
    @State private var periodStarts: [Date] = []
    /// Taux de gras et masse maigre écrits dans Santé par la balance.
    @State private var compositions: [BodyCompositionEntry] = []
    /// Pas par jour lus dans Santé (14 jours et aujourd'hui).
    @State private var dailySteps: [DailySteps] = []

    private let calendar = Calendar.current

    /// Les lectures Santé du lancement précédent servent tout de suite : l'objectif du jour ne
    /// change plus quand Santé répond, sauf si ses données ont vraiment bougé.
    init(profileRecord: ProfileRecord) {
        self.profileRecord = profileRecord
        guard UserDefaults.standard.bool(forKey: "healthWeightSync"), let snapshot = HealthSnapshotStore.last() else { return }
        _healthActivities = State(initialValue: snapshot.activities)
        _sleepHours = State(initialValue: snapshot.sleepHours)
        _averageSleepHours = State(initialValue: snapshot.averageSleepHours)
        _watchCardio = State(initialValue: snapshot.watchCardio)
        _restingHeartRate = State(initialValue: snapshot.restingHeartRate)
        _periodStarts = State(initialValue: snapshot.periodStarts)
        _compositions = State(initialValue: snapshot.compositions)
        _dailySteps = State(initialValue: snapshot.dailySteps)
    }

    var body: some View {
        let now = Date.now
        let todayLog = log(on: now)
        let todayAdjustments = todayLog?.adjustments ?? []
        let doneLogs = dayLogs.filter(\.workoutDone)
        let completed = doneLogs.map { (day: $0.day, title: $0.doneWorkoutTitle) }
        let lastStrength = DayLogEditor.lastStrength(before: now, completed: completed, samples: healthActivities, calendar: calendar)
        let activeDays = DayLogEditor.activeDays(before: now, completed: completed, samples: healthActivities, calendar: calendar)
        let cycleSessions = profileRecord.cycleSessions(
            on: now, recentAverage: CycleSessionPlan.recentAverage(doneDays: Array(activeDays), before: now, calendar: calendar), calendar: calendar
        )
        let lifts = liftRecords.map(\.entry)
        let cardioMeasures = cardioTests.map(\.measure) + [watchCardio].compactMap { $0 }
        let cardio = DayLogEditor.cardioStatus(for: profileRecord.profile, measures: cardioMeasures, restingHeartRate: restingHeartRate, on: now, calendar: calendar)
        let averageSteps = StepActivity.average(dailySteps, excluding: healthActivities, before: now, calendar: calendar)
        let measuredExpenditure = EnergyBalance.measured(
            intakes: dayLogs.compactMap { log in log.eatenKcal.map { IntakeDay(day: log.day, kcal: $0) } },
            weights: weights.map(\.entry), on: now, calendar: calendar
        )
        let exerciseKcal = ExerciseEnergy.dailyAverage(
            samples: healthActivities, completed: completed,
            sessionMinutes: profileRecord.profile.sessionMinutes,
            weightKg: weights.last?.kg ?? profileRecord.startWeightKg, on: now, calendar: calendar
        )
        let plan = CoachFactory.coach.plan(
            for: profileRecord.profile,
            weights: weights.map(\.entry),
            waists: waists.map(\.entry),
            compositions: bodyCompositions,
            adjustments: todayAdjustments,
            availableMinutes: todayLog?.availableMinutes,
            eatingOutSlot: todayLog?.eatingOutSlot,
            exerciseSwaps: todayLog?.exerciseSwaps ?? [:],
            mealIntakes: todayLog?.mealIntakes ?? [:],
            describedMeals: todayLog?.describedMeals ?? [:],
            lastWorkoutTitle: lastStrength.title,
            lastStrengthDay: lastStrength.day,
            calibratedLifts: DayLogEditor.calibratedLifts(lifts, before: now, since: profileRecord.strengthTestResetAt, lastStrengthDay: lastStrength.day, calendar: calendar),
            sleepHours: sleepHours,
            averageSleepHours: averageSleepHours,
            activeDays: activeDays,
            recentActivities: healthActivities,
            trainingChoice: todayLog?.trainingChoice,
            cardio: cardio,
            exerciseKcalPerDay: exerciseKcal,
            cycle: profileRecord.cycle,
            cycleWorkoutsThisWeek: profileRecord.cycle?.workoutsThisWeek(completed, on: now, calendar: calendar) ?? [],
            cycleSessionsPerWeek: cycleSessions?.sessions,
            averageDailySteps: averageSteps,
            measuredExpenditure: measuredExpenditure,
            on: now
        )
        // Journée complète (les quatre repas notés) : ses calories servent à mesurer la dépense.
        let eatenToday = plan.meals.meals.allSatisfy(\.isEaten) ? plan.meals.eatenTotals.kcal.rounded() : nil
        let proteinReachedToday = plan.targets.macros.proteinG > 0
            && plan.meals.eatenTotals.proteinG >= plan.targets.macros.proteinG * FloorWeek.proteinReached
        let floorWeek = floorWeekProgress(completed: completed, now: now)
        let comeback = floorWeek == nil ? currentComeback(now: now) : nil
        let eatingCare = eatingCareSignals(target: plan.targets.macros.kcal, trend: plan.trend, now: now)
        let reminders = CoachReminders.plan(
            lastActivity: activityDays().max(), floorWeekUntil: profileRecord.floorWeekUntil,
            floorStrengthSessions: floorWeek?.strengthSessions ?? 0, now: now, calendar: calendar
        )
        let widgetSnapshot = WidgetBridge.snapshot(
            plan: plan, training: (todayLog?.sessionEdits ?? SessionEdits()).apply(to: plan.training),
            workoutDone: todayLog?.workoutDone ?? false, now: now, calendar: calendar
        )

        let reviewToday: WeekReviewToday = WeekReviewToday(
            plan: plan,
            workoutDone: todayLog?.workoutDone ?? false,
            healthActivities: healthActivities,
            compositions: bodyCompositions,
            dailySteps: dailySteps,
            stepsGoal: steps(average: averageSteps, now: now)?.goal
        )

        let activityAnalyzer = WeekActivityAnalyzer(calendar: calendar)
        let week = activityAnalyzer.week(
            of: now,
            samples: healthActivities,
            completed: completed,
            sessionMinutes: profileRecord.profile.sessionMinutes
        )
        let checkIn = profileRecord.isCheckInDue(at: now)
            ? CoachFactory.coach.weeklyCheckIn(
                for: profileRecord.profile,
                weights: weights.map(\.entry),
                waists: waists.map(\.entry),
                compositions: bodyCompositions,
                exerciseKcalPerDay: exerciseKcal,
                retainsWater: profileRecord.profile.sex == .female
                    && MenstrualCycle.retainsWater(periodStarts: periodStarts, on: now, calendar: calendar),
                averageDailySteps: averageSteps,
                measuredExpenditure: measuredExpenditure,
                on: now
            )
            : nil

        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header(plan: plan, date: now)
                        if LaunchOptions.demoEatingCare != nil ? eatingCareRevision == 0 : EatingCareStore.shows(eatingCare, on: now, calendar: calendar) {
                            EatingCareCard(
                                signals: eatingCare,
                                pause: {
                                    withAnimation(Theme.springy) {
                                        if LaunchOptions.demoEatingCare == nil { EatingCareStore.startPause(on: now, calendar: calendar) }
                                        eatingCareRevision += 1
                                    }
                                },
                                showHelp: { isShowingEatingCareHelp = true },
                                dismiss: {
                                    withAnimation(Theme.springy) {
                                        if LaunchOptions.demoEatingCare == nil { EatingCareStore.snoozedAt = now }
                                        eatingCareRevision += 1
                                    }
                                }
                            )
                        }
                        if let comeback {
                            ComebackCard(comeback: comeback, startFloorWeek: startFloorWeek, dismiss: {
                                withAnimation(Theme.springy) { profileRecord.comebackDismissedAt = .now }
                                try? context.save()
                            })
                        }
                        if let floorWeek {
                            FloorWeekCard(progress: floorWeek, stop: {
                                withAnimation(Theme.springy) { profileRecord.floorWeekUntil = calendar.startOfDay(for: .now) }
                                try? context.save()
                            })
                        }
                        if let debriefDay = eveningDebriefDay(now: now) {
                            EveningDebriefCard(
                                pendingSlots: pendingMealSlots(in: log(on: debriefDay)),
                                isAfterMidnight: !calendar.isDate(debriefDay, inSameDayAs: now),
                                initialText: LaunchOptions.demoDebrief.flatMap { $0 == "YES" ? nil : $0 },
                                save: { saveDebrief($0, for: debriefDay) },
                                dismiss: {
                                    withAnimation(Theme.springy) {
                                        eveningDebriefDone = Self.dayKey(debriefDay, calendar: calendar)
                                        eveningDebriefHandled = true
                                    }
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if !profileRecord.screening.isAnswered {
                            screeningBanner
                        }
                        CommandField(apply: apply)
                        AdjustmentBar(active: todayAdjustments, toggle: toggle)
                        NutritionCard(targets: plan.targets, meals: plan.meals, logIntake: logIntake, describe: { slot in
                            describing = MealToDescribe(slot: slot, current: todayLog?.describedMeals[slot])
                        }, recent: { slot in
                            RecentMeals.list(for: slot, history: recentMealHistory(now: now), today: now, calendar: calendar)
                        }, reuse: { slot, meal in
                            saveDescribed(meal, for: slot)
                        }, showHistory: { slot in showHistory(slot.map { .meal($0) } ?? .section(.meals)) }, showGroceries: { isShowingGroceries = true })
                            .id("nutrition")
                        TrainingCard(
                            training: (todayLog?.sessionEdits ?? SessionEdits()).apply(to: plan.training),
                            options: plan.trainingOptions,
                            choice: todayLog?.trainingChoice ?? plan.trainingOptions.recommended,
                            choose: chooseTraining,
                            adjustments: todayAdjustments,
                            setFeeling: setFeeling,
                            swap: swapExercise,
                            isDone: todayLog?.workoutDone ?? false,
                            toggleDone: { toggleWorkoutDone(title: plan.training.workoutTitle) },
                            startSession: WorkoutLiveActivity.isAvailable ? { workout in Task { await WorkoutLiveActivity.start(workout) } } : nil,
                            week: week,
                            healthLinked: healthLink == .on,
                            lifts: lifts,
                            lastStrengthDay: lastStrength.day,
                            usesLoads: profileRecord.profile.equipment == .gym,
                            logLift: logLift,
                            bodyweightKg: weights.last?.kg ?? profileRecord.startWeightKg,
                            sex: profileRecord.profile.sex,
                            cardioTestToday: cardioTests.last { calendar.isDateInToday($0.day) }?.measure,
                            logCardioTest: logCardioTest,
                            cycleWeek: profileRecord.cycle?.week(on: now, calendar: calendar),
                            // Pas de cycle (séries au maximum, fractionné) tant qu'un avis médical est attendu.
                            canStartCycle: profileRecord.profile.equipment == .gym && !profileRecord.screening.restrictsIntensity,
                            manageCycle: { isManagingCycle = true },
                            cycleSessions: cycleSessions,
                            setCycleSessions: { sessions in
                                withAnimation(Theme.springy) { profileRecord.confirmCycleSessions(sessions, on: .now, calendar: calendar) }
                                try? context.save()
                            },
                            benchmarkToday: todayLog?.benchmarkSeconds,
                            previousBenchmark: dayLogs.filter { !calendar.isDateInToday($0.day) && $0.benchmarkSeconds != nil }.max { $0.day < $1.day }?.benchmarkSeconds,
                            logBenchmark: logBenchmark,
                            loadShifts: todayLog?.loadShifts ?? [:],
                            shiftLoads: { exercise, kg in
                                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                                log.loadShifts[exercise] = kg
                                try? context.save()
                            },
                            edits: todayLog?.sessionEdits ?? SessionEdits(),
                            editSession: { edits in
                                let log = DayLogEditor.todayLog(in: context, calendar: calendar)
                                withAnimation(Theme.springy) { log.sessionEdits = edits }
                                try? context.save()
                            },
                            showHistory: { showHistory(.section(.sessions)) }
                        )
                            .id("training")
                        ProgressCard(
                            trend: plan.trend,
                            message: plan.progressMessage,
                            profile: profileRecord.profile,
                            health: healthLink,
                            checkIn: checkIn,
                            waistCm: waists.last?.cm,
                            waistChange: plan.waistChangeCm,
                            composition: plan.composition,
                            records: StrengthProgress.records(in: lifts),
                            relativeStrength: RelativeStrength.compute(history: lifts, weights: weights.map(\.entry), on: now, calendar: calendar),
                            cardio: CardioTest.latest(cardioMeasures),
                            cardioZone: cardio.moderateHeartRate,
                            sleepHours: sleepHours,
                            steps: steps(average: averageSteps, now: now),
                            phase: plan.phase,
                            maintenanceOffer: profileRecord.isMaintenanceWeekDue(phase: plan.phase, on: now, calendar: calendar) || (LaunchOptions.demoMaintenanceOffer && profileRecord.maintenanceWeekUntil == nil),
                            acceptMaintenance: { withAnimation(Theme.springy) { profileRecord.startMaintenanceWeek(on: now, calendar: calendar) } },
                            dismissMaintenance: { withAnimation(Theme.springy) { profileRecord.maintenanceOfferDismissedAt = .now } },
                            addWeight: { isAddingWeight = true },
                            addWaist: { isAddingWaist = true },
                            acceptCheckIn: { acceptCheckIn(checkIn) },
                            dismissCheckIn: { withAnimation(Theme.springy) { profileRecord.lastCheckInAt = .now } },
                            connectHealth: { Task { await connectHealth() } },
                            disconnectHealth: {
                                healthSync = false
                                HealthSnapshotStore.clear()
                            },
                            showHistory: showHistory,
                            showReview: { isShowingReview = true },
                            projection: WeightProjector.project(entries: weights.map(\.entry), trend: plan.trend, targetKg: profileRecord.targetWeightKg, on: now, calendar: calendar),
                            showWhatIf: { isShowingWhatIf = true }
                        )
                        .id("progress")
                        .modifier(WeekReviewLink(
                            isPresented: $isShowingReview, profileRecord: profileRecord, context: reviewContext, today: reviewToday
                        ))
                    }
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                    .animation(Theme.springy, value: plan)
                }
                .scrollIndicators(.hidden)
                .task {
                    if LaunchOptions.demoActivities { healthActivities = DemoData.activities() }
                    if LaunchOptions.demoComposition { compositions = DemoData.compositions() }
                    if LaunchOptions.demoSteps { dailySteps = DemoData.steps() }
                    if let hours = LaunchOptions.demoSleepHours { sleepHours = hours }
                    if let hours = LaunchOptions.demoSleepAverage { averageSleepHours = hours }
                    if LaunchOptions.demoData && !LaunchOptions.demoCardioTest {
                        watchCardio = DemoData.watchCardio()
                        restingHeartRate = 58
                    }
                    guard let target = LaunchOptions.demoScrollTarget else { return }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                }
            }
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Mon profil", systemImage: "person.crop.circle") {
                        Button("Mon profil", systemImage: "person") { isEditingProfile = true }
                        Button("Mes données", systemImage: "externaldrive") { isManagingData = true }
                        Button("Conseils et sources", systemImage: "books.vertical") { isShowingGuides = true }
                        Button("Confidentialité", systemImage: "hand.raised") { isEditingPrivacy = true }
                        if profileRecord.profile.isOnDeficitPause(on: now) {
                            Button("Reprendre le déficit", systemImage: "play.circle") {
                                withAnimation(Theme.springy) {
                                    EatingCareStore.pauseUntil = nil
                                    eatingCareRevision += 1
                                }
                            }
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: todayAdjustments)
            .onChange(of: proteinReachedToday, initial: true) { _, reached in
                profileRecord.recordFloorProtein(reached, on: now, calendar: calendar)
            }
            .onChange(of: eatenToday, initial: true) { _, kcal in
                guard let record = log(on: now), record.eatenKcal != kcal else { return }
                record.eatenKcal = kcal
            }
            .onChange(of: plan.training.workoutTitle, initial: true) { _, title in
                DisplayedWorkout.remember(title, on: now, calendar: calendar)
            }
            .onChange(of: widgetSnapshot, initial: true) { _, snapshot in
                WidgetBridge.publish(snapshot)
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                // Repas et séance cochés depuis un widget ou le Centre de contrôle.
                if phase == .active, !LaunchOptions.demoData { WidgetBridge.applyPending(in: context) }
            }
            .onChange(of: scenePhase) { _, phase in
                // Tout ce qui a été touché est écrit avant que l'app ne passe en arrière-plan.
                if phase != .active { try? context.save() }
                // Copie du jour dans le dossier choisi, si l'utilisateur l'a demandée.
                if phase == .background, !LaunchOptions.demoData { AutoBackup.runIfDue(context: context) }
            }
            .sensoryFeedback(.selection, trigger: todayLog?.exerciseSwapsRaw.count ?? 0)
            .task(id: scenePhase) {
                // À chaque retour dans l'app : les pesées de la balance arrivent toutes seules.
                guard scenePhase == .active, healthSync else { return }
                // Déjà relié avant l'envoi des repas : Santé demande une fois l'autorisation d'écrire.
                if !LaunchOptions.demoData { try? await HealthWeight.requestAccess(includeCycle: tracksCycle) }
                await importFromHealth()
                await exportMeals(plan.meals, on: now)
            }
            .task(id: WatchScheduleKey(training: (todayLog?.sessionEdits ?? SessionEdits()).apply(to: plan.training), isDone: todayLog?.workoutDone ?? false, isActive: scenePhase == .active)) {
                // La séance choisie attend sur la montre ; faite, elle en disparaît.
                guard scenePhase == .active, !LaunchOptions.demoData else { return }
                let training = (todayLog?.sessionEdits ?? SessionEdits()).apply(to: plan.training)
                await WatchSchedule.replace(with: (todayLog?.workoutDone ?? false) ? nil : training.watchPlan, ask: false, now: now, calendar: calendar)
            }
            .task(id: ReminderKey(reminders: reminders, enabled: coachReminders, isActive: scenePhase == .active)) {
                // Rappels rares : décrochage et semaine plancher, reprogrammés à chaque changement
                // et au retour dans l'app (l'autorisation a pu être donnée entre-temps).
                guard scenePhase == .active, !LaunchOptions.demoData else { return }
                await CoachNotifications.reschedule(reminders, enabled: coachReminders)
            }
            .task(id: [String(healthSync)] + HealthMealExport(calendar: calendar).entries(for: plan.meals, on: now, now: now).map(\.fingerprint)) {
                // Un repas pris, décrit, modifié ou annulé : Santé suit aussitôt.
                await exportMeals(plan.meals, on: now)
            }
            .navigationDestination(isPresented: $isShowingGroceries) {
                GroceryListView(targets: plan.targets, profile: profileRecord.profile)
            }
            .navigationDestination(isPresented: $isShowingHistory) {
                HistoryView(healthActivities: healthActivities, compositions: bodyCompositions, dailySteps: dailySteps, focus: historyFocus)
            }
            .sheet(isPresented: $isAddingWeight) {
                WeightEntrySheet(initialKg: weights.last?.kg ?? profileRecord.startWeightKg)
            }
            .sheet(item: $describing) { item in
                MealDescriptionSheet(slot: item.slot, initial: item.current) { meal in
                    saveDescribed(meal, for: item.slot)
                }
            }
            .sheet(isPresented: $isShowingEatingCareHelp) {
                EatingCareHelpSheet()
            }
            .sheet(isPresented: $isShowingWhatIf) {
                if let target = profileRecord.targetWeightKg {
                    WhatIfSheet(entries: weights.map(\.entry), trend: plan.trend, targetKg: target, now: now, scenario: LaunchOptions.demoWhatIf ?? .none)
                }
            }
            .sheet(isPresented: $isAddingWaist) {
                WaistEntrySheet(initialCm: waists.last?.cm ?? 90)
            }
            .sheet(isPresented: $isAnsweringScreening) {
                HealthScreeningSheet(profile: profileRecord)
            }
            .sheet(isPresented: $isManagingCycle) {
                CycleSheet(profile: profileRecord)
            }
            .sheet(isPresented: $isEditingPrivacy) {
                PrivacySheet()
            }
            .sheet(isPresented: $isShowingGuides) {
                CoachGuidesSheet(screening: profileRecord.screening)
            }
            .sheet(isPresented: $isManagingData) {
                DataBackupSheet()
            }
            .sheet(isPresented: $isEditingProfile) {
                OnboardingView(editing: profileRecord, currentWeightKg: weights.last?.kg)
            }
        }
    }

    /// Jours où quelque chose a été noté : repas, séance cochée, série, pesée.
    private func activityDays() -> [Date] {
        dayLogs.filter { !$0.mealIntakesRaw.isEmpty || $0.describedMealsData != nil || $0.workoutDone }.map(\.day)
            + liftRecords.map(\.day)
            + weights.map(\.date)
    }

    private func currentComeback(now: Date) -> Comeback? {
        if LaunchOptions.demoComeback {
            return Comeback.detect(activityDays: [calendar.date(byAdding: .day, value: -6, to: now) ?? now], since: profileRecord.createdAt.addingTimeInterval(-30 * 86_400), on: now, calendar: calendar)
        }
        if let dismissed = profileRecord.comebackDismissedAt, calendar.isDate(dismissed, inSameDayAs: now) { return nil }
        return Comeback.detect(activityDays: activityDays(), since: profileRecord.createdAt, on: now, calendar: calendar)
    }

    private func floorWeekProgress(completed: [(day: Date, title: String?)], now: Date) -> FloorWeekProgress? {
        guard let end = profileRecord.floorWeekUntil, profileRecord.profile.isOnFloorWeek(on: now) else { return nil }
        let strengthDays = completed.filter { $0.title.map(TrainingPlanner.isStrengthSession) == true }.map(\.day)
            + healthActivities.filter { $0.kind == .strength && $0.minutes >= 20 }.map(\.start)
        return FloorWeekProgress.evaluate(
            until: end, strengthDays: strengthDays, proteinReachedDays: profileRecord.floorProteinDays,
            weighIns: weights.map(\.date), on: now, calendar: calendar
        )
    }

    private func startFloorWeek() {
        withAnimation(Theme.springy) { profileRecord.startFloorWeek(on: .now, calendar: calendar) }
        try? context.save()
        Telemetry.record(.floorWeekStarted)
        CoachNotifications.floorWeekStarted(until: profileRecord.floorWeekUntil)
    }

    private func acceptCheckIn(_ suggestion: CalorieSuggestion?) {
        guard let suggestion else { return }
        withAnimation(Theme.springy) {
            profileRecord.calorieAdjustmentKcal += suggestion.deltaKcal
            profileRecord.lastCheckInAt = .now
        }
        Telemetry.record(.weeklyCheckInApplied)
    }

    private var healthLink: HealthLink {
        if LaunchOptions.demoHealth { return .on }
        guard HealthWeight.isAvailable else { return .unavailable }
        return healthSync ? .on : .off
    }

    private func connectHealth() async {
        do {
            try await HealthWeight.requestAccess(includeCycle: tracksCycle)
        } catch {
            AppLog.health.error("Autorisation Santé refusée ou impossible : \(error.localizedDescription, privacy: .public)")
            return
        }
        healthSync = true
        await importFromHealth()
    }

    /// Repas mangés du jour → Santé ; un repas annulé ou sauté en est retiré.
    private func exportMeals(_ meals: DayMealPlan, on day: Date) async {
        guard healthSync, HealthWeight.isAvailable, !LaunchOptions.demoData else { return }
        let export = HealthMealExport(calendar: calendar)
        await HealthMeals.shared.sync(
            export.entries(for: meals, on: day, now: .now),
            ids: MealSlot.allCases.map { export.id(for: $0, on: day) }
        )
    }

    /// Toutes les lectures Santé partent en même temps, puis l'écran change une seule fois :
    /// le plan se recalcule une fois au lieu d'une fois par lecture.
    private func importFromHealth() async {
        guard !LaunchOptions.demoData else { return }
        let calendar = calendar
        let readsCycle = tracksCycle
        let weightsSince = calendar.date(byAdding: .day, value: -HealthWeight.lookbackDays, to: .now) ?? .now
        let activitiesSince = calendar.date(byAdding: .weekOfYear, value: -HealthWorkouts.lookbackWeeks, to: .now) ?? .now
        async let weightSamples = try? HealthWeight.samples(since: weightsSince)
        async let activities = try? HealthWorkouts.samples(since: activitiesSince)
        async let sleep = try? HealthSleep.lastNightHours(calendar: calendar)
        async let averageSleep = try? HealthSleep.averageHours(calendar: calendar)
        async let measure = try? HealthCardio.latestVO2max()
        async let resting = try? HealthCardio.restingHeartRate()
        async let values = HealthProfile.read(calendar: calendar)
        async let starts: [Date]? = readsCycle ? (try? HealthCycle.periodStarts(calendar: calendar)) : nil
        async let entries = HealthBodyComposition.entries(calendar: calendar)
        async let steps = try? HealthSteps.daily(calendar: calendar)
        let read = await (weights: weightSamples, activities: activities, sleep: sleep, averageSleep: averageSleep, measure: measure,
                          resting: resting, values: values, starts: starts, entries: entries, steps: steps)

        let toImport = read.weights.map {
            WeightImportPlanner(calendar: calendar).samplesToImport(
                $0,
                recordedDays: Set(weights.map { calendar.startOfDay(for: $0.date) }),
                knownIDs: Set(weights.compactMap(\.externalID))
            )
        } ?? []
        withAnimation(Theme.springy) {
            for sample in toImport {
                context.insert(WeightRecord(sample))
            }
            if let activities = read.activities { healthActivities = activities }
            if let hours = read.sleep { sleepHours = hours }
            if let hours = read.averageSleep { averageSleepHours = hours }
            watchCardio = read.measure
            restingHeartRate = read.resting
            if let starts = read.starts { periodStarts = starts }
            compositions = read.entries
            if let steps = read.steps { dailySteps = steps }
            // Taille, date de naissance et sexe de Santé : le profil suit, les besoins se recalculent.
            if let height = read.values.heightCm, abs(height - profileRecord.heightCm) >= 1 {
                profileRecord.heightCm = height
            }
            if let birthDate = read.values.birthDate, !calendar.isDate(birthDate, inSameDayAs: profileRecord.birthDate) {
                profileRecord.birthDate = birthDate
            }
            if let sex = read.values.sex, sex.rawValue != profileRecord.sexRaw {
                profileRecord.sexRaw = sex.rawValue
            }
        }
        try? context.save()
        HealthSnapshotStore.save(HealthSnapshot(
            savedAt: .now, activities: healthActivities, sleepHours: sleepHours, averageSleepHours: averageSleepHours,
            watchCardio: watchCardio, restingHeartRate: restingHeartRate, periodStarts: periodStarts,
            compositions: compositions, dailySteps: dailySteps
        ))
    }

    private var tracksCycle: Bool { profileRecord.profile.sex == .female }

    /// Pas du jour et objectif, une fois des pas lus dans Santé.
    private func steps(average: Double?, now: Date) -> StepsToday? {
        guard !dailySteps.isEmpty else { return nil }
        let age = profileRecord.profile.age(on: now, calendar: calendar)
        return StepsToday(
            today: dailySteps.last { calendar.isDate($0.day, inSameDayAs: now) }?.steps ?? 0,
            goal: StepActivity.goal(averageSteps: average, age: age),
            average: average
        )
    }

    /// Une balance qui n'écrit que le taux de gras : la masse maigre se déduit de la pesée du même jour.
    /// Une masse maigre incohérente avec le poids et le taux de gras (plus de 5 kg d'écart) est écartée.
    private var bodyCompositions: [BodyCompositionEntry] {
        compositions.map { entry in
            var entry = entry
            if let fat = entry.fatPercent,
               let weight = weights.last(where: { calendar.isDate($0.date, inSameDayAs: entry.date) }) {
                let derived = weight.kg * (1 - fat / 100)
                if let lean = entry.leanKg, abs(lean - derived) > 5 { entry.leanKg = nil }
                if entry.leanKg == nil { entry.leanKg = derived }
            }
            return entry
        }
    }

    /// Test de marche noté : la forme cardio du jour, un seul test par jour.
    private func logCardioTest(minutes: Double, heartRate: Int) {
        let profile = profileRecord.profile
        let vo2max = CardioTest.vo2max(
            minutes: minutes, heartRate: heartRate,
            weightKg: weights.last?.kg ?? profile.startWeightKg,
            age: profile.age(on: .now, calendar: calendar), sex: profile.sex
        )
        withAnimation(Theme.springy) {
            if let existing = cardioTests.last(where: { calendar.isDateInToday($0.day) }) {
                existing.minutes = minutes
                existing.heartRate = heartRate
                existing.vo2max = vo2max
            } else {
                context.insert(CardioTestRecord(day: calendar.storedDay(for: .now), minutes: minutes, heartRate: heartRate, vo2max: vo2max))
            }
        }
        try? context.save()
    }

    private func chooseTraining(_ choice: TrainingChoice) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            // Une autre proposition : la séance retouchée pour l'ancienne ne s'applique plus.
            if log.trainingChoice != choice { log.sessionEdits = SessionEdits() }
            log.trainingChoice = choice
        }
        try? context.save()
    }

    /// « Comment te sens-tu ? » : en forme efface fatigue et courbatures, les autres s'activent ou s'éteignent.
    private func setFeeling(_ feeling: Feeling) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            var adjustments = log.adjustments
            switch feeling {
            case .great: adjustments.subtract([.tired, .sore])
            case .sore: adjustments.formSymmetricDifference([.sore])
            case .tired: adjustments.formSymmetricDifference([.tired])
            }
            log.adjustments = adjustments
            // Le ressenti change la recommandation : on la suit plutôt qu'un ancien choix.
            log.trainingChoice = nil
        }
        try? context.save()
    }

    /// Profil créé avant le questionnaire de santé : on le propose une fois, sans bloquer.
    private var screeningBanner: some View {
        Button { isAnsweringScreening = true } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconBadge(symbol: "stethoscope", tint: Theme.protein, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Questionnaire de santé")
                        .font(.subheadline.weight(.semibold))
                    Text("Sept questions, 30 secondes : le coach adapte l'intensité si besoin.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }

    private func header(plan: TodayPlan, date: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Theme.locale)).capitalizingFirstLetter)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(greeting(at: date))
                .font(.display(34))
            Text(plan.headline)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(.top, Theme.Spacing.s)
    }

    private func greeting(at date: Date) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<5: "Bonne nuit"
        case 5..<12: "Bonjour"
        case 12..<18: "Bon après-midi"
        default: "Bonsoir"
        }
    }

    private func log(on date: Date) -> DayLogRecord? {
        dayLogs.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    private func todayLog() -> DayLogRecord {
        if let existing = log(on: .now) { return existing }
        let created = DayLogRecord(day: calendar.storedDay(for: .now))
        context.insert(created)
        return created
    }

    private func toggle(_ adjustment: QuickAdjustment) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            var current = log.adjustments
            if current.contains(adjustment) {
                current.remove(adjustment)
                if adjustment == .shortOnTime { log.availableMinutes = nil }
                if adjustment == .eatingOut { log.eatingOutSlot = nil }
            } else {
                current.insert(adjustment)
                // Le repas visé est fixé maintenant : il ne bascule plus au dîner à 15 h.
                if adjustment == .eatingOut, log.eatingOutSlot == nil {
                    log.eatingOutSlot = MealConstraints.nextMainMeal(at: .now, calendar: calendar)
                }
            }
            log.adjustments = current
        }
    }

    /// Un exercice ne convient pas (poste occupé, matériel absent) : variante suivante, pour la journée.
    private func swapExercise(key: String) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.exerciseSwapsRaw.append(key)
        }
    }

    /// Repas pris : `nil` annule la saisie. Les repas suivants se recalculent aussitôt.
    private func logIntake(_ slot: MealSlot, _ intake: MealIntake?) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.mealIntakes[slot] = intake
            if intake == nil { log.describedMeals[slot] = nil }
        }
    }

    /// Repas décrits des 7 derniers jours (seuls ces journaux sont décodés).
    private func showHistory(_ focus: HistoryView.Focus) {
        historyFocus = focus
        isShowingHistory = true
    }

    private func recentMealHistory(now: Date) -> [(day: Date, meals: [MealSlot: DescribedMeal])] {
        guard let since = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return [] }
        return dayLogs
            .filter { $0.day >= since && $0.describedMealsData != nil }
            .map { (day: $0.day, meals: $0.describedMeals) }
    }

    /// Repas décrit en texte : il remplace la saisie d'une touche pour ce repas.
    private func saveDescribed(_ meal: DescribedMeal, for slot: MealSlot) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.describedMeals[slot] = meal
            log.mealIntakes[slot] = nil
        }
        try? context.save()
        Telemetry.record(.mealDescribed)
    }

    /// Meilleure série du jour : une seule par exercice, la dernière saisie la remplace.
    private func logLift(_ entry: LiftEntry) {
        withAnimation(Theme.springy) {
            if let existing = liftRecords.first(where: { $0.exercise == entry.exercise && calendar.isDate($0.day, inSameDayAs: entry.date) }) {
                existing.kg = entry.kg
                existing.reps = entry.reps
                existing.isTest = entry.isTest
                existing.effortRaw = entry.effort?.rawValue
            } else {
                context.insert(LiftRecord(entry))
            }
        }
        try? context.save()
    }

    private func logBenchmark(_ seconds: Int) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.benchmarkSeconds = seconds
        }
    }

    private func toggleWorkoutDone(title: String?) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            log.workoutDone.toggle()
            log.doneWorkoutTitle = log.workoutDone ? title : nil
        }
        // Séance cochée à la main : le suivi de l'écran verrouillé n'a plus lieu d'être.
        if log.workoutDone { Task { await WorkoutLiveActivity.endAll() } }
    }

    /// Signaux du garde-fou alimentaire sur les 14 derniers jours (en démo : imposés).
    private func eatingCareSignals(target: Double, trend: WeightTrend, now: Date) -> Set<EatingCareSignal> {
        if let demo = LaunchOptions.demoEatingCare { return demo == "purging" ? [.purging] : [.restriction] }
        guard !LaunchOptions.demoData else { return [] }
        _ = eatingCareRevision
        let days = dayLogs.map { log in
            EatingCareDay(day: log.day, completeKcal: log.eatenKcal, skippedMeals: log.mealIntakes.values.filter { $0 == .skipped }.count)
        }
        return EatingCare.signals(
            days: days, targetKcal: target, floorKcal: SafetyLimits.minimumKcal(for: profileRecord.profile.sex), trend: trend,
            manualWeighIns: weights.filter { $0.sourceRaw == WeightSource.manual.rawValue }.map(\.date),
            distressDays: EatingCareStore.distressDays, purgingDays: EatingCareStore.purgingDays, on: now, calendar: calendar
        )
    }

    /// Jour à raconter : de 18 h à 4 h du matin, une fois par jour. En démo, seulement sur demande
    /// (captures à heure fixe), et le jour même.
    private func eveningDebriefDay(now: Date) -> Date? {
        if LaunchOptions.demoDebrief != nil { return eveningDebriefHandled ? nil : calendar.startOfDay(for: now) }
        guard !LaunchOptions.demoData, let day = EveningDebrief.day(for: now, calendar: calendar),
              eveningDebriefDone != Self.dayKey(day, calendar: calendar)
        else { return nil }
        return day
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Repas ni cochés ni décrits aujourd'hui.
    private func pendingMealSlots(in log: DayLogRecord?) -> Set<MealSlot> {
        Set(MealSlot.allCases)
            .subtracting(log?.mealIntakes.keys.map { $0 } ?? [])
            .subtracting(log?.describedMeals.keys.map { $0 } ?? [])
    }

    /// Débrief confirmé : repas et séance du jour raconté, ressenti posé sur le lendemain.
    private func saveDebrief(_ debrief: EveningDebrief, for day: Date) {
        func record(on date: Date) -> DayLogRecord {
            if let existing = DayLogEditor.log(on: date, in: context, calendar: calendar) { return existing }
            let created = DayLogRecord(day: calendar.storedDay(for: date))
            context.insert(created)
            return created
        }
        let log = record(on: day)
        withAnimation(Theme.springy) {
            if !debrief.meals.isEmpty { log.mealIntakes.merge(debrief.meals) { _, new in new } }
            if debrief.workoutDone == true, !log.workoutDone {
                log.workoutDone = true
                log.doneWorkoutTitle = DisplayedWorkout.title(on: day, calendar: calendar) ?? nil
            }
            eveningDebriefDone = Self.dayKey(day, calendar: calendar)
            eveningDebriefHandled = true
        }
        if !debrief.tomorrow.isEmpty, let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) {
            let next = record(on: tomorrow)
            next.adjustments = next.adjustments.union(debrief.tomorrow)
        }
        if debrief.workoutDone == true { Task { await WorkoutLiveActivity.endAll() } }
        try? context.save()
        Telemetry.record(.eveningDebriefSaved)
    }

    /// Phrase libre comprise : on ajoute les ajustements, sans retirer ceux déjà choisis.
    private func apply(_ command: InterpretedCommand) {
        let log = todayLog()
        withAnimation(Theme.springy) {
            DayLogEditor.apply(command, to: log)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(AppContainer.preview)
}

/// Repas en cours de description, pour présenter la feuille de saisie.
private struct MealToDescribe: Identifiable {
    let slot: MealSlot
    let current: DescribedMeal?
    var id: String { slot.rawValue }
}

/// « Mes 7 derniers jours » : destination de navigation et données du jour transmises par référence.
private struct WeekReviewLink: ViewModifier {
    @Binding var isPresented: Bool
    let profileRecord: ProfileRecord
    let context: WeekReviewContext
    let today: WeekReviewToday

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $isPresented) {
                WeekReviewView(profileRecord: profileRecord, context: context)
            }
            .onChange(of: today, initial: true) { _, today in
                context.today = today
            }
    }
}

/// Ce qui change la séance planifiée sur la montre.
private struct WatchScheduleKey: Equatable {
    let training: TrainingDay
    let isDone: Bool
    let isActive: Bool
}

private struct ReminderKey: Equatable {
    var reminders: [PlannedReminder]
    var enabled: Bool
    var isActive: Bool
}
