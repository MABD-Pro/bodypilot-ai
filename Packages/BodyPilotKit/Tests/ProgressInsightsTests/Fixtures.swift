import BodyPilotCore
import Foundation

let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    calendar.firstWeekday = 2
    return calendar
}()

func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    utc.date(from: DateComponents(year: year, month: month, day: day, hour: 8))!
}

/// Homme de 35 ans, 180 cm, 90 kg, actif modéré, perte de gras, 3 séances de 45 min à la maison.
func makeProfile(
    sex: BiologicalSex = .male,
    weightKg: Double = 90,
    targetWeightKg: Double? = 80,
    goal: Goal = .loseFat,
    daysPerWeek: Int = 3,
    sessionMinutes: Int = 45,
    equipment: Equipment = .bodyweight
) -> UserProfile {
    UserProfile(
        sex: sex,
        birthDate: day(1991, 1, 1),
        heightCm: 180,
        startWeightKg: weightKg,
        targetWeightKg: targetWeightKg,
        activity: .moderate,
        goal: goal,
        trainingDaysPerWeek: daysPerWeek,
        sessionMinutes: sessionMinutes,
        equipment: equipment
    )
}
