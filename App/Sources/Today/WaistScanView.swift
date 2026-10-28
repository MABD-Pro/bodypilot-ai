import ARKit
import BodyPilotCore
import ProgressInsights
import SceneKit
import SwiftData
import SwiftUI

/// Tour de taille au LiDAR (expérimental) : une personne tient l'iPhone, aligne la ligne sur le
/// nombril, mesure de face puis de profil. Le scan est enregistré à part du ruban et comparé à lui.
struct WaistScanView: View {
    static var isSupported: Bool { ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) }

    var onSaved: () -> Void

    private enum Step { case front, side, result }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WaistRecord> { !$0.isScan }, sort: \WaistRecord.date) private var tape: [WaistRecord]
    @State private var scanner = DepthScanner()
    @State private var step: Step = .front
    @State private var frontWidths: [Double] = []
    @State private var waistCm: Double?

    var body: some View {
        ZStack {
            DepthCameraView(scanner: scanner)
                .ignoresSafeArea()
            if step != .result { guide }
            VStack {
                HStack {
                    Spacer()
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                Spacer()
                panel
            }
            .padding(Theme.Spacing.l)
        }
        .onChange(of: scanner.rounds) { finish(scanner.widths) }
    }

    /// Ligne horizontale au centre : c'est là que la largeur du corps est mesurée.
    private var guide: some View {
        Rectangle()
            .fill(.white)
            .frame(height: 2)
            .overlay { Rectangle().stroke(Theme.progress, style: StrokeStyle(lineWidth: 1, dash: [6, 4])) }
            .shadow(radius: 2)
            .allowsHitTesting(false)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Expérimental")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.progress)
            switch step {
            case .front:
                instructions(
                    title: "1. De face",
                    detail: "En sous-vêtements ou t-shirt près du corps, bras croisés sur la poitrine, à 1 à 1,5 m. La personne qui tient l'iPhone place la ligne sur le nombril, tout le ventre dans l'image."
                )
                measureButton("Mesurer de face")
            case .side:
                instructions(
                    title: "2. De profil",
                    detail: "Tourne-toi d'un quart de tour, bras toujours croisés. Ligne sur le nombril, ventre relâché."
                )
                measureButton("Mesurer de profil")
            case .result:
                result
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func instructions(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func measureButton(_ title: String) -> some View {
        Button {
            scanner.start()
        } label: {
            Group {
                if scanner.isCollecting {
                    ProgressView(value: Double(scanner.widths.count), total: Double(WaistScan.framesPerView))
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.progress)
        .disabled(scanner.isCollecting)
    }

    @ViewBuilder
    private var result: some View {
        if let waistCm {
            let todayTape = tape.last { Calendar.current.isDateInToday($0.date) }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(waistCm.frenchOneDecimal) cm")
                    .font(.display(44))
                    .monospacedDigit()
                Text(todayTape.map { "Ruban aujourd'hui : \($0.cm.frenchOneDecimal) cm, écart \(abs(waistCm - $0.cm).frenchOneDecimal) cm." }
                    ?? "Mesure aussi au ruban aujourd'hui : l'historique compare les deux.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Le scan reste à part : ta tendance utilise le ruban tant que l'écart n'est pas sous \(WaistScan.adoptionThresholdCm.frenchCompact) cm.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Spacing.m) {
                Button("Recommencer") { restart() }
                    .buttonStyle(.glass)
                Button {
                    context.insert(WaistRecord(date: .now, cm: waistCm, isScan: true))
                    try? context.save()
                    onSaved()
                } label: {
                    Text("Enregistrer le scan")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
            }
        } else {
            instructions(
                title: "Mesure impossible",
                detail: "Le corps n'a pas été trouvé sur la ligne ou dépasse de l'image. Recule un peu, avec un mur dégagé derrière toi."
            )
            Button("Recommencer") { restart() }
                .buttonStyle(.glassProminent)
                .tint(Theme.progress)
        }
    }

    private func finish(_ widths: [Double]) {
        // Moins de la moitié des images exploitables : le corps n'était pas sur la ligne.
        guard widths.count * 2 >= WaistScan.framesPerView else {
            waistCm = nil
            step = .result
            return
        }
        switch step {
        case .front:
            frontWidths = widths
            step = .side
        case .side:
            waistCm = WaistScan.waistCm(frontWidths: frontWidths, sideDepths: widths)
            step = .result
        case .result:
            break
        }
    }

    private func restart() {
        frontWidths = []
        waistCm = nil
        step = .front
    }
}

/// Lit la profondeur LiDAR et mesure, image par image, la largeur du corps sur la ligne centrale.
@MainActor @Observable
final class DepthScanner: NSObject, ARSessionDelegate {
    let session = ARSession()
    private(set) var widths: [Double] = []
    private(set) var isCollecting = false
    /// Mesures terminées (assez d'images ou délai dépassé) : la vue lit alors `widths`.
    private(set) var rounds = 0
    /// Une image sur quatre : les mesures s'étalent sur une seconde environ.
    @ObservationIgnored private var frameIndex = 0
    /// Au-delà (environ 4 s), on s'arrête avec les images obtenues.
    private static let maxFrames = 240

    override init() {
        super.init()
        session.delegate = self
    }

    func run() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        session.run(configuration)
    }

    func start() {
        widths = []
        frameIndex = 0
        isCollecting = true
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let width = Self.bodyWidth(in: frame)
        MainActor.assumeIsolated {
            guard isCollecting else { return }
            frameIndex += 1
            if frameIndex.isMultiple(of: 4), let width { widths.append(width) }
            if widths.count >= WaistScan.framesPerView || frameIndex >= Self.maxFrames {
                isCollecting = false
                rounds += 1
            }
        }
    }

    /// Largeur (m) du corps sur la ligne horizontale qui passe par le centre de l'écran ;
    /// `nil` si le centre n'est pas sur le corps ou si le corps dépasse de l'image.
    nonisolated static func bodyWidth(in frame: ARFrame) -> Double? {
        guard let depthMap = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap else { return nil }
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        func depth(_ x: Int, _ y: Int) -> Float {
            base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float32.self)[x]
        }

        // Le capteur est en paysage : on ramène le centre et l'horizontale de l'écran (portrait)
        // dans les coordonnées de l'image.
        let toImage = frame.displayTransform(for: .portrait, viewportSize: CGSize(width: 3, height: 4)).inverted()
        let center = CGPoint(x: 0.5, y: 0.5).applying(toImage)
        let aside = CGPoint(x: 0.6, y: 0.5).applying(toImage)
        let alongX = abs(aside.x - center.x) > abs(aside.y - center.y)
        let cx = Int(center.x * CGFloat(width))
        let cy = Int(center.y * CGFloat(height))
        guard (0..<width).contains(cx), (0..<height).contains(cy) else { return nil }

        let centerDepth = depth(cx, cy)
        guard centerDepth.isFinite, (0.4...3).contains(centerDepth) else { return nil }
        let count = alongX ? width : height
        let mask = (0..<count).map { i in
            let d = alongX ? depth(i, cy) : depth(cx, i)
            return d.isFinite && abs(d - centerDepth) < WaistScan.bodyDepthToleranceMeters
        }
        guard let span = WaistScan.run(in: mask, through: alongX ? cx : cy),
              span.lowerBound > 0, span.upperBound < count - 1 else { return nil }

        let intrinsics = frame.camera.intrinsics
        let scale = Double(width) / Double(frame.camera.imageResolution.width)
        let focal = Double(alongX ? intrinsics[0][0] : intrinsics[1][1]) * scale
        return WaistScan.metricLength(pixels: Double(span.count), depthMeters: Double(centerDepth), focalPixels: focal)
    }
}

/// Aperçu caméra de la session AR.
private struct DepthCameraView: UIViewRepresentable {
    let scanner: DepthScanner

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = scanner.session
        scanner.run()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }
}
