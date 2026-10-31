import BodyPilotCore
import Coach
import SwiftUI

/// « Ta journée en une phrase », le soir : le coach comprend, montre ce qu'il a compris, et
/// n'enregistre qu'après confirmation.
struct EveningDebriefCard: View {
    /// Repas pas encore notés, ceux que « comme prévu » coche.
    let pendingSlots: Set<MealSlot>
    let save: (EveningDebrief) -> Void
    let dismiss: () -> Void

    @State private var text: String
    @State private var draft: EveningDebrief?
    @State private var notUnderstood = false
    @FocusState private var isFocused: Bool

    private static let suggestions = [
        "Séance faite, repas comme prévu",
        "Pas de séance, je suis fatigué",
        "Gros dîner ce soir",
    ]

    init(pendingSlots: Set<MealSlot>, initialText: String? = nil, save: @escaping (EveningDebrief) -> Void, dismiss: @escaping () -> Void) {
        self.pendingSlots = pendingSlots
        self.save = save
        self.dismiss = dismiss
        _text = State(initialValue: initialText ?? "")
        _draft = State(initialValue: initialText.map { EveningDebriefParser.parse($0, pendingSlots: pendingSlots) }.flatMap { $0.isUnderstood ? $0 : nil })
    }

    var body: some View {
        CoachCard(eyebrow: "Débrief du soir", symbol: "moon.stars.fill", tint: Theme.training) {
            if let draft {
                understood(draft)
            } else {
                Text("Ta journée en une phrase ?")
                    .font(.title3.weight(.semibold))
                field
                if notUnderstood {
                    Text("Je n'ai rien reconnu. Dis par exemple « séance faite, dîner copieux ».")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(Self.suggestions, id: \.self) { suggestion in
                            Button(suggestion) { submit(suggestion) }
                                .font(.footnote.weight(.semibold))
                                .buttonStyle(.glass)
                        }
                    }
                }
                .scrollClipDisabled()
                Button("Pas ce soir", action: dismiss)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.success, trigger: draft != nil)
    }

    private var field: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("Séance faite, pizza ce soir, crevé…", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit { submit(text) }
            if !text.isEmpty {
                Button { submit(text) } label: {
                    Image(systemName: "arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Theme.training.gradient, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Envoyer")
            }
        }
        .padding(.leading, Theme.Spacing.l)
        .padding(.trailing, Theme.Spacing.s)
        .frame(minHeight: 50)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func understood(_ draft: EveningDebrief) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(draft.understoodLines, id: \.self) { line in
                    Label(line, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.training)
                }
            }
            Text(draft.coachReply)
                .font(.subheadline)
                .foregroundStyle(Color.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    save(draft)
                } label: {
                    Text("Enregistrer")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.training)
                Button {
                    withAnimation(Theme.springy) { self.draft = nil }
                } label: {
                    Text("Corriger")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func submit(_ sentence: String) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let result = EveningDebriefParser.parse(trimmed, pendingSlots: pendingSlots)
        withAnimation(Theme.springy) {
            text = trimmed
            notUnderstood = !result.isUnderstood
            draft = result.isUnderstood ? result : nil
            if result.isUnderstood { isFocused = false }
        }
    }
}
