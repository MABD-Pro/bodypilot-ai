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
                step(-0.1, symbol: "minus")
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
                step(0.1, symbol: "plus")
            }

            Button {
                context.insert(WeightRecord(date: .now, kg: kg))
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
        .presentationDetents([.height(340)])
        .sensoryFeedback(.increase, trigger: kg)
    }

    private func step(_ delta: Double, symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { kg = ((kg + delta) * 10).rounded() / 10 }
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonRepeatBehavior(.enabled)
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
                step(-0.5, symbol: "minus")
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
                step(0.5, symbol: "plus")
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
        .presentationDetents([.height(WaistScanView.isSupported ? 400 : 340)])
        .sensoryFeedback(.increase, trigger: cm)
        .fullScreenCover(isPresented: $isScanning) {
            WaistScanView {
                isScanning = false
                dismiss()
            }
        }
    }

    private func step(_ delta: Double, symbol: String) -> some View {
        Button {
            withAnimation(.snappy) { cm = ((cm + delta) * 10).rounded() / 10 }
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .buttonRepeatBehavior(.enabled)
    }
}
