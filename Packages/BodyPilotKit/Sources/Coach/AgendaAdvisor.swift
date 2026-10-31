import BodyPilotCore
import Foundation

/// Un événement du calendrier de l'iPhone, lu sur l'appareil (EventKit) et jamais envoyé ailleurs.
public struct AgendaEvent: Sendable, Equatable {
    public var title: String
    public var start: Date
    public var end: Date
    public var location: String?
    public var isAllDay: Bool

    public init(title: String, start: Date, end: Date, location: String? = nil, isAllDay: Bool = false) {
        self.title = title
        self.start = start
        self.end = end
        self.location = location
        self.isAllDay = isAllDay
    }
}

/// Ce que l'agenda du jour suggère. Le coach propose, l'utilisateur applique d'une touche :
/// rien ne change tout seul.
public struct AgendaAdvice: Sendable, Equatable {
    /// Premier créneau libre assez long pour la séance prévue.
    public var freeSlot: DateInterval?
    /// Journée pleine : temps de la plus longue pause, en minutes (multiple de 5, au moins 15).
    public var shortOnTimeMinutes: Int?
    /// Repas au restaurant vu dans l'agenda, et l'événement qui le montre.
    public var eatingOut: (slot: MealSlot, event: String)?
    /// Déplacement vu dans l'agenda (train, avion, hôtel…).
    public var travelEvent: String?

    public init(freeSlot: DateInterval? = nil, shortOnTimeMinutes: Int? = nil, eatingOut: (slot: MealSlot, event: String)? = nil, travelEvent: String? = nil) {
        self.freeSlot = freeSlot
        self.shortOnTimeMinutes = shortOnTimeMinutes
        self.eatingOut = eatingOut
        self.travelEvent = travelEvent
    }

    /// Ajustements à proposer, dans l'ordre d'affichage.
    public var suggestions: [QuickAdjustment] {
        var result: [QuickAdjustment] = []
        if travelEvent != nil { result.append(.traveling) }
        if shortOnTimeMinutes != nil { result.append(.shortOnTime) }
        if eatingOut != nil { result.append(.eatingOut) }
        return result
    }

    public var isEmpty: Bool { freeSlot == nil && suggestions.isEmpty }

    public static func == (lhs: AgendaAdvice, rhs: AgendaAdvice) -> Bool {
        lhs.freeSlot == rhs.freeSlot && lhs.shortOnTimeMinutes == rhs.shortOnTimeMinutes
            && lhs.eatingOut?.slot == rhs.eatingOut?.slot && lhs.eatingOut?.event == rhs.eatingOut?.event
            && lhs.travelEvent == rhs.travelEvent
    }
}

/// Lit les événements du jour pour anticiper ce que l'utilisateur aurait dû déclarer : pas de
/// temps pour la séance, un restaurant ce soir, un déplacement. Déterministe et local
/// (premier palier de l'AI Cost Router) : des mots-clés, aucun modèle.
public enum AgendaAdvisor {
    /// Fenêtre où une séance est envisageable (choix BodyPilot).
    public static let dayStartHour = 6
    public static let dayEndHour = 22
    /// Une pause plus courte ne permet aucune séance.
    public static let minimumMinutes = 15
    /// Événements qui ne prennent pas de temps (rappels, anniversaires…) : plus courts que ça, ignorés.
    static let minimumEventMinutes = 5

    /// Mots entiers (« train » ne reconnaît pas « entraînement »), sans accents ni majuscules.
    static let restaurantWords = ["restaurant", "restaurants", "resto", "brasserie", "bistrot", "pizzeria", "sushi", "brunch", "apero", "diner chez", "dejeuner chez", "diner avec", "dejeuner avec", "diner d'affaires", "dejeuner d'affaires", "afterwork"]
    static let travelWords = ["vol", "avion", "aeroport", "train", "tgv", "ouigo", "eurostar", "gare", "hotel", "deplacement", "voyage", "seminaire", "flight", "airport"]

    public static func advice(events: [AgendaEvent], now: Date, sessionMinutes: Int, calendar: Calendar) -> AgendaAdvice {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let windowStart = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: today),
              let windowEnd = calendar.date(bySettingHour: dayEndHour, minute: 0, second: 0, of: today) else { return AgendaAdvice() }
        let todays = events.filter { $0.end > today && $0.start < tomorrow }

        var advice = AgendaAdvice()
        advice.travelEvent = todays.first { matches($0, travelWords) }?.title

        if let restaurant = todays.first(where: { !$0.isAllDay && $0.end > now && matches($0, restaurantWords) }),
           let slot = mealSlot(at: restaurant.start, calendar: calendar) {
            advice.eatingOut = (slot, restaurant.title)
        }

        // Créneaux libres entre maintenant (ou 6 h) et 22 h, hors événements sur toute la journée.
        let busy: [DateInterval] = todays
            .filter { !$0.isAllDay && $0.end.timeIntervalSince($0.start) >= Double(minimumEventMinutes * 60) }
            .compactMap { event in
                let start = max(event.start, windowStart)
                let end = min(event.end, windowEnd)
                return end > start ? DateInterval(start: start, end: end) : nil
            }
            .sorted { $0.start < $1.start }
        let from = max(now, windowStart)
        guard from < windowEnd else { return advice }
        var gaps: [DateInterval] = []
        var cursor = from
        for interval in busy {
            if interval.start > cursor { gaps.append(DateInterval(start: cursor, end: interval.start)) }
            cursor = max(cursor, interval.end)
        }
        if cursor < windowEnd { gaps.append(DateInterval(start: cursor, end: windowEnd)) }

        let needed = Double(sessionMinutes * 60)
        if let slot = gaps.first(where: { $0.duration >= needed }) {
            // Seulement une journée chargée : sans événement, le créneau libre n'apprend rien.
            if !busy.isEmpty { advice.freeSlot = DateInterval(start: slot.start, duration: needed) }
        } else if let longest = gaps.max(by: { $0.duration < $1.duration }) {
            let minutes = Int(longest.duration / 60) / 5 * 5
            if minutes >= minimumMinutes { advice.shortOnTimeMinutes = minutes }
        }
        return advice
    }

    /// Déjeuner de 11 h à 15 h, dîner de 18 h à minuit ; à une autre heure, pas un repas.
    static func mealSlot(at date: Date, calendar: Calendar) -> MealSlot? {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 11..<15: return .lunch
        case 18..<24: return .dinner
        default: return nil
        }
    }

    static func matches(_ event: AgendaEvent, _ words: [String]) -> Bool {
        let text = " " + normalized(event.title + " " + (event.location ?? "")) + " "
        return words.contains { text.contains(" \($0) ") }
    }

    /// Minuscules sans accents, ponctuation remplacée par des espaces (l'apostrophe reste).
    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "’", with: "'")
        let cleaned = String(folded.map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " })
        return cleaned.split(separator: " ").joined(separator: " ")
    }
}
