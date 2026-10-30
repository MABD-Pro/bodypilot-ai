import ProgressInsights
import SwiftUI

/// « Comment s'est passée ta semaine ? » : une humeur en une touche, puis ce qui a coincé.
/// Chaque touche est enregistrée tout de suite et recalcule les 3 priorités.
struct WeekFeelingCard: View {
    let feeling: WeekFeeling?
    let save: (WeekFeeling) -> Void

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.s), GridItem(.flexible(), spacing: Theme.Spacing.s)]

    var body: some View {
        CoachCard(eyebrow: "Ton ressenti", symbol: "heart.text.square.fill", tint: Theme.protein) {
            Text(feeling.map { "Ta semaine : \($0.mood.label.lowercased())" } ?? "Comment s'est passée ta semaine ?")
                .font(.headline)
            HStack(spacing: Theme.Spacing.s) {
                ForEach(WeekMood.allCases, id: \.self) { mood in
                    moodButton(mood)
                }
            }
            if let feeling {
                Text("Ce qui a coincé")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(WeekObstacle.allCases, id: \.self) { obstacle in
                        obstacleButton(obstacle, in: feeling)
                    }
                }
            } else {
                Text("Une touche suffit. Le coach en tire tes 3 priorités de la semaine.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func moodButton(_ mood: WeekMood) -> some View {
        let selected = feeling?.mood == mood
        return Button {
            withAnimation(Theme.springy) {
                save(WeekFeeling(mood: mood, obstacles: feeling?.obstacles ?? []))
            }
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: mood.symbol)
                    .font(.title3)
                    .symbolRenderingMode(.multicolor)
                Text(mood.label)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(selected ? Theme.protein.opacity(0.18) : Color.primary.opacity(0.05), in: .rect(cornerRadius: Theme.Radius.inner))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.inner)
                    .strokeBorder(selected ? Theme.protein : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func obstacleButton(_ obstacle: WeekObstacle, in feeling: WeekFeeling) -> some View {
        let selected = feeling.obstacles.contains(obstacle)
        return Button {
            var updated = feeling
            if selected { updated.obstacles.remove(obstacle) } else { updated.obstacles.insert(obstacle) }
            withAnimation(Theme.springy) { save(updated) }
        } label: {
            Label(obstacle.label, systemImage: selected ? "checkmark.circle.fill" : obstacle.symbol)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.s)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .foregroundStyle(selected ? Theme.protein : .primary)
                .background(selected ? Theme.protein.opacity(0.14) : Color.primary.opacity(0.05), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Les 3 priorités de la semaine, numérotées.
struct WeekPrioritiesCard: View {
    let priorities: [WeekAdvice]
    let fromFeeling: Bool

    var body: some View {
        CoachCard(eyebrow: "Tes \(priorities.count) priorité\(priorities.count > 1 ? "s" : "") de la semaine", symbol: "list.number", tint: Theme.training) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(Array(priorities.enumerated()), id: \.offset) { index, priority in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        Text("\(index + 1)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Theme.training, in: .circle)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 7 }
                        Text(priority.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if !fromFeeling {
                Text("Donne ton ressenti juste au-dessus : les priorités tiendront compte de ce qui a coincé.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
