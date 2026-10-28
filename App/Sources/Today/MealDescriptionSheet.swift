import BodyPilotCore
import Nutrition
import PhotosUI
import SwiftUI
import UIKit

/// « Qu'as-tu vraiment mangé ? » en une phrase : le coach estime, demande une précision si besoin.
struct MealDescriptionSheet: View {
    let slot: MealSlot
    let save: (DescribedMeal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var parse: MealParse?
    /// Portion choisie pour chaque aliment dont la quantité était devinée (indice → facteur).
    @State private var portions: [Int: Double] = [:]
    /// Aliments retirés par l'utilisateur (indices dans l'estimation).
    @State private var removed: Set<Int> = []
    /// Quantité réglée sans chiffre (« un peu moins », « le double »), par aliment.
    @State private var scales: [Int: Double] = [:]
    /// Aliment remplacé par un équivalent, par indice d'origine.
    @State private var replacements: [Int: DescribedFood] = [:]
    @State private var isAnalyzing = false
    @FocusState private var isEditing: Bool
    @State private var photo: UIImage?
    @State private var pickedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var isReadingPhoto = false
    @State private var photoNotRecognized = false

    init(slot: MealSlot, initial: DescribedMeal?, save: @escaping (DescribedMeal) -> Void) {
        self.slot = slot
        self.save = save
        _text = State(initialValue: initial?.text ?? "")
        _parse = State(initialValue: initial.map { MealParse(text: $0.text, foods: $0.foods) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Qu'as-tu mangé \(slot.inTheMeal) ?")
                            .font(.display(26))
                        Text("Comme tu le dirais : « une grande assiette de pâtes carbo et un coca ».")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    photoButtons

                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .clipShape(.rect(cornerRadius: Theme.Radius.inner))
                            .overlay {
                                if isReadingPhoto {
                                    ProgressView("Je regarde ton assiette…")
                                        .padding(Theme.Spacing.m)
                                        .glassEffect(.regular, in: .capsule)
                                }
                            }
                            .transition(.opacity)
                    }

                    if photoNotRecognized {
                        CoachNote(text: "Je n'ai pas reconnu ce repas sur la photo. Décris-le en quelques mots, je m'occupe du reste.", tint: slot.tint)
                    }

                    TextField("Ton repas", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($isEditing)
                        .submitLabel(.done)
                        .onSubmit { Task { await analyze() } }
                        .padding(Theme.Spacing.m)
                        .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: Theme.Radius.inner))

                    if parse == nil || isEditing {
                        Button {
                            Task { await analyze() }
                        } label: {
                            Label(isAnalyzing ? "J'analyse…" : "Estimer", systemImage: "sparkles")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(slot.tint)
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
                    }

                    if let parse {
                        result(parse)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        guard let meal else { return }
                        save(meal)
                        dismiss()
                    }
                    .disabled(meal == nil || isEditing)
                }
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await read(image)
                }
                pickedItem = nil
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image in
                isShowingCamera = false
                if let image { Task { await read(image) } }
            }
            .ignoresSafeArea()
        }
        .onChange(of: text) { _, new in
            if new != parse?.text { parse = nil; portions = [:]; removed = []; scales = [:]; replacements = [:] }
        }
    }

    /// Repas à enregistrer : les aliments reconnus, avec les portions précisées.
    private var meal: DescribedMeal? {
        guard let parse else { return nil }
        let foods = kept(of: parse).map(\.food)
        return foods.isEmpty ? nil : DescribedMeal(text: parse.text, foods: foods)
    }

    /// Aliments gardés, avec leur indice d'origine et la portion précisée.
    private func kept(of parse: MealParse) -> [(index: Int, food: DescribedFood)] {
        parse.foods.enumerated().compactMap { index, original in
            guard !removed.contains(index) else { return nil }
            var food = base(of: parse, at: index)
            if replacements[index] == nil, food.needsPortion, let factor = portions[index],
               let choice = MealTextParser.portionChoices.first(where: { $0.factor == factor }) {
                food = food.resized(by: factor, label: choice.factor == 1 ? "Portion normale" : "\(choice.label) portion")
            }
            if let scale = scales[index], scale != 1, let amount = Self.amounts.first(where: { $0.factor == scale }) {
                food = food.resized(by: scale, label: "\(food.quantityLabel), \(amount.label.lowercased())")
            }
            return (index, food)
        }
    }

    /// L'aliment saisi, ou son remplaçant choisi dans « Remplacer par ».
    private func base(of parse: MealParse, at index: Int) -> DescribedFood {
        replacements[index] ?? parse.foods[index]
    }

    /// Quantités sans chiffre, appliquées à la portion lue.
    static let amounts: [(label: String, factor: Double)] = [
        ("La moitié", 0.5), ("Un peu moins", 0.75), ("Comme indiqué", 1), ("Un peu plus", 1.25), ("Le double", 2),
    ]

    @ViewBuilder
    private func result(_ parse: MealParse) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            // Le total et les suggestions d'abord : sous les aliments, ils passaient sous le pli.
            if let meal {
                HStack(alignment: .firstTextBaseline) {
                    Text("≈ \(meal.macros.kcal.frenchInteger) kcal")
                        .font(.display(24))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: meal.macros.kcal))
                    Spacer()
                    Text("P \(Int(meal.macros.proteinG.rounded())) · G \(Int(meal.macros.carbsG.rounded())) · L \(Int(meal.macros.fatG.rounded())) g")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text("Une estimation, pas une pesée : la suite de ta journée s'ajuste à ce total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                suggestions(for: meal)
            }

            ForEach(kept(of: parse), id: \.index) { item in
                // La question disparaît dès qu'une quantité est choisie : le menu sous le nom reste là pour la changer.
                let unanswered = portions[item.index] == nil && scales[item.index] == nil
                foodRow(item.food, base: base(of: parse, at: item.index),
                        question: unanswered && replacements[item.index] == nil && parse.foods[item.index].needsPortion,
                        index: item.index)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            if !parse.unrecognized.isEmpty {
                CoachNote(
                    text: "Je ne connais pas « \(parse.unrecognized.joined(separator: " », « ")) ». Précise les aliments (« agneau, semoule, légumes ») ou une quantité en grammes.",
                    tint: slot.tint
                )
            }
        }
    }

    /// « Plus léger » ou « plus de protéines » : une touche remplace le repas estimé.
    @ViewBuilder
    private func suggestions(for meal: DescribedMeal) -> some View {
        let suggestions = MealImprover.suggestions(for: meal, slot: slot)
        if suggestions.isEmpty {
            Label("Repas équilibré : rien à changer", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.progress)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Pour la prochaine fois, ou si tu n'as pas encore mangé")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(suggestions) { suggestion in
                    Button {
                        withAnimation(Theme.springy) {
                            parse = MealParse(text: suggestion.meal.text, foods: suggestion.meal.foods)
                            portions = [:]
                            removed = []
                            scales = [:]
                            replacements = [:]
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            Image(systemName: suggestion.goal == .lighter ? "leaf.fill" : "bolt.heart.fill")
                                .foregroundStyle(suggestion.goal == .lighter ? Theme.progress : Theme.protein)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(.subheadline.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                Text(suggestion.effect)
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: Theme.Spacing.s)
                            Text("Appliquer")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(slot.tint)
                        }
                        .padding(Theme.Spacing.m)
                        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, Theme.Spacing.s)
        }
    }

    private func foodRow(_ food: DescribedFood, base: DescribedFood, question: Bool, index: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.subheadline.weight(.semibold))
                    adjustMenu(food, base: base, index: index)
                }
                Spacer()
                Text("\(food.macros.kcal.frenchInteger) kcal")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: food.macros.kcal))
                Button {
                    withAnimation(Theme.springy) { _ = removed.insert(index) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Retirer \(food.name)")
            }
            if question {
                Text("Quelle quantité ?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(slot.tint)
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(MealTextParser.portionChoices, id: \.factor) { choice in
                        let isOn = portions[index] == choice.factor
                        Button {
                            withAnimation(Theme.springy) { portions[index] = choice.factor }
                        } label: {
                            Text(choice.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isOn ? Color.white : Color.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.s)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(isOn ? .regular.tint(slot.tint).interactive() : .regular.interactive(), in: .capsule)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(Color.primary.opacity(0.04), in: .rect(cornerRadius: Theme.Radius.inner))
    }

    /// Touche sur la quantité : la régler sans chiffre, ou remplacer l'aliment par un équivalent.
    private func adjustMenu(_ food: DescribedFood, base: DescribedFood, index: Int) -> some View {
        Menu {
            Section("Quantité") {
                ForEach(Self.amounts, id: \.factor) { amount in
                    Button {
                        withAnimation(Theme.springy) { scales[index] = amount.factor }
                    } label: {
                        if (scales[index] ?? 1) == amount.factor {
                            Label(amount.label, systemImage: "checkmark")
                        } else {
                            Text(amount.label)
                        }
                    }
                }
            }
            let alternatives = MealImprover.alternatives(for: base)
            if !alternatives.isEmpty {
                Section("Remplacer par") {
                    ForEach(alternatives, id: \.name) { alternative in
                        // L'écart avec l'aliment saisi : un remplaçant peut être plus calorique.
                        let delta = alternative.macros.kcal - base.macros.kcal
                        let effect = abs(delta) < 5 ? "même apport" : "\(delta < 0 ? "−" : "+")\(abs(delta).frenchInteger) kcal"
                        Button("\(alternative.name) · \(effect)") {
                            withAnimation(Theme.springy) {
                                replacements[index] = alternative
                                scales[index] = nil
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(food.isEstimate ? "\(food.quantityLabel) · estimé" : food.quantityLabel)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(slot.tint)
        }
        .accessibilityLabel("Quantité de \(food.name) : \(food.quantityLabel). Modifier ou remplacer")
    }

    /// Appareil photo (s'il existe) et photothèque : la photo préremplit la description.
    private var photoButtons: some View {
        HStack(spacing: Theme.Spacing.s) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    isEditing = false
                    isShowingCamera = true
                } label: {
                    Label("Prendre en photo", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.s)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(slot.tint.opacity(0.3)).interactive(), in: .capsule)
            }
            PhotosPicker(selection: $pickedItem, matching: .images) {
                Label("Photothèque", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.s)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .disabled(isReadingPhoto || isAnalyzing)
    }

    /// La photo devient une phrase, que l'utilisateur peut corriger avant l'estimation.
    private func read(_ image: UIImage) async {
        withAnimation(Theme.springy) {
            photo = image
            isReadingPhoto = true
            photoNotRecognized = false
        }
        let sentence = await MealPhotoReader.sentence(for: image)
        withAnimation(Theme.springy) { isReadingPhoto = false }
        guard let sentence else {
            withAnimation(Theme.springy) { photoNotRecognized = true }
            isEditing = true
            return
        }
        text = sentence
        await analyze()
    }

    private func analyze() async {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        isEditing = false
        isAnalyzing = true
        let result = await OnDeviceMealModel.describer().describe(input)
        // Texte modifié pendant l'estimation : ce résultat ne correspond plus, le suivant le remplacera.
        guard text.trimmingCharacters(in: .whitespacesAndNewlines) == input else {
            isAnalyzing = false
            return
        }
        withAnimation(Theme.springy) {
            parse = result
            portions = [:]
            removed = []
            scales = [:]
            replacements = [:]
            isAnalyzing = false
        }
    }
}

extension MealSlot {
    /// « au petit-déjeuner », « à la collation »…
    var inTheMeal: String {
        switch self {
        case .breakfast: "au petit-déjeuner"
        case .lunch: "au déjeuner"
        case .snack: "à la collation"
        case .dinner: "au dîner"
        }
    }
}

/// Appareil photo système, le temps d'une prise de vue.
private struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    @MainActor
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void

        init(done: @escaping (UIImage?) -> Void) {
            self.done = done
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            done(nil)
        }
    }
}
