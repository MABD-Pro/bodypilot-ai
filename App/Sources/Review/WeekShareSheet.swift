import ProgressInsights
import SwiftUI

/// « Partager ma semaine » : une image (ou un texte) de ce qui a été fait, pour un ami, un coach ou
/// un groupe. Rien ne part sans le geste de l'utilisateur, et le poids n'apparaît jamais en valeur
/// absolue : seulement sa variation, et seulement si l'interrupteur est mis.
struct WeekShareSheet: View {
    let review: WeekReview
    let headline: String
    let weeklyWeightChangeKg: Double?
    let waistChangeCm: Double?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @AppStorage("shareShowsBody") private var showsBody = false
    /// Image rendue une fois par réglage, pas à chaque rendu : le bouton reste stable au toucher.
    @State private var image: Image?

    private var week: ShareableWeek {
        ShareableWeekBuilder.make(
            review: review, headline: headline,
            weeklyWeightChangeKg: weeklyWeightChangeKg, waistChangeCm: waistChangeCm,
            showsBody: showsBody
        )
    }

    private var hasBodyData: Bool { weeklyWeightChangeKg != nil || waistChangeCm != nil }

    var body: some View {
        let week = week
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.l) {
                    WeekShareCard(week: week)
                        .clipShape(.rect(cornerRadius: Theme.Radius.card))
                        .accessibilityElement(children: .combine)
                    if hasBodyData {
                        Toggle("Montrer l'évolution du poids et du tour de taille", isOn: $showsBody.animation(Theme.springy))
                            .font(.subheadline)
                            .padding(Theme.Spacing.l)
                            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner))
                    }
                    if let image {
                        ShareLink(item: image, preview: SharePreview("Ma semaine avec BodyPilot", image: image)) {
                            Label("Partager l'image", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                    }
                    ShareLink(item: week.text) {
                        Label("Partager en texte", systemImage: "text.bubble")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    Text("Tu choisis à qui l'envoyer. Ton poids n'y figure jamais, seulement son évolution si tu l'actives.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
            }
            .background { AppBackground() }
            .task(id: showsBody) { image = render(week) }
            .navigationTitle("Partager ma semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    /// L'image partagée : la carte seule, à la résolution de l'écran.
    @MainActor
    private func render(_ week: ShareableWeek) -> Image? {
        let renderer = ImageRenderer(content: WeekShareCard(week: week).frame(width: 360))
        renderer.scale = max(displayScale, 2)
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}

/// La carte partagée, pensée pour être lisible hors de l'app : fond plein, texte blanc.
struct WeekShareCard: View {
    let week: ShareableWeek

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Ma semaine")
                    .font(.title2.weight(.bold))
                Text(week.period)
                    .font(.subheadline.weight(.medium))
                    .opacity(0.8)
            }
            if !week.headline.isEmpty {
                Text(week.headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ForEach(week.stats) { stat in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        Image(systemName: stat.symbol)
                            .font(.body.weight(.semibold))
                            .frame(width: 24)
                        Text(stat.value)
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text(stat.label)
                            .font(.subheadline)
                            .opacity(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let highlight = week.highlight {
                Label(highlight, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "sparkles")
                Text("BodyPilot")
            }
            .font(.caption.weight(.semibold))
            .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(colors: [Theme.training, Theme.progress], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}
