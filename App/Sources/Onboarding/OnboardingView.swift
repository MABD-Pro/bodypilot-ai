import BodyPilotCore
import SwiftData
import SwiftUI

/// Accueil en trois écrans, une minute au plus. Sert aussi à modifier le profil.
struct OnboardingView: View {
    private let editing: ProfileRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileDraft
    @State private var step: Step = .goal

    init(editing: ProfileRecord? = nil) {
        self.editing = editing
        _draft = State(initialValue: editing.map { ProfileDraft($0.profile) } ?? ProfileDraft())
    }

    enum Step: Int, CaseIterable {
        case goal, body, rhythm

        var title: String {
            switch self {
            case .goal: "Quel est ton objectif ?"
            case .body: "Parle-moi de toi"
            case .rhythm: "Ton rythme"
            }
        }

        var subtitle: String {
            switch self {
            case .goal: "Je construis ton plan autour de ça. Tu pourras changer d'avis."
            case .body: "Pour calculer tes besoins. Tout reste sur ton iPhone."
            case .rhythm: "Je cale les séances sur ta semaine, pas l'inverse."
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
                    case .goal: GoalStep(draft: $draft)
                    case .body: BodyStep(draft: $draft)
                    case .rhythm: RhythmStep(draft: $draft)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollIndicators(.hidden)

            Button(action: next) {
                Text(step == .rhythm ? (editing == nil ? "Voir mon plan du jour" : "Enregistrer") : "Continuer")
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
                Image(systemName: step == .goal ? "xmark" : "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .opacity(step == .goal && editing == nil ? 0 : 1)
            .disabled(step == .goal && editing == nil)

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
        let profile = draft.profile()
        if let editing {
            editing.update(from: profile)
            dismiss()
        } else {
            context.insert(ProfileRecord(profile))
        }
    }
}

/// Saisie en cours, convertie en `UserProfile` à la fin.
struct ProfileDraft {
    var goal: Goal = .loseFat
    var sex: BiologicalSex = .male
    var age: Double = 35
    var heightCm: Double = 175
    var weightKg: Double = 80
    var targetWeightKg: Double = 74
    var activity: ActivityLevel = .light
    var trainingDays: Int = 3
    var sessionMinutes: Int = 45
    var equipment: Equipment = .bodyweight
    var id = EntityID()

    init() {}

    init(_ profile: UserProfile, now: Date = .now, calendar: Calendar = .current) {
        id = profile.id
        goal = profile.goal
        sex = profile.sex
        age = Double(profile.age(on: now, calendar: calendar))
        heightCm = profile.heightCm
        weightKg = profile.startWeightKg
        targetWeightKg = profile.targetWeightKg ?? profile.startWeightKg
        activity = profile.activity
        trainingDays = profile.trainingDaysPerWeek
        sessionMinutes = profile.sessionMinutes
        equipment = profile.equipment
    }

    func profile(now: Date = .now, calendar: Calendar = .current) -> UserProfile {
        UserProfile(
            id: id,
            sex: sex,
            birthDate: calendar.date(byAdding: .year, value: -Int(age), to: now) ?? now,
            heightCm: heightCm,
            startWeightKg: weightKg,
            targetWeightKg: goal == .maintain ? nil : targetWeightKg,
            activity: activity,
            goal: goal,
            trainingDaysPerWeek: trainingDays,
            sessionMinutes: sessionMinutes,
            equipment: equipment
        )
    }
}

#Preview {
    OnboardingView()
        .modelContainer(AppContainer.inMemory())
}
