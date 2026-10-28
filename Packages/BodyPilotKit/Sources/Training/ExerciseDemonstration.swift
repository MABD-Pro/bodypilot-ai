import Foundation

/// Démonstration vidéo d'un exercice : une vidéo YouTube choisie et vérifiée à la main,
/// en français quand une bonne existe, lue dans l'app ; sinon une recherche YouTube sur la technique.
public enum ExerciseDemonstration {
    public static func url(for exercise: String) -> URL {
        if let id = videoID(for: exercise), let url = URL(string: "https://www.youtube.com/watch?v=\(id)") {
            return url
        }
        var search = URLComponents(string: "https://www.youtube.com/results")!
        search.queryItems = [URLQueryItem(name: "search_query", value: "\(exercise) technique")]
        return search.url!
    }

    /// Vrai quand la vidéo a été choisie, faux quand le lien ouvre une recherche.
    public static func hasChosenVideo(for exercise: String) -> Bool {
        videoID(for: exercise) != nil
    }

    /// « Marche du fermier (100 m) » partage la vidéo de « Marche du fermier ».
    static func videoID(for exercise: String) -> String? {
        videos[exercise] ?? videos[ExerciseGuide.baseName(exercise)]
    }

    /// Lecteur intégré sans cookies publicitaires (youtube-nocookie), lu dans la fiche sans quitter l'app.
    public static func embedURL(for exercise: String) -> URL? {
        guard let id = videoID(for: exercise) else { return nil }
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
        // Compléments d'isolation et équilibre
        "Élévations latérales haltères": "rtHgJXHMo7s",
        "Curl haltères": "8wvflicHXXw",
        "Extension triceps à la poulie": "jUUtHr42ra0",
        "Mollets debout à la machine": "yQv9y1oHitc",
        "Pompes diamant": "lp5MZ4XVbIA",
        "Pompes pike": "GJtgPG1pSFc",
        "Mollets sur une marche": "-hD4xqobyqk",
        "Équilibre sur une jambe": "FlLsGUIR-hI",
        "Good morning sans charge": "61zbhuRiwQg",
        // Cycle CrossFit, vérifiés le 28 octobre 2026. En anglais : Push press, Rowing aux anneaux, Wall ball.
        "Squat avant": "H_d6oaCKG0U",
        "Push press": "iaBVSJm78ko",
        "Tractions assistées": "WO5olJ6NASQ",
        "Rowing aux anneaux": "sEAOZc77wk8",
        "Thruster léger": "N0dtRABhraY",
        "Wall ball": "fpUD0mcFp_0",
        "Kettlebell swing": "gA5klxc7YrY",
        "Hang power clean": "wYnBdzF9Ixk",
        "Power clean": "Io4QsuRnhZg",
        // Ateliers Hyrox, vérifiés le 28 octobre 2026, tous en français (série « HYROX 360° »
        // de The Fit Protocol, sinon la plus courte des vidéos correctes).
        "SkiErg": "7UBh9GO0EHA",
        "Poussée de traîneau": "SnZ2lpELvHc",
        "Tirage de traîneau": "2l0gdo5H3Jw",
        "Burpees sautés en longueur": "EmdSHPjsn28",
        "Marche du fermier": "f1esxvhzcWc",
        "Fentes avec sac lesté": "PVA9xYD0ZyE",
        "Rameur": "GG_z7CnOWMI",
    ]
}
