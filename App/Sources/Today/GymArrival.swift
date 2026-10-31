import CoreLocation
import OSLog
import UserNotifications

/// « Ma salle » : un rappel quand tu arrives à ta salle, pour ouvrir la séance du jour avec ses
/// charges. Le lieu est enregistré une fois, sur place, et reste sur l'iPhone ; c'est iOS qui
/// détecte l'arrivée (notification de lieu), l'app ne suit pas ta position.
enum GymArrival {
    static let notificationID = "coach.gym"
    /// Rayon autour de la salle : assez large pour la précision du GPS en intérieur.
    static let radius: CLLocationDistance = 150
    private static let latitudeKey = "gymLatitude"
    private static let longitudeKey = "gymLongitude"

    enum Failure: Error {
        case locationDenied
        case locationUnavailable
        case notificationsDenied
        /// Lieu enregistré, mais iOS ne peut plus repérer l'arrivée (autorisation « Une fois » expirée
        /// ou retirée) ; ou le rappel n'a pas pu être programmé.
        case notScheduled
    }

    /// iOS ne déclenche une notification de lieu qu'avec l'autorisation « Lorsque l'app est active »
    /// (ou « Toujours ») encore valable.
    static var canDetectArrival: Bool {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    /// Le rappel est-il bien en attente chez iOS ?
    static func isScheduled() async -> Bool {
        await UNUserNotificationCenter.current().pendingNotificationRequests().contains { $0.identifier == notificationID }
    }

    /// Le lieu enregistré, s'il y en a un.
    static var savedCoordinate: CLLocationCoordinate2D? {
        if LaunchOptions.demoGym { return CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522) }
        let defaults = UserDefaults.standard
        guard let latitude = defaults.object(forKey: latitudeKey) as? Double,
              let longitude = defaults.object(forKey: longitudeKey) as? Double else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Enregistre la position actuelle comme salle et programme le rappel d'arrivée.
    static func saveCurrentLocation() async -> Result<Void, Failure> {
        guard await CoachNotifications.requestAuthorization() else { return .failure(.notificationsDenied) }
        let location: CLLocation
        switch await currentLocation() {
        case .success(let found): location = found
        case .failure(let failure): return .failure(failure)
        }
        UserDefaults.standard.set(location.coordinate.latitude, forKey: latitudeKey)
        UserDefaults.standard.set(location.coordinate.longitude, forKey: longitudeKey)
        guard await schedule(at: location.coordinate) else { return .failure(.notScheduled) }
        return .success(())
    }

    /// Oublie la salle et le rappel.
    static func forget() {
        UserDefaults.standard.removeObject(forKey: latitudeKey)
        UserDefaults.standard.removeObject(forKey: longitudeKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    /// Le rappel se déclenche à chaque arrivée ; iOS s'en charge même si l'app est fermée.
    private static func schedule(at coordinate: CLLocationCoordinate2D) async -> Bool {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        let region = CLCircularRegion(center: coordinate, radius: radius, identifier: notificationID)
        region.notifyOnEntry = true
        region.notifyOnExit = false
        let content = UNMutableNotificationContent()
        content.title = "Te voilà à la salle"
        content.body = "Ta séance du jour t'attend dans BodyPilot, avec tes charges."
        content.sound = .default
        let trigger = UNLocationNotificationTrigger(region: region, repeats: true)
        do {
            try await center.add(UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger))
        } catch {
            AppLog.location.error("Rappel d'arrivée à la salle non programmé : \(error.localizedDescription, privacy: .public)")
            return false
        }
        let scheduled = await isScheduled()
        if !scheduled { AppLog.location.error("Rappel d'arrivée à la salle absent des notifications en attente") }
        return scheduled
    }

    /// Une position assez précise, demandée une fois (autorisation « Pendant l'utilisation »).
    private static func currentLocation() async -> Result<CLLocation, Failure> {
        await withTaskGroup(of: Result<CLLocation, Failure>.self) { group in
            group.addTask {
                let session = CLServiceSession(authorization: .whenInUse)
                defer { session.invalidate() }
                do {
                    for try await update in CLLocationUpdate.liveUpdates() {
                        if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                            return .failure(.locationDenied)
                        }
                        if let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 {
                            return .success(location)
                        }
                    }
                } catch {}
                return .failure(.locationUnavailable)
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(20))
                return .failure(.locationUnavailable)
            }
            let first = await group.next() ?? .failure(.locationUnavailable)
            group.cancelAll()
            return first
        }
    }
}
