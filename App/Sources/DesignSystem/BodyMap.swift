import SwiftUI
import Training

/// Silhouette schématique, de face ou de dos, dont chaque zone musculaire peut prendre une couleur.
/// Dessin maison (formes SwiftUI, aucune ressource sous licence) : il suit le thème et le mode sombre.
struct BodyMap: View {
    let side: MuscleRegion.Side
    /// Couleur d'une zone ; `nil` la laisse dans la teinte de la silhouette.
    let color: (MuscleRegion) -> Color?
    var base: Color = Color.primary.opacity(0.16)

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / BodyMapGeometry.width, size.height / BodyMapGeometry.height)
            let dx = (size.width - BodyMapGeometry.width * scale) / 2
            let dy = (size.height - BodyMapGeometry.height * scale) / 2
            let transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
            for piece in BodyMapGeometry.silhouette {
                context.fill(piece.applying(transform), with: .color(base))
            }
            for region in MuscleRegion.allCases where region.sides.contains(side) {
                guard let tint = color(region) else { continue }
                for shape in BodyMapGeometry.shapes(for: region, side: side) {
                    context.fill(shape.applying(transform), with: .color(tint))
                }
            }
        }
        .aspectRatio(BodyMapGeometry.width / BodyMapGeometry.height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Ce que la feuille agrandie affiche autour de la silhouette.
struct BodyMapZoom {
    struct LegendLine: Identifiable {
        let color: Color
        let title: String
        let items: [String]
        var id: String { title }
    }

    var title: String
    var legend: [LegendLine]
}

/// Face et dos côte à côte, légendés. Avec `zoom`, une touche ouvre la silhouette en grand.
struct BodyMapPair: View {
    var leading: MuscleRegion.Side = .front
    let color: (MuscleRegion) -> Color?
    var height: CGFloat = 150
    var captions = true
    /// Étiquettes Face / Dos discrètes dans les cartes, lisibles en grand.
    var largeCaptions = false
    var zoom: BodyMapZoom?
    /// `-demoBodyMapZoom YES` : la feuille agrandie s'ouvre d'elle-même (captures).
    var opensZoom = false

    @State private var isZoomed = false

    private var sides: [MuscleRegion.Side] { leading == .front ? [.front, .back] : [.back, .front] }

    var body: some View {
        if let zoom {
            Button {
                isZoomed = true
            } label: {
                pair
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agrandir la silhouette")
            .sheet(isPresented: $isZoomed) {
                BodyMapZoomSheet(zoom: zoom, color: color)
            }
            .onAppear { if opensZoom { isZoomed = true } }
        } else {
            pair
        }
    }

    private var pair: some View {
        HStack(spacing: Theme.Spacing.s) {
            ForEach(Array(sides.enumerated()), id: \.offset) { _, side in
                VStack(spacing: 2) {
                    BodyMap(side: side, color: color)
                        .frame(height: height)
                    if captions {
                        Text(side == .front ? "Face" : "Dos")
                            .font(largeCaptions ? .footnote.weight(.semibold) : .caption2)
                            .foregroundStyle(largeCaptions ? .secondary : .tertiary)
                    }
                }
            }
        }
        .contentShape(.rect)
        .accessibilityHidden(true)
    }
}

/// Silhouette en grand : face, dos ou les deux, avec la légende des zones colorées.
struct BodyMapZoomSheet: View {
    let zoom: BodyMapZoom
    let color: (MuscleRegion) -> Color?

    private enum View_: Hashable { case front, back, both }
    @State private var view: View_ = .both
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                HStack(alignment: .firstTextBaseline) {
                    Text(zoom.title)
                        .font(.display(24))
                    Spacer()
                    Button("Fermer") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .tint(Theme.training)
                }
                Picker("Vue", selection: $view.animation(.snappy)) {
                    Text("Les deux").tag(View_.both)
                    Text("Face").tag(View_.front)
                    Text("Dos").tag(View_.back)
                }
                .pickerStyle(.segmented)
                switch view {
                case .both:
                    BodyMapPair(color: color, height: 420, largeCaptions: true)
                case .front:
                    BodyMap(side: .front, color: color)
                        .frame(height: 480)
                case .back:
                    BodyMap(side: .back, color: color)
                        .frame(height: 480)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(zoom.legend) { line in
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            Circle()
                                .fill(line.color)
                                .frame(width: 10, height: 10)
                                .offset(y: -1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(line.items.isEmpty ? "—" : line.items.joined(separator: ", "))
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Theme.Spacing.xxl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.large])
    }
}

/// Silhouette d'un exercice : zones principales en couleur pleine, secondaires en pâle, avec la liste.
struct MuscleHighlightRow: View {
    let regions: ExerciseRegions
    var tint: Color = Theme.training
    /// Titre de la silhouette agrandie (nom de l'exercice).
    var title = "Muscles travaillés"
    /// Ouvre la silhouette en grand dès l'affichage (captures).
    var opensZoom = false

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            BodyMapPair(leading: regions.leadingSide, color: color, height: 140, zoom: zoom, opensZoom: opensZoom)
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                legend(title: "Travaille surtout", regions: regions.primary, opacity: 1)
                if !regions.secondary.isEmpty {
                    legend(title: "En appoint", regions: regions.secondary, opacity: 0.55)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func color(_ region: MuscleRegion) -> Color? {
        if regions.primary.contains(region) { return tint }
        if regions.secondary.contains(region) { return tint.opacity(0.55) }
        return nil
    }

    private var zoom: BodyMapZoom {
        var legend = [BodyMapZoom.LegendLine(color: tint, title: "Travaille surtout", items: regions.primary.map(\.label))]
        if !regions.secondary.isEmpty {
            legend.append(BodyMapZoom.LegendLine(color: tint.opacity(0.55), title: "En appoint", items: regions.secondary.map(\.label)))
        }
        return BodyMapZoom(title: title, legend: legend)
    }

    private func legend(title: String, regions: [MuscleRegion], opacity: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Circle()
                .fill(tint.opacity(opacity))
                .frame(width: 9, height: 9)
                .offset(y: -1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(regions.map(\.label).joined(separator: ", "))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var accessibilityText: String {
        var text = "Travaille surtout : \(regions.primary.map(\.label).joined(separator: ", "))."
        if !regions.secondary.isEmpty { text += " En appoint : \(regions.secondary.map(\.label).joined(separator: ", "))." }
        return text
    }
}

/// Formes de la silhouette dans un repère de 100 × 220 : le dessin est symétrique, chaque zone
/// est tracée à gauche puis reflétée.
enum BodyMapGeometry {
    static let width: CGFloat = 100
    static let height: CGFloat = 220

    static var silhouette: [Path] {
        var pieces: [Path] = [
            ellipse(50, 15, 11, 13),
            Path(roundedRect: CGRect(x: 44, y: 25, width: 12, height: 12), cornerRadius: 3),
            torso,
            Path(roundedRect: CGRect(x: 33, y: 90, width: 34, height: 23), cornerRadius: 10),
        ]
        pieces += mirrored([
            capsule(CGPoint(x: 30, y: 37), CGPoint(x: 23, y: 72), width: 11),
            capsule(CGPoint(x: 23, y: 72), CGPoint(x: 19, y: 104), width: 9),
            ellipse(18, 109, 4.5, 6),
            capsule(CGPoint(x: 41, y: 106), CGPoint(x: 39, y: 152), width: 15),
            capsule(CGPoint(x: 39, y: 152), CGPoint(x: 38, y: 196), width: 10),
            ellipse(37, 202, 6, 4),
        ])
        return pieces
    }

    private static var torso: Path {
        var path = Path()
        path.move(to: CGPoint(x: 29, y: 34))
        path.addLine(to: CGPoint(x: 71, y: 34))
        path.addQuadCurve(to: CGPoint(x: 66, y: 98), control: CGPoint(x: 64, y: 70))
        path.addLine(to: CGPoint(x: 34, y: 98))
        path.addQuadCurve(to: CGPoint(x: 29, y: 34), control: CGPoint(x: 36, y: 70))
        path.closeSubpath()
        return path
    }

    static func shapes(for region: MuscleRegion, side: MuscleRegion.Side) -> [Path] {
        switch region {
        case .chest: mirrored([ellipse(41, 47, 9.5, 7.5)])
        case .frontDeltoids, .rearDeltoids: mirrored([ellipse(30, 40, 6.5, 6)])
        case .biceps, .triceps: mirrored([capsule(CGPoint(x: 28, y: 48), CGPoint(x: 24, y: 67), width: 7)])
        case .forearms: mirrored([capsule(CGPoint(x: 23, y: 76), CGPoint(x: 20, y: 99), width: 6)])
        case .abs:
            mirrored([58, 69, 80].map { y in Path(roundedRect: CGRect(x: 43.5, y: y, width: 6, height: 9.5), cornerRadius: 2.5) })
        case .obliques: mirrored([capsule(CGPoint(x: 38.5, y: 60), CGPoint(x: 38, y: 90), width: 5.5)])
        case .trapezius: [trapezius]
        case .lats: mirrored([capsule(CGPoint(x: 36, y: 50), CGPoint(x: 42, y: 80), width: 10)])
        case .lowerBack: [Path(roundedRect: CGRect(x: 43, y: 78, width: 14, height: 17), cornerRadius: 5)]
        case .glutes: mirrored([ellipse(43, 105, 8.5, 8)])
        case .quadriceps: mirrored([capsule(CGPoint(x: 39.5, y: 114), CGPoint(x: 38, y: 148), width: 10.5)])
        case .adductors: mirrored([capsule(CGPoint(x: 46, y: 110), CGPoint(x: 44.5, y: 134), width: 4)])
        case .hamstrings: mirrored([capsule(CGPoint(x: 41, y: 116), CGPoint(x: 39.5, y: 150), width: 11)])
        case .calves: mirrored([capsule(CGPoint(x: 39.5, y: 158), CGPoint(x: 38.5, y: 186), width: 8.5)])
        }
    }

    private static var trapezius: Path {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 31))
        path.addLine(to: CGPoint(x: 36, y: 40))
        path.addLine(to: CGPoint(x: 42, y: 62))
        path.addLine(to: CGPoint(x: 50, y: 70))
        path.addLine(to: CGPoint(x: 58, y: 62))
        path.addLine(to: CGPoint(x: 64, y: 40))
        path.closeSubpath()
        return path
    }

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    /// Segment arrondi de `a` à `b`, d'épaisseur `width`.
    static func capsule(_ a: CGPoint, _ b: CGPoint, width: CGFloat) -> Path {
        let length = hypot(b.x - a.x, b.y - a.y)
        let angle = atan2(b.y - a.y, b.x - a.x)
        let local = Path(roundedRect: CGRect(x: 0, y: -width / 2, width: length, height: width), cornerRadius: width / 2)
        return local.applying(CGAffineTransform(translationX: a.x, y: a.y).rotated(by: angle))
    }

    /// Les formes données, plus leur reflet par rapport à l'axe du corps.
    static func mirrored(_ paths: [Path]) -> [Path] {
        let flip = CGAffineTransform(translationX: width, y: 0).scaledBy(x: -1, y: 1)
        return paths + paths.map { $0.applying(flip) }
    }
}
