/// Les seuls événements d'usage que l'app peut envoyer à un service de statistiques.
///
/// Règle (App Store 5.1.3, RGPD) : un événement dit qu'une fonction du coach a servi, rien
/// de plus. Aucun paramètre, donc aucune valeur : ni donnée de Santé, ni mesure du corps,
/// ni texte saisi, ni ajustement qui décrit l'état physique (fatigue, douleur, sommeil, cycle).
/// Ajouter un cas ici est la seule façon d'ajouter un événement.
public enum UsageEvent: String, CaseIterable, Sendable {
    /// Inscription terminée.
    case onboardingCompleted = "onboarding_completed"
    /// Un repas décrit (texte, photo ou repas repris) a été enregistré.
    case mealDescribed = "meal_described"
    /// L'aperçu « Envoyer sur ma Watch » a été ouvert.
    case watchPreviewOpened = "watch_preview_opened"
    /// La proposition du bilan de la semaine a été appliquée.
    case weeklyCheckInApplied = "weekly_checkin_applied"
    /// Un cycle d'entraînement a été démarré.
    case cycleStarted = "cycle_started"
    /// Le ressenti de la semaine a été donné (une fois par semaine, sans la réponse).
    case weekFeelingSaved = "week_feeling_saved"

    /// Nom envoyé : minuscules, chiffres et `_`, 40 caractères au plus, sans préfixe réservé.
    public var name: String { rawValue }
}
