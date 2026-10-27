import Coach
import SwiftUI

/// « Dis-le en une phrase » : le coach comprend et ajuste, sans formulaire.
struct CommandField: View {
    let apply: (InterpretedCommand) -> Void

    @State private var text = ""
    @State private var feedback: Feedback?
    @FocusState private var isFocused: Bool

    private let interpreter = CommandInterpreter()

    private enum Feedback: Equatable {
        case understood(String)
        case notUnderstood
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "sparkles")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.nutrition)
                    .symbolEffect(.bounce, value: feedback)
                TextField("Dis-le en une phrase…", text: $text)
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit(submit)
                if !text.isEmpty {
                    Button(action: submit) {
                        Image(systemName: "arrow.up")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Theme.nutrition.gradient, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Envoyer")
                }
            }
            .padding(.leading, Theme.Spacing.l)
            .padding(.trailing, Theme.Spacing.s)
            .frame(minHeight: 50)
            .glassEffect(.regular.interactive(), in: .capsule)
            .animation(Theme.springy, value: text.isEmpty)

            if let feedback {
                Group {
                    switch feedback {
                    case .understood(let summary):
                        Label("Compris : \(summary). Ton plan est ajusté.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Theme.progress)
                    case .notUnderstood:
                        Label("Je n'ai pas compris. Essaie « je mange au resto » ou « j'ai 15 min ».", systemImage: "questionmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.footnote.weight(.medium))
                .padding(.horizontal, Theme.Spacing.s)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sensoryFeedback(trigger: feedback) { _, new in
            switch new {
            case .understood: .success
            case .notUnderstood: .warning
            case nil: nil
            }
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let result = interpreter.interpret(trimmed)
        withAnimation(Theme.springy) {
            if let result, result.isUnderstood {
                apply(result)
                feedback = .understood(summary(of: result))
                text = ""
                isFocused = false
            } else {
                feedback = .notUnderstood
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            withAnimation(Theme.springy) { feedback = nil }
        }
    }

    private func summary(of command: InterpretedCommand) -> String {
        var parts = QuickAdjustment.allCases
            .filter { command.adjustments.contains($0) && !($0 == .shortOnTime && command.availableMinutes != nil) }
            .map(\.shortLabel)
        if let minutes = command.availableMinutes {
            parts.insert("\(minutes) min", at: 0)
        }
        return parts.joined(separator: ", ")
    }
}
