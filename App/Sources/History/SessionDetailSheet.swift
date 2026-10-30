import BodyPilotCore
import Charts
import MapKit
import ProgressInsights
import SwiftUI
import Training

/// Une séance de l'historique, touchée : le détail adapté à son type. Parcours, allure et
/// pouls pour une activité de Santé ; séries notées pour une séance cochée dans l'app.
struct SessionDetailSheet: View {
    struct Item: Identifiable {
        var day: Date
        var entry: SessionEntry
        var id: String { entry.healthID ?? "\(day.timeIntervalSince1970)-\(entry.title)" }
    }

    let item: Item
    /// Séries notées ce jour-là.
    var lifts: [LiftEntry] = []
    /// Fréquence maximale estimée (âge du profil) : base des zones de pouls.
    var maxHeartRate: Double?

    @Environment(\.dismiss) private var dismiss
    @State private var detail: WorkoutDetail?
    /// Vrai jusqu'à la première lecture : pas de message d'absence avant d'avoir lu Santé.
    @State private var isLoading = true

    private var entry: SessionEntry { item.entry }
    private var tint: Color { entry.fromHealth ? Theme.protein : Theme.training }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    if entry.fromHealth {
                        healthContent
                    } else {
                        liftsCard
                    }
                }
                .padding(Theme.Spacing.l)
            }
            .background { AppBackground() }
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await load() }
    }

    private func load() async {
        defer { isLoading = false }
        guard entry.fromHealth, let id = entry.healthID else { return }
        if id.hasPrefix("demo-") {
            detail = DemoData.workoutDetail(for: item)
            return
        }
        await HealthWorkoutDetail.requestAccess()
        detail = try? await HealthWorkoutDetail.load(id: id)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconBadge(symbol: entry.kind?.symbol ?? "checkmark.circle.fill", tint: tint, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.title3.weight(.bold))
                Text(when)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let source = detail?.source ?? (entry.fromHealth ? nil : "Cochée dans BodyPilot") {
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let indoor = detail?.indoor {
                Tag(text: indoor ? "Intérieur" : "Extérieur", symbol: indoor ? "house.fill" : "sun.max.fill", tint: tint)
            }
        }
    }

    /// « jeudi 29 octobre · 18:00 – 19:15 ».
    private var when: String {
        let day = item.day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Theme.locale))
        let time = Date.FormatStyle(date: .omitted, time: .shortened).locale(Theme.locale)
        if let detail {
            return "\(day) · \(detail.start.formatted(time)) – \(detail.end.formatted(time))"
        }
        if let start = entry.start { return "\(day) · \(start.formatted(time))" }
        return day
    }

    // MARK: - Activité Santé

    @ViewBuilder
    private var healthContent: some View {
        if let detail, detail.route.count >= 2 {
            routeMap(detail.route)
        }
        stats
        if let detail, !detail.heartRates.isEmpty {
            heartRateCard(detail)
        }
        if let detail, !WorkoutDetails.readsAsSpeed(entry.kind), entry.kind != .swimming {
            let splits = WorkoutDetails.splits(detail.route)
            if !splits.isEmpty { splitsCard(splits) }
        }
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if let detail, detail.route.isEmpty, detail.heartRates.isEmpty {
            note("Santé n'a ni parcours ni pouls pour cette activité : elle a sans doute été enregistrée sans montre ou en intérieur.")
        } else if detail == nil {
            note("Le détail n'est pas lisible : l'activité a été supprimée de Santé, ou la lecture des entraînements est refusée (Réglages › Santé › Accès aux données).")
        }
    }

    private func routeMap(_ route: [RoutePoint]) -> some View {
        let coordinates = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return Map(initialPosition: .automatic) {
            MapPolyline(coordinates: coordinates)
                .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            if let first = coordinates.first {
                Marker("Départ", systemImage: "flag.fill", coordinate: first)
                    .tint(Theme.progress)
            }
            if let last = coordinates.last {
                Marker("Arrivée", systemImage: "flag.checkered", coordinate: last)
                    .tint(tint)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 240)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityLabel("Carte du parcours")
    }

    private struct Stat: Identifiable {
        var label: String
        var value: String
        var symbol: String
        var id: String { label }
    }

    private var statItems: [Stat] {
        let minutes = detail?.minutes ?? entry.minutes
        let km = detail?.distanceKm
        var items: [Stat] = []
        if let minutes { items.append(Stat(label: "Durée", value: WorkoutDetails.durationLabel(minutes: minutes), symbol: "stopwatch")) }
        if let km, km > 0 { items.append(Stat(label: "Distance", value: "\(km.frenchOneDecimal)\u{00A0}km", symbol: "point.topleft.down.to.point.bottomright.curvepath")) }
        if let minutes, let km, km > 0 {
            if WorkoutDetails.readsAsSpeed(entry.kind) {
                if let speed = WorkoutDetails.speedLabel(minutes: minutes, km: km) { items.append(Stat(label: "Vitesse moyenne", value: speed, symbol: "speedometer")) }
            } else if entry.kind != .swimming, let pace = WorkoutDetails.paceLabel(minutes: minutes, km: km) {
                items.append(Stat(label: "Allure moyenne", value: pace, symbol: "gauge.with.needle"))
            }
        }
        if let kcal = entry.kcal { items.append(Stat(label: "Calories actives", value: "\(kcal.frenchInteger)\u{00A0}kcal", symbol: "flame.fill")) }
        if let average = detail?.averageHeartRate { items.append(Stat(label: "Pouls moyen", value: "\(average.frenchInteger)\u{00A0}bpm", symbol: "heart.fill")) }
        if let max = detail?.maxHeartRate { items.append(Stat(label: "Pouls max", value: "\(max.frenchInteger)\u{00A0}bpm", symbol: "bolt.heart.fill")) }
        if let climb = detail?.elevationGainM, climb >= 1 { items.append(Stat(label: "Dénivelé +", value: "\(climb.frenchInteger)\u{00A0}m", symbol: "mountain.2.fill")) }
        if let temperature = detail?.temperatureC { items.append(Stat(label: "Température", value: "\(temperature.frenchInteger)\u{00A0}°C", symbol: "thermometer.medium")) }
        return items
    }

    private var stats: some View {
        CoachCard(eyebrow: "Résumé", symbol: "list.bullet.rectangle", tint: tint) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], spacing: Theme.Spacing.l) {
                ForEach(statItems) { stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(stat.label, systemImage: stat.symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stat.value)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func heartRateCard(_ detail: WorkoutDetail) -> some View {
        CoachCard(eyebrow: "Pouls", symbol: "heart.fill", tint: Theme.protein) {
            Chart(detail.heartRates, id: \.time) { point in
                LineMark(x: .value("Heure", point.time), y: .value("Pouls", point.bpm))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.protein)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 140)
            if let maxHeartRate {
                let minutes = WorkoutDetails.zoneMinutes(detail.heartRates, maxHeartRate: maxHeartRate, end: detail.end)
                let total = max(minutes.values.reduce(0, +), 1)
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(HeartRateZone.allCases.reversed()) { zone in
                        let value = minutes[zone] ?? 0
                        HStack(spacing: Theme.Spacing.s) {
                            Text("Z\(zone.rawValue) \(zone.title)")
                                .font(.caption.weight(.semibold))
                                .frame(width: 110, alignment: .leading)
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Theme.protein.opacity(0.25 + 0.15 * Double(zone.rawValue)))
                                    .frame(width: max(4, proxy.size.width * value / total))
                            }
                            .frame(height: 10)
                            Text("\(Int(value.rounded())) min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 52, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Text("Zones en part de ta fréquence maximale estimée (\(Int(maxHeartRate.rounded())) bpm, Tanaka 2001).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func splitsCard(_ splits: [KilometerSplit]) -> some View {
        let fastest = splits.map(\.secondsPerKm).min() ?? 1
        let slowest = splits.map(\.secondsPerKm).max() ?? 1
        return CoachCard(eyebrow: "Kilomètre par kilomètre", symbol: "flag.2.crossed.fill", tint: tint) {
            ForEach(splits) { split in
                HStack(spacing: Theme.Spacing.s) {
                    Text(split.km < 1 ? "\(split.km.frenchOneDecimal)" : "\(split.number)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 32, alignment: .leading)
                    GeometryReader { proxy in
                        // Le plus rapide en barre pleine, le plus lent au tiers.
                        let spread = max(slowest - fastest, 1)
                        let share = 1 - 0.66 * (split.secondsPerKm - fastest) / spread
                        Capsule()
                            .fill(split.secondsPerKm == fastest ? tint : tint.opacity(0.45))
                            .frame(width: proxy.size.width * share)
                    }
                    .frame(height: 10)
                    Text(WorkoutDetails.paceLabel(secondsPerKm: split.secondsPerKm) ?? "–")
                        .font(.subheadline)
                        .monospacedDigit()
                    if let climb = split.climbM, climb >= 1 {
                        Text("+\(Int(climb.rounded()))\u{00A0}m")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Séance cochée dans l'app

    @ViewBuilder
    private var liftsCard: some View {
        CoachCard(eyebrow: "Séries notées", symbol: "dumbbell.fill", tint: tint) {
            if lifts.isEmpty {
                Text("Aucune série notée ce jour-là. Touche un exercice pendant ta séance pour noter ta meilleure série : elle apparaîtra ici.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(lifts.enumerated()), id: \.offset) { _, lift in
                    HStack(alignment: .firstTextBaseline) {
                        Text(lift.exercise)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: Theme.Spacing.s)
                        Text(StrengthProgress.label(lift) + (lift.isTest ? " · test" : "") + (lift.effort.map { " · \($0.title.lowercased())" } ?? ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
        note("Les activités enregistrées par ta montre ce jour-là (parcours, pouls) ont leur propre ligne dans l'historique.")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
