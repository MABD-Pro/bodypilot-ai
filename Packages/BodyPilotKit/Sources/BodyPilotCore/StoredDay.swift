import Foundation

extension Calendar {
    /// Jour enregistré : midi de ce jour-là plutôt que minuit. Comparé dans un autre fuseau
    /// (voyage), midi reste le même jour jusqu'à 12 h de décalage, alors que minuit à Paris
    /// tombe la veille à New York.
    public func storedDay(for date: Date) -> Date {
        let start = startOfDay(for: date)
        return self.date(byAdding: .hour, value: 12, to: start) ?? start
    }

    /// Jour enregistré à minuit par une version précédente, à ramener à midi.
    public func isStoredAtMidnight(_ date: Date) -> Bool {
        let time = dateComponents([.hour, .minute, .second], from: date)
        return time.hour == 0 && time.minute == 0 && time.second == 0
    }
}
