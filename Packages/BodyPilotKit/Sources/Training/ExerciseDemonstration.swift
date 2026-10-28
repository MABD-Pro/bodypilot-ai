import Foundation

/// Démonstration vidéo d'un exercice : une vidéo YouTube choisie et vérifiée à la main,
/// en français quand une bonne existe, lue dans l'app ; sinon une recherche YouTube sur la technique.
public enum ExerciseDemonstration {
    public static func url(for exercise: String) -> URL {
        if let id = videos[exercise], let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
            return url
        }
        var search = URLComponents(string: "https://www.youtube.com/results")!
        search.queryItems = [URLQueryItem(name: "search_query", value: "\(exercise) technique")]
        return search.url!
    }

    /// Vrai quand la vidéo a été choisie, faux quand le lien ouvre une recherche.
    public static func hasChosenVideo(for exercise: String) -> Bool {
        videos[exercise] != nil
    }

    /// Lecteur intégré sans cookies publicitaires (youtube-nocookie), lu dans la fiche sans quitter l'app.
    public static func embedURL(for exercise: String) -> URL? {
        guard let id = videos[exercise] else { return nil }
        var embed = URLComponents(string: "https://www.youtube-nocookie.com/embed/\(id)")!
        embed.queryItems = [URLQueryItem(name: "playsinline", value: "1"), URLQueryItem(name: "rel", value: "0")]
        return embed.url
    }

    // Identifiants vérifiés le 27 octobre 2026 (vidéo en ligne et intégrable).
    // Vidéos en anglais, faute d'équivalent français correct : Step-ups haltères,
    // Squats tempo lent, Good morning sans charge.
    static let videos: [String: String] = [
        "Squat à la barre": "K5HuVGYcp50",
        "Développé couché": "feWp7jZopI8",
        "Tirage vertical lourd": "9kk_mZEghuY",
        "Soulevé de terre roumain": "ZR7uALySrLs",
        "Soulevé de terre": "nkzKGyk8U0k",
        "Développé militaire": "8ay3Bj5y-_E",
        "Rowing barre": "HZ9LxOlHUco",
        "Fentes bulgares haltères": "r_-HNEXkW00",
        "Hip thrust": "IMPB5EMTcqI",
        "Squat goblet lourd": "u9xM9NQ7tNw",
        "Presse à cuisses": "sfQKHQ2RWeo",
        "Développé couché haltères": "HBXn_SAlPw0",
        "Développé à la machine": "B-cCh7H0CPY",
        "Tractions": "b6KgEsSnhaY",
        "Tirage vertical prise serrée": "UUroZKE5gNo",
        "Tirage horizontal à la poulie": "w2Q7LbkhtLI",
        "Soulevé de terre roumain haltères": "hyBx3QViCw8",
        "Soulevé de terre à la trap bar": "KTJranIRvjw",
        "Développé militaire haltères": "CE9KiCPFw0E",
        "Développé épaules à la machine": "qrCPnVYJEo0",
        "Rowing haltère": "2P2TyrYyTmU",
        "Fentes marchées haltères": "T7j9efz104k",
        "Step-ups haltères": "WCFCdxzFBa4",
        "Squats bulgares": "V6U8pR-DPH0",
        "Squats tempo lent": "mmb618X9Ieg",
        "Step-ups sur une chaise": "yTRS_y4HT88",
        "Pompes": "jgJHg3rAOVg",
        "Pompes déclinées": "oDZIAsF0q4k",
        "Dips sur une chaise": "hIB3YWZk834",
        "Rowing inversé sous une table": "090g5co-zYU",
        "Superman au sol": "KuddSXD0Jk0",
        "Pont fessier une jambe": "EtfFV7THNh4",
        "Pont fessier pieds surélevés": "lpXC5v9TWXY",
        "Hip thrust une jambe": "qHaAALHvHCM",
        "Good morning sans charge": "61zbhuRiwQg",
    ]
}
