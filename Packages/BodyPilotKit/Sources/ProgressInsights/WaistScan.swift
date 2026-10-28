import Foundation

/// Tour de taille estimé au LiDAR (expérimental) : largeur de la taille vue de face, épaisseur
/// vue de profil, puis périmètre d'une ellipse. Une taille n'est pas une ellipse parfaite et les
/// vêtements faussent la mesure : le scan est comparé au mètre ruban avant d'être adopté.
public enum WaistScan {
    /// Pixels du corps : profondeur à moins de 30 cm de celle du nombril (le fond est plus loin).
    public static let bodyDepthToleranceMeters: Float = 0.3
    /// Images retenues par vue (face, profil) : la médiane écarte les images ratées.
    public static let framesPerView = 15
    /// Le scan remplace le ruban seulement si l'écart reste sous ce seuil.
    public static let adoptionThresholdCm = 1.0
    /// Mesures plausibles, pour écarter un scan raté.
    public static let plausibleRangeCm = 50.0...200.0

    /// Périmètre d'une ellipse de grand axe `width` et de petit axe `depth` (approximation de Ramanujan).
    public static func circumference(width: Double, depth: Double) -> Double {
        let a = width / 2
        let b = depth / 2
        return .pi * (3 * (a + b) - ((3 * a + b) * (a + 3 * b)).squareRoot())
    }

    /// Longueur réelle d'une suite de pixels : pixels × distance / focale (en pixels).
    public static func metricLength(pixels: Double, depthMeters: Double, focalPixels: Double) -> Double {
        guard focalPixels > 0 else { return 0 }
        return pixels * depthMeters / focalPixels
    }

    /// Bornes de la suite continue de pixels du corps qui contient `index` ; `nil` si `index` est hors du corps.
    public static func run(in mask: [Bool], through index: Int) -> ClosedRange<Int>? {
        guard mask.indices.contains(index), mask[index] else { return nil }
        var low = index
        var high = index
        while low > 0, mask[low - 1] { low -= 1 }
        while high < mask.count - 1, mask[high + 1] { high += 1 }
        return low...high
    }

    public static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// Tour de taille (cm) à partir des largeurs mesurées de face et de profil (en mètres, une par image) ;
    /// `nil` s'il manque des images ou si le résultat n'est pas plausible.
    public static func waistCm(frontWidths: [Double], sideDepths: [Double]) -> Double? {
        guard let width = median(frontWidths), let depth = median(sideDepths), width > 0, depth > 0 else { return nil }
        let cm = circumference(width: max(width, depth), depth: min(width, depth)) * 100
        return plausibleRangeCm.contains(cm) ? (cm * 10).rounded() / 10 : nil
    }

    /// Écart moyen absolu entre chaque scan et la mesure au ruban du même jour ; `nil` sans paire.
    public static func meanGapCm(scans: [(date: Date, cm: Double)], tape: [(date: Date, cm: Double)], calendar: Calendar = .current) -> Double? {
        let gaps = scans.compactMap { scan in
            tape.first { calendar.isDate($0.date, inSameDayAs: scan.date) }.map { abs($0.cm - scan.cm) }
        }
        return gaps.isEmpty ? nil : gaps.reduce(0, +) / Double(gaps.count)
    }
}
