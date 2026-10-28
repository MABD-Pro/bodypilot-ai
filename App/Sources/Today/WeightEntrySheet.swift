import BodyPilotCore
import SwiftData
import SwiftUI

/// Pesée en deux touches : la valeur part de la dernière mesure.
struct WeightEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var kg: Double

    init(initialKg: Double) {
        _kg = State(initialValue: (initialKg * 10).rounded() / 10)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("Pesée du jour")
                    .font(.display(24))
                Text("Le matin, à jeun, après être passé aux toilettes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.xl) {
                StepButton(symbol: "minus", label: "Retirer 100 g") { change(by: -0.1) }
                SteppedValue(accessibilityValue: "\(kg.frenchOneDecimal) kg", decrease: { change(by: -0.1) }, increase: { change(by: 0.1) }) {
                    VStack(spacing: 0) {
                        Text(kg.frenchOneDecimal)
                            .font(.display(60))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: kg))
                        Text("kg")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 150)
                }
                StepButton(symbol: "plus", label: "Ajouter 100 g") { change(by: 0.1) }
            }

            Button {
                context.insert(WeightRecord(date: .now, kg: kg))
                try? context.save()
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.progress)
        }
        .padding(Theme.Spacing.xxl)
        .adaptiveDetents(height: 340)
        .sensoryFeedback(.increase, trigger: kg)
    }

    /// Bornée à des valeurs plausibles : un appui maintenu ne descend pas sous 30 kg.
    private func change(by delta: Double) {
        kg = min(300, max(30, ((kg + delta) * 10).rounded() / 10))
    }
}

/// Tour de taille : même geste que la pesée, par pas d'un demi-centimètre.
struct WaistEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var cm: Double
    @State private var isScanning = false

    init(initialCm: Double) {
        // Dernière mesure exacte : enregistrer sans toucher ne crée pas de variation fictive.
        _cm = State(initialValue: (initialCm * 10).rounded() / 10)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.xs) {
                Text("Tour de taille")
                    .font(.display(24))
                Text("Au niveau du nombril, le matin, ventre relâché.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Theme.Spacing.xl) {
                StepButton(symbol: "minus", label: "Retirer 5 mm") { change(by: -0.5) }
                SteppedValue(accessibilityValue: "\(cm.frenchOneDecimal) cm", decrease: { change(by: -0.5) }, increase: { change(by: 0.5) }) {
                    VStack(spacing: 0) {
                        Text(cm.frenchOneDecimal)
                            .font(.display(60))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: cm))
                        Text("cm")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 150)
                }
                StepButton(symbol: "plus", label: "Ajouter 5 mm") { change(by: 0.5) }
            }

            Button {
                context.insert(WaistRecord(date: .now, cm: cm))
                try? context.save()
                dismiss()
            } label: {
                Text("Enregistrer")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Theme.progress)

            if WaistScanView.isSupported {
                Button("Scanner au LiDAR (expérimental)", systemImage: "camera.metering.matrix") {
                    isScanning = true
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.glass)
            }
        }
        .padding(Theme.Spacing.xxl)
        .adaptiveDetents(height: WaistScanView.isSupported ? 400 : 340)
        .sensoryFeedback(.increase, trigger: cm)
        .fullScreenCover(isPresented: $isScanning) {
            WaistScanView {
                isScanning = false
                dismiss()
            }
        }
    }

    /// Bornée à des valeurs plausibles : un appui maintenu ne descend pas sous 40 cm.
    private func change(by delta: Double) {
        cm = min(200, max(40, ((cm + delta) * 10).rounded() / 10))
    }
}
