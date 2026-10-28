import BodyPilotCore
import SwiftUI

/// « Conseils et sources » : ce que le coach ne règle pas tout seul (créatine, fibres, sommeil),
/// et les études sur lesquelles reposent ses règles. Texte fixe, rien à saisir.
struct CoachGuidesSheet: View {
    /// Questionnaire de santé : un « oui » renvoie vers le médecin avant toute créatine.
    let screening: HealthScreening

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    guide(
                        title: "Créatine", symbol: "bolt.circle.fill", tint: Theme.training,
                        lines: [
                            "Le complément le mieux étudié pour la musculation : un peu plus de force et de muscle quand elle accompagne l'entraînement.",
                            "Créatine monohydrate, 3 à 5 g par jour, tous les jours, à n'importe quelle heure. La phase de charge n'est pas nécessaire.",
                            "Elle fait prendre 1 à 2 kg d'eau les premières semaines : la balance monte, le tour de taille non. Le coach compte sur la tendance, pas sur une pesée.",
                            "Facultative : sans elle, le programme marche aussi.",
                        ],
                        warning: screening.yes.isEmpty && screening.situations.isEmpty
                            ? "Pas avant 18 ans, ni enceinte, ni avec une maladie des reins : demande l'avis de ton médecin."
                            : "Tu as répondu oui au questionnaire de santé : demande l'avis de ton médecin avant d'en prendre."
                    )
                    guide(
                        title: "Fibres et produits peu transformés", symbol: "leaf.fill", tint: Theme.progress,
                        lines: [
                            "Vise 30 g de fibres par jour : des légumes à chaque repas, des fruits entiers, des légumineuses et des céréales complètes.",
                            "Préfère les aliments peu transformés : à calories offertes égales, les produits ultra-transformés font manger environ 500 kcal de plus par jour.",
                            "Quand tu décris un repas, le coach compte les calories et les protéines, pas encore les fibres.",
                        ]
                    )
                    guide(
                        title: "Sommeil", symbol: "bed.double.fill", tint: Theme.protein,
                        lines: [
                            "Au moins 7 h par nuit. En déficit, un sommeil court fait perdre plus de muscle et moins de gras.",
                            "Avec Santé reliée, le coach lit ta nuit et ta moyenne des 7 dernières nuits, et propose du cardio modéré plutôt que du lourd après une nuit de moins de 6 h.",
                        ]
                    )
                    sources
                }
                .padding(Theme.Spacing.xl)
            }
            .navigationTitle("Conseils et sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .background { AppBackground() }
        }
    }

    private func guide(title: String, symbol: String, tint: Color, lines: [String], warning: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let warning {
                CoachNote(text: warning, tint: .orange)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label("Sources", systemImage: "books.vertical.fill")
                .font(.headline)
            Text("Les règles du coach reposent sur ces travaux : synthèses, méta-analyses et recommandations d'organismes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Self.references, id: \.topic) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.topic)
                        .font(.subheadline.weight(.semibold))
                    ForEach(group.items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.inner + 4))
    }

    /// Références de docs/COACH_RULES.md et docs/TRAINING_EVIDENCE.md, par thème.
    static let references: [(topic: String, items: [String])] = [
        ("Santé avant l'effort", [
            "Warburton et al., 2011, PAR-Q+, Health & Fitness Journal of Canada",
            "Riebe et al., 2015, dépistage de l'ACSM, Med Sci Sports Exerc",
        ]),
        ("Calories et dépense", [
            "Mifflin et al., 1990, métabolisme de base, Am J Clin Nutr",
            "Hall et al., 2011, adaptation de la dépense, Lancet",
            "Tudor-Locke & Bassett, 2004, paliers de pas, Sports Med",
            "Paluch et al., 2022, pas et mortalité, Lancet Public Health",
            "Ainsworth et al., 2011, Compendium des activités, Med Sci Sports Exerc",
        ]),
        ("Protéines et phase", [
            "Morton et al., 2018, protéines et muscle, Br J Sports Med",
            "Helms et al., 2014, protéines en déficit, J Int Soc Sports Nutr",
            "Barakat et al., 2020, recomposition, Strength Cond J",
            "Iraki et al., 2019, prise de muscle sèche, Sports",
            "Ashwell et al., 2012, tour de taille / taille, Obes Rev",
            "Peos et al., 2021, pauses à l'équilibre (ICECAP), Med Sci Sports Exerc",
        ]),
        ("Musculation", [
            "ACSM, 2009, progression en musculation, Med Sci Sports Exerc",
            "Schoenfeld et al., 2017, charges et hypertrophie, J Strength Cond Res",
            "Schoenfeld, Ogborn & Krieger, 2017, volume par muscle, J Sports Sci",
            "Refalo et al., 2023, proximité de l'échec, Sports Med",
            "Helms et al., 2016, répétitions en réserve, Strength Cond J",
            "Schumann et al., 2022, cardio et musculation, Sports Med",
            "Fragala et al., 2019, musculation des seniors, J Strength Cond Res",
        ]),
        ("Récupération et compléments", [
            "Watson et al., 2015, durée de sommeil, Sleep",
            "Nedeltcheva et al., 2010, sommeil et perte de gras, Ann Intern Med",
            "Kreider et al., 2017, créatine (ISSN), J Int Soc Sports Nutr",
            "Hall et al., 2019, aliments ultra-transformés, Cell Metab",
            "ANSES, 2016, repères de consommation (fibres)",
        ]),
    ]
}
