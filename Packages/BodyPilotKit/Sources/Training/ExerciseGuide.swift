import BodyPilotCore

/// Fiche d'un exercice de force : consignes clés, muscles travaillés et charge d'essai.
public struct ExerciseGuide: Sendable, Equatable {
    public var muscles: String
    public var cues: [String]
    /// La charge notée est celle d'un seul haltère.
    public var perDumbbell: Bool
    /// À la barre : la charge se règle par paires de disques, donc de 2,5 en 2,5 kg.
    public var barbell: Bool
    /// Charge d'essai en fraction du poids du corps ; `nil` au poids du corps.
    var startRatioMale: Double?
    var startRatioFemale: Double?

    init(muscles: String, cues: [String], perDumbbell: Bool = false, barbell: Bool = false, start: (Double, Double)? = nil) {
        self.muscles = muscles
        self.cues = cues
        self.perDumbbell = perDumbbell
        self.barbell = barbell
        startRatioMale = start?.0
        startRatioFemale = start?.1
    }

    public static func guide(for exercise: String) -> ExerciseGuide? {
        catalog[exercise] ?? catalog[baseName(exercise)]
    }

    /// Nom sans la distance : « SkiErg (250 m) » → « SkiErg ». Les ateliers Hyrox partagent
    /// une fiche et une vidéo quelle que soit la distance prescrite.
    static func baseName(_ exercise: String) -> String {
        guard exercise.hasSuffix(")"), let open = exercise.range(of: " (", options: .backwards) else { return exercise }
        return String(exercise[..<open.lowerBound])
    }

    /// Charge d'essai pour une première séance, volontairement prudente : la première série
    /// sert à se calibrer (1 à 2 répétitions en réserve), la progression prend ensuite le relais.
    public func startingLoad(bodyweightKg: Double, sex: BiologicalSex) -> Double? {
        guard let ratio = sex == .female ? startRatioFemale : startRatioMale else { return nil }
        let raw = bodyweightKg * ratio
        let step = barbell ? 2.5 : StrengthProgress.loadStep(for: raw)
        return max(step, (raw / step).rounded(.down) * step)
    }

    // Charges d'essai : repères prudents pour un débutant, en fraction du poids du corps.
    // Ce ne sont pas des résultats d'étude ; la première série notée les remplace.
    static let catalog: [String: ExerciseGuide] = [
        // Salle : mouvements principaux
        "Squat à la barre": ExerciseGuide(
            muscles: "Quadriceps, fessiers, adducteurs, gainage",
            cues: ["Barre sur le haut du dos, pieds largeur d'épaules, pointes légèrement ouvertes.", "Descends hanches et genoux ensemble, genoux dans l'axe des pieds.", "Cuisses au moins parallèles au sol, dos neutre, talons au sol.", "Remonte en poussant le sol, sans que le buste ne bascule."],
            barbell: true, start: (0.6, 0.4)
        ),
        "Développé couché": ExerciseGuide(
            muscles: "Pectoraux, triceps, épaules (avant)",
            cues: ["Omoplates serrées et basses, pieds bien ancrés au sol.", "Mains un peu plus larges que les épaules, poignets droits.", "Descends la barre au bas des pectoraux, coudes à environ 45°.", "Pousse en ligne vers le haut, sans décoller les fesses."],
            barbell: true, start: (0.5, 0.3)
        ),
        "Tirage vertical lourd": ExerciseGuide(
            muscles: "Grand dorsal, biceps, arrière d'épaule",
            cues: ["Cuisses calées, buste très légèrement incliné en arrière.", "Abaisse d'abord les épaules, puis tire les coudes vers les hanches.", "Barre jusqu'au haut de la poitrine, sans élan.", "Remonte en contrôlant, bras presque tendus."],
            start: (0.5, 0.35)
        ),
        "Soulevé de terre roumain": ExerciseGuide(
            muscles: "Ischio-jambiers, fessiers, lombaires",
            cues: ["Genoux légèrement fléchis et fixes pendant tout le mouvement.", "Pousse les hanches en arrière, barre collée aux cuisses.", "Descends tant que le dos reste plat, souvent mi-tibia.", "Remonte en serrant les fessiers, sans cambrer."],
            barbell: true, start: (0.5, 0.35)
        ),
        "Soulevé de terre": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers, dos, quadriceps",
            cues: ["Barre au-dessus du milieu du pied, tibias proches de la barre.", "Dos plat, poitrine sortie, bras tendus.", "Pousse le sol avec les jambes, la barre frôle les jambes.", "Verrouille en serrant les fessiers, sans basculer en arrière."],
            barbell: true, start: (0.75, 0.5)
        ),
        "Développé militaire": ExerciseGuide(
            muscles: "Épaules, triceps, haut des pectoraux",
            cues: ["Debout, fessiers et abdominaux serrés, sans cambrer.", "Barre au haut de la poitrine, avant-bras verticaux.", "Pousse vers le haut en reculant légèrement la tête.", "Bras tendus au-dessus de la tête, barre au-dessus des pieds."],
            barbell: true, start: (0.3, 0.2)
        ),
        "Rowing barre": ExerciseGuide(
            muscles: "Dos (milieu), grand dorsal, biceps",
            cues: ["Buste penché à environ 45°, dos plat, genoux fléchis.", "Tire la barre vers le nombril, coudes près du corps.", "Serre les omoplates en haut, une seconde.", "Redescends en contrôle, sans redresser le buste."],
            barbell: true, start: (0.45, 0.3)
        ),
        "Fentes bulgares haltères": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Pied arrière posé sur un banc, pied avant assez loin devant.", "Descends à la verticale, genou avant dans l'axe du pied.", "Genou arrière proche du sol, buste légèrement penché.", "Pousse dans le talon avant pour remonter."],
            perDumbbell: true, start: (0.1, 0.07)
        ),
        "Hip thrust": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers",
            cues: ["Haut du dos sur un banc, barre au pli de la hanche (avec une mousse).", "Pieds à plat, tibias verticaux en haut du mouvement.", "Monte en serrant les fessiers, sans cambrer.", "Menton rentré, regard vers l'avant."],
            barbell: true, start: (0.6, 0.5)
        ),
        // Salle : variantes
        "Squat goblet lourd": ExerciseGuide(
            muscles: "Quadriceps, fessiers, gainage",
            cues: ["Un haltère tenu contre la poitrine, coudes vers le bas.", "Descends entre les genoux, buste droit.", "Genoux dans l'axe des pieds, talons au sol.", "Remonte en poussant le sol."],
            start: (0.2, 0.15)
        ),
        "Presse à cuisses": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Bas du dos plaqué au dossier pendant tout le mouvement.", "Pieds largeur d'épaules au milieu du plateau.", "Descends jusqu'à environ 90° aux genoux, sans décoller les fesses.", "Pousse sans verrouiller complètement les genoux."],
            start: (1.0, 0.8)
        ),
        "Développé couché haltères": ExerciseGuide(
            muscles: "Pectoraux, triceps, épaules (avant)",
            cues: ["Omoplates serrées, pieds au sol.", "Haltères au niveau de la poitrine, coudes à environ 45°.", "Pousse vers le haut en rapprochant légèrement les haltères.", "Redescends lentement, étirement contrôlé."],
            perDumbbell: true, start: (0.15, 0.1)
        ),
        "Développé à la machine": ExerciseGuide(
            muscles: "Pectoraux, triceps",
            cues: ["Poignées à hauteur du milieu de la poitrine.", "Omoplates serrées contre le dossier.", "Pousse sans verrouiller les coudes.", "Reviens lentement jusqu'à l'étirement."],
            start: (0.45, 0.3)
        ),
        // Cycle CrossFit : Force C, technique, conditioning
        "Squat avant": ExerciseGuide(
            muscles: "Quadriceps, fessiers, gainage, haut du dos",
            cues: ["Barre posée sur l'avant des épaules, coudes hauts, doigts sous la barre.", "Buste droit pendant toute la descente.", "Descends entre les talons, genoux vers l'avant dans l'axe des pieds.", "Remonte en gardant les coudes hauts : s'ils tombent, la barre glisse."],
            barbell: true, start: (0.45, 0.3)
        ),
        "Push press": ExerciseGuide(
            muscles: "Épaules, triceps, jambes (impulsion)",
            cues: ["Barre sur l'avant des épaules, pieds largeur de hanches.", "Petite flexion des genoux, buste droit, talons au sol.", "Pousse fort avec les jambes et enchaîne avec les bras.", "Verrouille bras tendus au-dessus de la tête, tête passée sous la barre."],
            barbell: true, start: (0.35, 0.2)
        ),
        "Tractions assistées": ExerciseGuide(
            muscles: "Grand dorsal, biceps, gainage",
            cues: ["Élastique sous un pied ou un genou, ou machine assistée.", "Abaisse les épaules avant de tirer.", "Menton au-dessus de la barre, sans balancer.", "Diminue l'aide quand les répétitions prévues passent facilement."]
        ),
        "Rowing aux anneaux": ExerciseGuide(
            muscles: "Dos, biceps, arrière d'épaule, gainage",
            cues: ["Corps gainé en planche, talons au sol.", "Tire la poitrine vers les mains, coudes près du corps.", "Plus les pieds avancent, plus c'est dur.", "Redescends en contrôle, bras tendus."]
        ),
        "Thruster léger": ExerciseGuide(
            muscles: "Quadriceps, fessiers, épaules, triceps",
            cues: ["Barre ou haltères sur l'avant des épaules.", "Squat avant complet, buste droit.", "En remontant, enchaîne sans pause la poussée au-dessus de la tête.", "Charge légère : c'est un mouvement de rythme."],
            start: (0.25, 0.15)
        ),
        "Wall ball": ExerciseGuide(
            muscles: "Quadriceps, fessiers, épaules",
            cues: ["Balle contre la poitrine, face au mur, à un pas.", "Squat complet, buste droit.", "Lance avec les jambes vers la cible (2,7 à 3 m).", "Rattrape la balle en redescendant directement en squat."]
        ),
        "Kettlebell swing": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers, gainage",
            cues: ["Pieds un peu plus larges que les hanches, kettlebell devant toi.", "Pousse les hanches en arrière, dos plat, comme pour un soulevé de terre roumain.", "Projette les hanches vers l'avant : ce sont elles qui lancent, pas les bras.", "Kettlebell à hauteur des épaules, fessiers serrés en haut."],
            start: (0.2, 0.12)
        ),
        "Hang power clean": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers, trapèzes, gainage",
            cues: ["Départ debout, barre au-dessus des genoux, dos plat.", "Extension explosive des hanches, épaules qui haussent.", "Passe sous la barre et reçois-la sur l'avant des épaules, coudes hauts.", "Charge légère tant que le geste n'est pas propre : apprends-le avec un coach en box."],
            barbell: true, start: (0.3, 0.2)
        ),
        "Power clean": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers, quadriceps, trapèzes",
            cues: ["Départ au sol comme un soulevé de terre, barre au-dessus du milieu du pied.", "Décolle lentement jusqu'aux genoux, dos plat.", "Accélère, extension explosive des hanches.", "Reçois la barre sur l'avant des épaules, coudes hauts. Un coach en box corrigera mieux que l'app."],
            barbell: true, start: (0.35, 0.25)
        ),
        "Tractions": ExerciseGuide(
            muscles: "Grand dorsal, biceps, gainage",
            cues: ["Prise un peu plus large que les épaules, bras tendus.", "Abaisse les épaules puis tire les coudes vers les côtes.", "Menton au-dessus de la barre, sans balancer.", "Redescends jusqu'en bas, en contrôle. Trop dur : élastique ou machine assistée."]
        ),
        "Tirage vertical prise serrée": ExerciseGuide(
            muscles: "Grand dorsal, biceps, bas des trapèzes",
            cues: ["Poignée en V ou prise serrée, cuisses calées sous les boudins.", "Abaisse d'abord les épaules, buste légèrement incliné en arrière.", "Tire les coudes le long du corps jusqu'au haut de la poitrine.", "Remonte en contrôlant, bras presque tendus."],
            start: (0.5, 0.35)
        ),
        "Tirage horizontal à la poulie": ExerciseGuide(
            muscles: "Dos (milieu), grand dorsal, biceps",
            cues: ["Assis, buste droit, genoux légèrement fléchis.", "Tire la poignée vers le nombril, coudes près du corps.", "Serre les omoplates, sans pencher le buste en arrière.", "Reviens bras tendus, épaules vers l'avant."],
            start: (0.5, 0.35)
        ),
        "Soulevé de terre roumain haltères": ExerciseGuide(
            muscles: "Ischio-jambiers, fessiers, lombaires",
            cues: ["Un haltère dans chaque main, genoux légèrement fléchis.", "Hanches en arrière, haltères le long des jambes.", "Dos plat, descends jusqu'à l'étirement des ischios.", "Remonte en serrant les fessiers."],
            perDumbbell: true, start: (0.2, 0.15)
        ),
        "Soulevé de terre à la trap bar": ExerciseGuide(
            muscles: "Quadriceps, fessiers, dos",
            cues: ["Au centre de la barre hexagonale, pieds largeur de hanches.", "Hanches basses, dos plat, bras tendus.", "Pousse le sol pour te redresser.", "Repose la barre en contrôle, dos toujours plat."],
            barbell: true, start: (0.8, 0.55)
        ),
        "Développé militaire haltères": ExerciseGuide(
            muscles: "Épaules, triceps",
            cues: ["Assis ou debout, abdominaux serrés.", "Haltères à hauteur des épaules, paumes vers l'avant.", "Pousse vers le haut sans cambrer.", "Redescends jusqu'aux épaules, en contrôle."],
            perDumbbell: true, start: (0.12, 0.08)
        ),
        "Développé épaules à la machine": ExerciseGuide(
            muscles: "Épaules, triceps",
            cues: ["Dos plaqué au dossier, poignées à hauteur des épaules.", "Pousse vers le haut sans verrouiller.", "Redescends lentement.", "Pas d'élan avec les jambes."],
            start: (0.3, 0.2)
        ),
        "Rowing haltère": ExerciseGuide(
            muscles: "Grand dorsal, dos (milieu), biceps",
            cues: ["Une main et un genou sur un banc, dos plat.", "Tire l'haltère vers la hanche, coude près du corps.", "Pas de rotation du buste.", "Redescends bras tendu, en contrôle."],
            perDumbbell: true, start: (0.2, 0.14)
        ),
        "Fentes marchées haltères": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Grand pas en avant, buste droit.", "Genou arrière proche du sol, genou avant dans l'axe du pied.", "Pousse dans le talon avant pour enchaîner.", "Compte une répétition par jambe."],
            perDumbbell: true, start: (0.1, 0.07)
        ),
        "Step-ups haltères": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Box à hauteur de genou, pied entier posé dessus.", "Monte en poussant sur la jambe du haut, sans t'aider de l'autre.", "Redescends lentement.", "Compte les répétitions par jambe."],
            perDumbbell: true, start: (0.1, 0.07)
        ),
        // Maison : poids du corps
        "Squats bulgares": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Pied arrière sur une chaise, pied avant assez loin devant.", "Descends à la verticale, genou avant dans l'axe du pied.", "Genou arrière proche du sol.", "Trop facile : tiens un sac chargé."]
        ),
        "Squats tempo lent": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Descends en 3 secondes, pause d'une seconde en bas.", "Remonte en une seconde.", "Talons au sol, genoux dans l'axe des pieds.", "Cuisses au moins parallèles au sol."]
        ),
        "Step-ups sur une chaise": ExerciseGuide(
            muscles: "Quadriceps, fessiers",
            cues: ["Chaise stable, contre un mur.", "Monte en poussant sur la jambe du haut.", "Redescends lentement.", "Compte les répétitions par jambe."]
        ),
        "Pompes": ExerciseGuide(
            muscles: "Pectoraux, triceps, gainage",
            cues: ["Mains un peu plus larges que les épaules, corps gainé.", "Descends la poitrine près du sol, coudes à environ 45°.", "Pas de hanches qui tombent.", "Trop dur : mains surélevées sur une table."]
        ),
        "Pompes déclinées": ExerciseGuide(
            muscles: "Haut des pectoraux, épaules, triceps",
            cues: ["Pieds sur une chaise, mains au sol.", "Corps gainé de la tête aux pieds.", "Descends le front vers le sol, coudes à 45°.", "Pousse sans creuser le dos."]
        ),
        "Dips sur une chaise": ExerciseGuide(
            muscles: "Triceps, pectoraux",
            cues: ["Mains au bord d'une chaise stable, doigts vers l'avant.", "Descends jusqu'à environ 90° aux coudes.", "Dos proche de la chaise, épaules basses.", "Plus facile : jambes fléchies."]
        ),
        "Rowing inversé sous une table": ExerciseGuide(
            muscles: "Dos, biceps, arrière d'épaule",
            cues: ["Allongé sous une table solide, mains au bord.", "Corps gainé, talons au sol.", "Tire la poitrine vers la table.", "Plus facile : genoux fléchis."]
        ),
        "Rowing serviette à la porte": ExerciseGuide(
            muscles: "Dos, biceps",
            cues: ["Serviette passée autour de la poignée d'une porte fermée à clé.", "Pieds près de la porte, corps incliné en arrière.", "Tire la poitrine vers la porte.", "Plus tu es incliné, plus c'est dur."]
        ),
        "Superman au sol": ExerciseGuide(
            muscles: "Lombaires, fessiers, haut du dos",
            cues: ["Allongé sur le ventre, bras devant.", "Lève bras et jambes de quelques centimètres.", "Tiens deux secondes, regard vers le sol.", "Redescends doucement."]
        ),
        "Pont fessier une jambe": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers",
            cues: ["Sur le dos, un pied au sol, l'autre jambe tendue.", "Monte le bassin en serrant le fessier.", "Pas de cambrure en haut.", "Compte les répétitions par jambe."]
        ),
        "Pont fessier pieds surélevés": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers",
            cues: ["Sur le dos, talons sur une chaise.", "Monte le bassin en serrant les fessiers.", "Tiens une seconde en haut.", "Épargne le genou : pas de flexion chargée."]
        ),
        "Hip thrust une jambe": ExerciseGuide(
            muscles: "Fessiers, ischio-jambiers",
            cues: ["Haut du dos sur un canapé, un pied au sol.", "Monte le bassin en serrant le fessier.", "Tibia vertical en haut du mouvement.", "Compte les répétitions par jambe."]
        ),
        // Ateliers Hyrox : technique d'abord, la charge est celle de la course.
        "SkiErg": ExerciseGuide(
            muscles: "Grand dorsal, triceps, gainage, jambes",
            cues: ["Bras tendus au-dessus de la tête, poignées en main, pieds largeur de hanches.", "Tire en fléchissant les hanches et les genoux, comme une charnière : le buste descend avec les bras.", "Poignées jusqu'aux cuisses, puis remonte en déroulant, bras d'abord.", "Garde un rythme régulier : la puissance vient des hanches, pas seulement des bras."]
        ),
        "Poussée de traîneau": ExerciseGuide(
            muscles: "Quadriceps, fessiers, mollets, gainage",
            cues: ["Mains sur les poteaux, bras tendus ou fléchis, buste incliné à environ 45°.", "Petits pas rapides sur l'avant du pied, genoux qui avancent.", "Dos plat, regard vers le sol un peu devant.", "Ne t'arrête pas : relancer un traîneau à l'arrêt coûte bien plus cher."]
        ),
        "Tirage de traîneau": ExerciseGuide(
            muscles: "Dos, biceps, fessiers, ischio-jambiers",
            cues: ["Pieds écartés, genoux fléchis, assis en arrière comme sur une chaise.", "Tire la corde main sur main en gardant les bras proches du corps.", "Les jambes et les hanches participent : pousse dans le sol à chaque traction.", "Range la corde derrière toi pour ne pas t'y prendre les pieds."]
        ),
        "Burpees sautés en longueur": ExerciseGuide(
            muscles: "Corps entier : jambes, pectoraux, épaules, gainage",
            cues: ["Poitrine au sol, puis remonte en ramenant les pieds sous les hanches.", "Saut vers l'avant à deux pieds, bras qui balancent.", "Réception souple, genoux dans l'axe, puis enchaîne.", "Sauts courts et réguliers plutôt que longs et épuisants."]
        ),
        "Marche du fermier": ExerciseGuide(
            muscles: "Avant-bras (prise), trapèzes, gainage, jambes",
            cues: ["Ramasse les charges comme un soulevé de terre, dos plat.", "Épaules basses et en arrière, buste droit, bras le long du corps.", "Petits pas rapides, sans balancer les charges.", "Pose-les volontairement avant que la prise ne lâche, pas au dernier moment."]
        ),
        "Fentes avec sac lesté": ExerciseGuide(
            muscles: "Quadriceps, fessiers, gainage",
            cues: ["Sac sur les épaules, derrière la nuque, tenu des deux mains.", "Grand pas en avant, genou arrière qui frôle le sol.", "Genou avant dans l'axe du pied, buste droit.", "Pousse sur le talon avant pour enchaîner la fente suivante."]
        ),
        "Rameur": ExerciseGuide(
            muscles: "Jambes, dos, bras",
            cues: ["Ordre de la poussée : jambes, puis buste qui bascule légèrement en arrière, puis bras.", "Retour dans l'ordre inverse : bras, buste, puis jambes.", "Poignée jusqu'au bas des côtes, coudes près du corps.", "Environ 1 temps de tirage pour 2 temps de retour : la vitesse vient de la poussée des jambes."]
        ),
        "Good morning sans charge": ExerciseGuide(
            muscles: "Ischio-jambiers, lombaires",
            cues: ["Mains derrière la tête, genoux légèrement fléchis.", "Penche-toi en poussant les hanches en arrière.", "Dos plat jusqu'à l'étirement des ischios.", "Remonte en serrant les fessiers."]
        ),
    ]
}
