import BodyPilotCore
import SwiftData
import SwiftUI

/// Accueil en trois écrans, une minute au plus. Sert aussi à modifier le profil.
struct OnboardingView: View {
    private let editing: ProfileRecord?
    /// Dernière pesée (saisie ou Santé) : le profil affiche le poids actuel, pas celui de l'inscription.
    private let currentWeightKg: Double?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileDraft
    @State private var step: Step = LaunchOptions.demoOnboardingStep.flatMap(Step.init(rawValue:)) ?? .body
    /// « Refaire le test de force » touché : appliqué seulement à l'enregistrement, pas si on annule.
    @State private var redoStrengthTest = false
    /// Profil déjà créé : une double touche sur le dernier bouton n'en crée pas un second.
    @State private var isSaved = false

    init(editing: ProfileRecord? = nil, currentWeightKg: Double? = nil) {
        self.editing = editing
        self.currentWeightKg = currentWeightKg
        var draft = editing.map { ProfileDraft($0.profile) } ?? ProfileDraft()
        if let currentWeightKg { draft.weightKg = currentWeightKg }
        _draft = State(initialValue: draft)
    }

    enum Step: Int, CaseIterable {
        case body, health, rhythm, start

        var title: String {
            switch self {
            case .body: "Parle-moi de toi"
            case .health: "Ta santé"
            case .rhythm: "Ton rythme"
            case .start: "Ton point de départ"
            }
        }

        var subtitle: String {
            switch self {
            case .body: "Objectif : perdre du gras et gagner du muscle. Tout reste sur ton iPhone."
            case .health: "Sept questions avant de commencer : le coach adapte l'intensité si besoin."
            case .rhythm: "Une séance chaque jour, dosée selon ta récupération."
            case .start: "Le coach mesure d'abord où tu en es, puis ajuste chaque jour."
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            topBar

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(step.title)
                    .font(.display(32))
                Text(step.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

            ScrollView {
                Group {
                    switch step {
                    case .body: BodyStep(draft: $draft)
                    case .health: HealthScreeningStep(screening: $draft.screening, sex: draft.sex, age: Int(draft.age))
                    case .rhythm: RhythmStep(draft: $draft)
                    case .start: StartStep(equipment: draft.equipment, redoStrengthTest: editing.map { _ in { redoStrengthTest = true } })
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            // Chaque étape repart du haut, sans reprendre le défilement de la précédente.
            .id(step)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            Button(action: next) {
                Text(step == .start ? (editing == nil ? "Voir mon plan du jour" : "Enregistrer") : "Continuer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.nutrition)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.l)
        .background { AppBackground() }
        .sensoryFeedback(.selection, trigger: step)
    }

    private var topBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                if let previous = Step(rawValue: step.rawValue - 1) {
                    withAnimation(Theme.springy) { step = previous }
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: step == .body ? "xmark" : "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .opacity(step == .body && editing == nil ? 0 : 1)
            .disabled(step == .body && editing == nil)

            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.self) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? AnyShapeStyle(Theme.nutrition.gradient) : AnyShapeStyle(Color.primary.opacity(0.12)))
                        .frame(height: 6)
                }
            }
        }
    }

    private func next() {
        if let following = Step(rawValue: step.rawValue + 1) {
            withAnimation(Theme.springy) { step = following }
            return
        }
        guard !isSaved else { return }
        draft.screening.answeredAt = .now
        var profile = draft.profile()
        if let editing {
            // Le poids de départ reste celui de l'inscription ; un poids modifié ici devient la pesée du jour.
            profile.startWeightKg = editing.startWeightKg
            // Âge inchangé : on garde la date de naissance exacte (celle de Santé, par exemple).
            if profile.age(on: .now, calendar: .current) == editing.profile.age(on: .now, calendar: .current) {
                profile.birthDate = editing.birthDate
            }
            let shown = currentWeightKg ?? editing.startWeightKg
            if abs(draft.weightKg - shown) >= 0.05 {
                context.insert(WeightRecord(date: .now, kg: draft.weightKg))
            }
            editing.update(from: profile)
            if redoStrengthTest { editing.strengthTestResetAt = .now }
            isSaved = true
            dismiss()
        } else {
            isSaved = true
            context.insert(ProfileRecord(profile))
            Telemetry.record(.onboardingCompleted)
        }
    }
}

/// Saisie en cours, convertie en `UserProfile` à la fin.
struct ProfileDraft {
    /// Un seul objectif : la recomposition. Le poids visé règle le déficit.
    var goal: Goal = .recomposition
    var sex: BiologicalSex = .male
    var age: Double = 35
    var heightCm: Double = 175
    var weightKg: Double = 80
    var targetWeightKg: Double = 74
    var activity: ActivityLevel = .light
    var trainingWeekdays: [Int] = UserProfile.defaultTrainingWeekdays(count: 3)
    var sessionMinutes: Int = 45
    var equipment: Equipment = .bodyweight
    var screening = HealthScreening()
    var id = EntityID()

    init() {}

    init(_ profile: UserProfile, now: Date = .now, calendar: Calendar = .current) {
        id = profile.id
        sex = profile.sex
        age = Double(profile.age(on: now, calendar: calendar))
        heightCm = profile.heightCm
        weightKg = profile.startWeightKg
        targetWeightKg = profile.targetWeightKg ?? profile.startWeightKg
        activity = profile.activity
        trainingWeekdays = profile.trainingWeekdays
        sessionMinutes = profile.sessionMinutes
        equipment = profile.equipment
        screening = profile.screening
    }

    func profile(now: Date = .now, calendar: Calendar = .current) -> UserProfile {
        UserProfile(
            id: id,
            sex: sex,
            birthDate: calendar.date(byAdding: .year, value: -Int(age), to: now) ?? now,
            heightCm: heightCm,
            startWeightKg: weightKg,
            targetWeightKg: targetWeightKg,
            activity: activity,
            goal: goal,
            trainingDaysPerWeek: trainingWeekdays.count,
            trainingWeekdays: trainingWeekdays,
            sessionMinutes: sessionMinutes,
            equipment: equipment,
            screening: screening
        )
    }
}

#Preview {
    OnboardingView()
        .modelContainer(AppContainer.inMemory())
}
