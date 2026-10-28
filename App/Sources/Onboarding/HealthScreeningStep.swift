import BodyPilotCore
import SwiftData
import SwiftUI

/// Questionnaire de santé (PAR-Q+) : 7 questions par oui ou non, puis les situations où le coach
/// ne fixe pas de déficit. Un oui ne bloque rien : le coach reste sur un effort modéré.
struct HealthScreeningStep: View {
    @Binding var screening: HealthScreening
    let sex: BiologicalSex
    let age: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ForEach(ScreeningQuestion.allCases, id: \.self) { question in
                row(question.text, isOn: binding(question))
            }

            if !screening.yes.isEmpty {
                note(
                    symbol: "stethoscope",
                    tint: Theme.protein,
                    title: "Parles-en à ton médecin",
                    text: "En attendant son avis, le coach reste sur un effort modéré : ni test de force, ni fractionné, ni série au maximum. Marche, cardio doux et musculation légère restent proposés."
                )
                row("Mon médecin m'a donné son accord pour une activité sans restriction", isOn: $screening.medicalClearance, tint: Theme.progress)
            }

            Text("Situations particulières")
                .font(.headline)
                .padding(.top, Theme.Spacing.s)
            ForEach(NoDeficitSituation.allCases.filter { $0 != .pregnancy || sex == .female }, id: \.self) { situation in
                row(situation.title, isOn: binding(situation))
            }
            if !screening.situations.isEmpty || age < HealthScreening.adultAge {
                note(
                    symbol: "heart.text.square.fill",
                    tint: Theme.nutrition,
                    title: "Pas de déficit calorique",
                    text: "Le coach vise l'équilibre et garde les protéines. Pour un objectif de poids, fais-toi accompagner par un professionnel de santé."
                )
            }
            Text("Questions inspirées du PAR-Q+. Tes réponses restent sur ton iPhone.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sensoryFeedback(.selection, trigger: screening)
    }

    private func binding(_ question: ScreeningQuestion) -> Binding<Bool> {
        Binding {
            screening.yes.contains(question)
        } set: { isOn in
            withAnimation(Theme.springy) {
                if isOn { screening.yes.insert(question) } else { screening.yes.remove(question) }
                // Plus aucun oui : l'accord du médecin n'a plus d'objet.
                if screening.yes.isEmpty { screening.medicalClearance = false }
            }
        }
    }

    private func binding(_ situation: NoDeficitSituation) -> Binding<Bool> {
        Binding {
            screening.situations.contains(situation)
        } set: { isOn in
            withAnimation(Theme.springy) {
                if isOn { screening.situations.insert(situation) } else { screening.situations.remove(situation) }
            }
        }
    }

    private func row(_ text: String, isOn: Binding<Bool>, tint: Color = Theme.training) -> some View {
        Toggle(isOn: isOn) {
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .tint(tint)
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }

    private func note(symbol: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            IconBadge(symbol: symbol, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: Theme.Radius.inner + 4))
        .transition(.opacity)
    }
}

/// Questionnaire proposé une fois aux profils créés avant son arrivée.
struct HealthScreeningSheet: View {
    let profile: ProfileRecord

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var screening: HealthScreening

    init(profile: ProfileRecord) {
        self.profile = profile
        _screening = State(initialValue: profile.screening)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    Text("Sept questions, trente secondes : le coach adapte l'intensité si besoin.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    HealthScreeningStep(screening: $screening, sex: profile.profile.sex, age: profile.profile.age(on: .now, calendar: .current))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background { AppBackground() }
            .navigationTitle("Ta santé")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Plus tard") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        screening.answeredAt = .now
                        profile.screening = screening
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
