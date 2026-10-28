# Règles du coach (lot 1, 100 % local)

Tout est déterministe et calculé sur l'appareil. Aucun appel IA.

## Besoins nutritionnels (`Nutrition/EnergyCalculator`)

- Métabolisme de base : Mifflin-St Jeor. Dépense = métabolisme × facteur de la vie quotidienne hors sport (1,2 / 1,3 / 1,4 / 1,55, choix BodyPilot) + dépense des séances faites (`ProgressInsights/ExerciseEnergy`).
- Séances : moyenne par jour des 14 jours précédents, plafonnée à 600 kcal. Un jour avec des entraînements dans Santé compte leurs calories actives. Un jour avec seulement une séance cochée est estimé par MET (Compendium, Ainsworth 2011) : (MET − 1) × poids × durée, avec force 5, cardio 6, marche 3,5. Jamais compté deux fois. Le déficit s'applique sur ce total. Siri et Raccourcis ne lisent pas Santé : ils ne comptent que les séances cochées.
- Objectif unique : la **recomposition** (perdre du gras en gardant ou en gagnant du muscle). L'utilisateur ne choisit pas entre perdre du poids et prendre du muscle.
- Déficit selon l'écart au poids visé : 20 % à 10 kg ou plus, proportionnel en dessous (5 % au minimum), aucun à moins de 0,5 kg du poids visé. Sans poids visé : 10 %. Plafonné à 600 kcal. **Plancher** : jamais sous le métabolisme de base, ni sous 1 500 kcal (homme) / 1 200 kcal (femme). Jamais de surplus.
- Protéines : 2,0 g/kg. Au-delà d'un IMC de 30, calculées sur le poids à IMC 27.
- Lipides : 27 % des calories. Glucides : le reste.
- Le poids utilisé est la **tendance mesurée** dès qu'elle existe, sinon le poids déclaré.

## Repas du jour (`Nutrition/MealPlanner`)

- Répartition : petit-déjeuner 25 %, déjeuner 35 %, collation 10 %, dîner 30 %.
- Protéines : 30 % du total du jour au petit-déjeuner, au déjeuner et au dîner, 10 % à la collation. Avec 2 g/kg, chaque repas principal dépasse 0,4 g/kg (Schoenfeld et Aragon, 2018). « Pas faim » ne réduit pas les protéines. Un repas allégé ou agrandi pour compenser garde sa proportion de protéines.
- Modèles de repas tournants (variété sans saisie), portions ajustées entre ×0,5 et ×2, arrondies à 5 g ou à l'unité (œufs, fruits). Les sources de protéines (au moins 30 % de leurs calories en protéines : viande, poisson, œufs, skyr, tofu, lentilles…) sont dosées pour l'objectif de protéines du repas, les accompagnements (×0,4 à ×2) pour les calories. Les calories passent avant si les deux ne tiennent pas ensemble.
- Valeurs nutritionnelles : moyennes arrondies, ordre de grandeur Ciqual. À remplacer par une vraie base.
- « Je mange au restaurant » : le prochain repas principal (déjeuner avant 15 h, dîner ensuite) devient « Au restaurant » avec quatre repères (protéine, légumes, une portion de féculents, un seul extra parmi sauce, dessert ou alcool). La collation est supprimée et son budget va au restaurant.
- « Je n'ai pas faim » : 85 % des calories, sans descendre sous le plancher de sécurité, collation dense en protéines.

## Repas pris (`Nutrition/MealPlanner`)

- Pour chaque repas, une touche : « Mangé comme prévu », ou bien sauté, plus léger (×0,6), plus copieux (×1,4), beaucoup plus copieux (×1,8). Pas de pesée ni de calcul.
- Les repas restants se recalculent pour viser le total du jour, dans une limite de ×0,6 à ×1,4 : on ne saute pas un repas pour compenser un excès, on ne double pas le dîner après un déjeuner sauté.
- Le coach le dit en une phrase, sans culpabiliser : une journée ne fait pas la tendance.

## Repas décrit en texte (`Nutrition/MealTextParser`, `Nutrition/MealDescriber`)

- « Décrire » sur un repas : l'utilisateur écrit ce qu'il a mangé, comme il le dirait (« une grande assiette de pâtes carbo et un coca »).
- Lecture locale d'abord : un catalogue d'environ 75 aliments et plats courants, les quantités en grammes ou en millilitres (« 200 g », « 33 cl »), en unités (« 2 œufs »), en contenants (« un bol », « une assiette », « une tranche ») et en tailles (« petite », « grande », « demi »).
- Sans quantité, la portion habituelle est proposée et le coach demande « Quelle quantité ? » : petite (×0,7), normale ou grande (×1,4). La question ne bloque pas l'enregistrement.
- Aliment inconnu du catalogue : le modèle Apple embarqué l'estime (jamais le cloud), dans des bornes réalistes (portion de 1 g à 1,5 kg, densité sous 900 kcal/100 g, calories recalculées depuis les macros si elles se contredisent). Sans modèle disponible, le coach demande de préciser les aliments.
- Photo (appareil photo ou photothèque), analysée sur l'iPhone et non conservée. Avec iOS 27, si le modèle embarqué voit les images, il décrit le repas en une phrase. Sinon, le classifieur d'images de Vision donne des étiquettes (environ 90 aliments), traduites en français (`PhotoLabelReader`, confiance d'au moins 30 %, 4 aliments au plus). La phrase préremplit la saisie : l'utilisateur la corrige, puis le coach demande les portions. Jamais de cloud.
- Le repas décrit remplace le repas prévu et la saisie d'une touche. Les repas suivants s'ajustent comme pour un repas pris (×0,6 à ×1,4).
- La carte Manger affiche, pour chaque macro, ce qui a été mangé sur l'objectif du jour, ainsi que les calories restantes.

## Séance du jour (`Training/TrainingPlanner`)

- Au jour le jour, sans planning : chaque jour, le coach propose 2 ou 3 activités et le repos, en recommande une et dit pourquoi ; l'utilisateur choisit d'une touche (le choix vaut pour la journée). Propositions : force (seulement si la dernière séance de force, cochée dans l'app ou renforcement d'au moins 20 min dans Santé, date d'au moins 48 h, ou s'il n'y en a jamais eu : full body lourd A puis B, ou test de force), « Cardio et marche inclinée » (à la maison « en côte » : cardio continu modéré et sans impact, puis marche inclinée), marche tranquille de 30 min, repos.
- Recommandation, dans l'ordre : séance ratée → marche tranquille ; 6 jours d'activité d'affilée (app ou Santé, 20 min au moins) → repos ; fatigue et nuit de moins de 6 h (sommeil lu dans Santé) → repos ; nuit de moins de 6 h → cardio et marche (marche tranquille si la force date de moins de 48 h) ; courbatures → cardio et marche ; force possible → force ; séance intense de 45 min ou plus la veille dans Santé (fractionné, cours, sport, combat, course) → marche tranquille ; sinon cardio et marche.
- « Comment te sens-tu ? » en tête de la carte Bouger : En forme, Courbatures, Fatigué. Fatigué est le même ajustement que « Je suis fatigué » (séance allégée) ; changer de ressenti revient à la recommandation du coach.
- Fondements scientifiques et références : `docs/TRAINING_EVIDENCE.md`.
- Chaque séance enchaîne trois axes : musculation lourde en full body (A et B alternés : à la salle 4 × 5 à 8 répétitions sur les polyarticulaires, repos 2 à 3 min ; au poids du corps, variantes difficiles et tempo lent), puis un cardio varié qui change d'une séance à l'autre (rameur, vélo, corde, elliptique ; à la maison burpees, mountain climbers, jumping jacks, boxe), puis la marche inclinée ou l'escalier (tapis 10 à 12 %, stepper ; à la maison côte ou escaliers), qui sert aussi de retour au calme.
- Répartition : 60 % du temps pour la force, le reste partagé entre cardio et marche. Sous 30 minutes, la force seule.
- « Je n'ai que 20 minutes » : on raccourcit les repos, puis l'échauffement, puis les séries, puis on retire les accessoires. Les exercices essentiels restent. Sous 12 minutes, marche rapide.
- « Je suis fatigué » : une série de moins (minimum 2), variantes sans impact, effort modéré. Nutrition inchangée.
- « J'ai mal au genou » : variantes sans flexion chargée ni impact (pont fessier, hip thrust, bird dog…), et conseil de consulter si la douleur est vive, gonfle ou dure. Jour de cardio : la marche en pente devient une marche à plat (ou vélo à la salle).
- « Je pars en déplacement » : séance au poids du corps, 30 minutes maximum.
- « J'ai raté ma séance » : jamais deux séances le même jour. Une marche tranquille le jour même ; la force non faite revient dès le lendemain, puisque la dernière force date toujours d'au moins 48 h.
- « Machine prise, pas de barre » : chaque exercice a deux ou trois variantes du même mouvement, avec le même matériel. Une touche passe à la variante suivante, puis revient à l'exercice d'origine. Séries, volume et repos ne changent pas. Le choix vaut pour la journée. Les règles de sécurité restent prioritaires : avec un genou douloureux, une variante qui charge le genou est remplacée par la version qui l'épargne, et celle-ci ne se remplace pas.

## Cycle de 12 semaines (`BodyPilotCore/Cycle`, `Training/StrengthCycle`)

- Choisi par l'utilisateur (salle) depuis la carte Bouger ; commence le jour même. Premier programme : vers le CrossFit (plan validé par Mounaïm le 2026-10-28). L'Hyrox suivra une fois son plan validé.
- 3 phases de 4 semaines (base, puissance, conditioning) ; la 4ᵉ semaine de chaque phase est allégée. Après la 12ᵉ semaine, le cycle s'arrête et la carte propose d'en recommencer un.
- Mouvements principaux (priorité 1) : semaine 1 : 3 × 6 à ~75 % du max, 3 répétitions en réserve ; semaine 2 : 4 × 6 à ~78 %, 2 en réserve ; semaine 3 : 4 × 5 à ~82 %, 1 en réserve ; semaine allégée : 2 × 5 à ~70 %, 4 en réserve. Exercices secondaires : 3 séries ; en semaine allégée, 2 séries à ~70 % du max. La semaine allégée raccourcit aussi la séance de force à 70 % du temps (au moins 30 min si le temps le permet) : le temps gagné ne part pas en cardio. Choix BodyPilot dans la fourchette de l'ACSM (2009) ; semaine allégée selon le consensus de Bell et al. (2023).
- Charge = pourcentage du max pondéré (`StrengthProgress.referenceOneRepMax`), arrondie aux disques en dessous ; elle remplace la surcharge progressive pendant le cycle. Le max se recalcule à chaque série notée : la phase suivante monte toute seule si la semaine 3 a progressé.
- Le coach du jour garde la main : fatigue, nuit courte, genou, temps limité et test de force passent avant le cycle. La note de la séance indique la semaine et la phase.
- Pas encore dans ce lot : Force C et nouveaux exercices, cardio progressif, EMOM/AMRAP, WOD de référence.

## Séance sur l'Apple Watch (`Training/GuidedWorkout`)

- La séance envoyée est celle du jour, déjà adaptée (temps, fatigue, genou, déplacement).
- Chaque exercice devient un bloc répété autant de fois qu'il y a de séries : effort puis repos minuté.
- Une série en répétitions reste ouverte (on passe à la suite d'une touche) ; une série chronométrée et le repos ont une durée.
- Envoi via l'aperçu WorkoutKit : l'utilisateur confirme l'ajout sur sa montre, aucune autorisation supplémentaire.

## Records et charges (`Training/StrengthProgress`)

- Une touche sur un exercice de force aux répétitions note la meilleure série du jour (charge ou poids du corps, répétitions). Une seule par exercice et par jour : une nouvelle saisie remplace la précédente.
- Record : meilleur 1RM estimé (Epley, plafonné à 12 répétitions) ; au poids du corps, le plus de répétitions. Une série avec charge passe devant le poids du corps. Une première série n'est pas un record ; un record battu est fêté dans la carte Bouger et listé dans Progresser.
- Max de référence : le meilleur 1RM estimé de l'exercice, pondéré par son ancienneté au moment de la dernière séance de force, puis par la pause depuis cette séance (dernière série notée, séance cochée ou entraînement de force dans Santé). Même barème pour les deux : jusqu'à 21 jours 100 %, jusqu'à 6 semaines 95 %, jusqu'à 3 mois 90 %, au-delà 85 %. La force maximale se maintient environ 3 semaines sans entraînement (Bosquet et al., 2013) ; les paliers suivants sont un choix prudent.
- Objectif suivant : la plus haute des deux charges, celle tirée du max de référence (répétitions prévues plus 2 en réserve, arrondie vers le bas) et la progression de la dernière série (charge + ~5 % si elle a dépassé les répétitions prévues, sinon même charge ; pas de 2,5 kg, 1 kg sous 30 kg).
- Pause de plus de 3 semaines : charge tirée du max de référence seulement, sans hausse, et une note de reprise en tête de la séance de force. Plus de 3 mois sans force : le test de force revient, son premier essai part du max pondéré. Au poids du corps : une répétition de plus que la dernière fois, une fois les répétitions prévues atteintes.
- Chaque variante (remplacement, genou) a ses propres records : le nom affiché sert de clé.
- Fiche exercice (`Training/ExerciseGuide`) : muscles travaillés et 4 consignes de technique pour chaque exercice de force du catalogue et ses variantes, dans la feuille de saisie. Pour les haltères, la charge notée est celle d'un haltère.
- Démonstration (`Training/ExerciseDemonstration`) : « Voir une démonstration » lit dans la fiche une vidéo YouTube choisie et vérifiée à la main, en français quand une bonne existe. Lecteur intégré youtube-nocookie (pas de cookies publicitaires tant que la vidéo n'est pas lancée), « Ouvrir dans YouTube » en secours. Sans vidéo choisie, « Chercher une démonstration » ouvre une recherche YouTube « <exercice> technique ». Aucune vidéo n'est stockée dans l'app.
- Charge d'essai (salle, avant toute série notée) : fraction prudente du poids du corps selon l'exercice et le sexe, arrondie vers le bas au pas de charge. Affichée « Essai : … » ; la première série notée la remplace.

## Calibrage des charges (`Training/StrengthCalibration`)

- À la salle, six mouvements de référence : squat, développé couché, rowing barre, soulevé de terre, développé militaire, tirage vertical à la poulie (pas de tractions). Tant que l'un d'eux n'a aucune charge notée, le jour de force devient un test.
- Deux séances de test, à 48 h d'écart : « Test de force 1/2 » (squat, développé couché, rowing) puis « 2/2 » (soulevé de terre, militaire, tirage vertical). Squat et soulevé de terre lourds ne se testent pas le même jour : les derniers mouvements seraient sous-estimés.
- Protocole par mouvement : 10 × 50 %, 5 × 70 %, 3 × 85 % du premier essai, puis séries de 5 en ajoutant ~10 % (jambes, 5 kg minimum) ou ~5 % (haut du corps, 2,5 kg minimum) tant que les 5 répétitions restent propres, 2 min 30 de repos. Le premier essai part de la charge d'essai prudente. L'utilisateur note sa série de 5 la plus lourde.
- Pas de test en cas de fatigue, de douleur au genou, en déplacement ou au poids du corps : la séance habituelle suit. Avec peu de temps, le test garde les mouvements qui tiennent dans la durée (au moins un). Le test ne se remplace pas et ne se resserre pas.
- Après le test : charge de travail = 1RM estimé (Epley) ramené aux répétitions prévues plus 2 en réserve, arrondi vers le bas. Les variantes (haltères, machines, hip thrust, roumain…) se déduisent du mouvement de référence par un ratio prudent, jusqu'à leur première série notée.
- L'inscription l'explique (écran « Ton point de départ »). Dans « Mon profil », « Refaire le test de force » (salle) remet le calibrage à zéro : seules les charges notées depuis comptent, le test revient au prochain jour de force et son premier essai part des dernières charges. Les records restent.

## Test de cardio (`Training/CardioTest`)

- Forme cardio = VO2max (ml/kg/min). La plus récente des mesures compte : la « Forme cardio » de l'Apple Watch lue dans Santé, ou un test de marche noté dans l'app.
- Sans mesure de moins de 8 semaines avant ce jour, un jour de cardio devient « Test de cardio : 1,6 km de marche ». C'est seulement possible sans fatigue, courbatures, nuit courte ni genou sensible, et avec au moins 25 min. Un jour de force, la force reste recommandée. Le test se fait en marchant le plus vite possible, sans courir, sur terrain plat. La Watch reçoit un objectif de 1,6 km.
- « Noter mon test » : temps et pouls à l'arrivée → VO2max par l'équation de Rockport. Un test par jour, corrigeable.
- Zone de cardio modéré : 40 à 59 % de la réserve cardiaque si le pouls au repos est connu (Santé), sinon 64 à 76 % de la fréquence maximale (208 − 0,7 × âge). Elle s'affiche dans la consigne des jours de cardio et dans Progresser.
- Siri et Raccourcis ne lisent pas Santé : ils ne voient que les tests notés dans l'app.

## Progression (`ProgressInsights/WeightTrendAnalyzer`)

- Poids lissé (moyenne mobile exponentielle, 0,25) pour gommer l'eau et le sel.
- Vitesse : régression linéaire sur 21 jours, au moins 3 pesées sur 7 jours.
- En bonne voie entre −0,1 % et −1 % du poids par semaine ; au-delà de −1 %, le coach suggère +150 kcal. Le coach suggère, l'utilisateur décide.
- Tour de taille : saisi à la main, au plus une fois par semaine suffit. Variation sur 4 semaines, avec deux mesures espacées d'au moins 10 jours. Une baisse d'au moins 1 cm montre que le gras part, même si le poids ne bouge pas : le coach ne parle pas de stagnation.
- Scan LiDAR du tour de taille (expérimental, iPhone Pro) : une personne tient l'iPhone et place la ligne centrale sur le nombril, de face puis de profil, bras croisés. Pour chaque vue, 15 images : largeur du corps sur la ligne (pixels dont la profondeur est à moins de 30 cm de celle du nombril, × distance / focale), médiane, puis périmètre d'une ellipse (Ramanujan). Le scan est enregistré à part (`WaistRecord.isScan`) : il n'entre ni dans la tendance ni dans le bilan. L'historique affiche l'écart moyen avec le ruban du même jour ; il ne remplacera le ruban que si l'écart reste sous 1 cm pendant deux semaines (choix BodyPilot).

## Régularité

- Pas d'objectif par semaine : la séance se décide au jour le jour. « Ma semaine » (carte Bouger) montre ce qui a été fait. `ProgressInsights/ConsistencyAnalyzer` reste disponible mais n'est plus affiché.

## Bilan de la semaine (`Coach/WeeklyCheckIn`)

- Au plus une fois par semaine, sur la carte Progresser. Le coach propose, l'utilisateur applique ou repousse.
- Perte trop rapide (plus de 1 % par semaine) : +150 kcal. Prise trop rapide (plus de 0,5 %) : −150 kcal.
- Stagnation ou mauvaise direction : correction seulement si c'était déjà le cas une semaine plus tôt (pas de réaction à l'eau). Si le tour de taille a baissé d'au moins 1 cm, aucune correction : la recomposition fonctionne. Sans mesure de taille, le coach propose −150 kcal et demande de mesurer la taille.
- Corrections cumulées limitées à ±450 kcal ; jamais sous le plancher de sécurité, jamais de surplus. Sans effet réel, pas de proposition.
- Cycle menstruel (femmes, suivi de cycle noté dans Santé) : pas de baisse proposée pendant les 5 premiers jours des règles ni les 5 jours qui les précèdent (prévus d'après la durée moyenne des 3 derniers cycles de 21 à 35 jours). La rétention d'eau y masque la perte de gras (White et al., 2011). Une hausse pour perte trop rapide reste proposée.
- L'objectif proposé tient compte de la dépense des séances, comme celui du jour.

## Pesées importées de Santé (`ProgressInsights/WeightImportPlanner`)

- Lecture seule du poids (HealthKit, `bodyMass`), 90 jours en arrière à la connexion, puis à chaque retour dans l'app. Aucune donnée ne quitte l'iPhone.
- Santé fournit aussi, en lecture : les entraînements (Watch, cours collectifs, autres apps), le sommeil de la nuit passée, la VO2max et le pouls au repos, et pour les femmes le suivi des règles (120 jours ; un saignement après 10 jours sans flux ouvre un nouveau cycle). Progresser affiche ce qui est relié et la nuit dernière.
- Profil : la taille, la date de naissance et le sexe de Santé remplacent ceux du profil à chaque retour dans l'app, donc les besoins se recalculent. « Mon profil » affiche le poids de la dernière pesée. Un poids modifié là devient la pesée du jour, et le poids de départ ne change pas.
- Une pesée par jour : la première de la journée (le plus souvent le matin à jeun).
- Un jour déjà renseigné n'est jamais écrasé : la saisie manuelle garde la main.
- Valeurs hors 25–350 kg écartées ; une mesure déjà importée (même identifiant Santé) ne revient pas.
- Composition corporelle (balance à impédance) : taux de gras (`bodyFatPercentage`) et masse maigre (`leanBodyMass`) lus dans Santé, 90 jours, une mesure par jour, valeurs aberrantes écartées (gras hors 3–70 %, masse maigre hors 20–150 kg). Sans masse maigre, elle se déduit du poids du même jour. Rien n'est enregistré dans l'app : Santé reste la source.
- Progresser affiche la moyenne de la dernière semaine de mesures et l'écart avec la première semaine sur 4 semaines (au moins 2 semaines de recul). Une mesure d'impédance varie avec l'hydratation : seule la tendance compte.
- Recomposition : une baisse du taux de gras d'au moins 0,5 point (choix BodyPilot) joue le même rôle que la taille qui baisse : message de progrès et aucune baisse de calories au bilan.

## Ma semaine (`ProgressInsights/WeekActivityAnalyzer`)

- La carte Bouger montre la semaine en cours : minutes bougées par jour, puis chaque activité (séances cochées dans l'app et entraînements de Santé, Apple Watch comprise), avec durée et kcal.
- Une séance cochée sans renforcement enregistré dans Santé le même jour s'affiche à part ; avec un enregistrement de la Watch, elle n'apparaît qu'une fois.
- Apple Watch : la séance du jour (celle choisie) s'envoie d'une touche. Pas de planning de semaine : la séance se décide chaque jour.

## Repas envoyés vers Santé (`Nutrition/HealthMealExport`)

- Avec Santé relié, chaque repas mangé (« Comme prévu », plus ou moins, décrit en texte ou en photo) part dans Santé > Nutrition : énergie consommée, protéines, glucides, lipides, nommés d'après le repas.
- Heure habituelle du repas (8 h, 12 h 30, 16 h 30, 20 h), jamais dans le futur.
- Identifiant stable par jour et par repas : une modification remplace les valeurs, une annulation ou un repas sauté les retire. Rien n'est réécrit tant que le contenu ne change pas.
- Écriture refusée dans Santé : l'app fonctionne sans. Rien ne quitte l'iPhone.

## Phrase libre (`Coach/CommandInterpreter`)

- « Je suis crevé, j'ai 15 min et resto ce soir » → fatigue + 15 minutes + restaurant.
- Passe par l'AIRouter au niveau déterministe : mots-clés français, sans accents ni casse, gratuit et hors ligne. Un temps précis (5 à 120 min) remplace les 20 minutes par défaut.
- Si les mots-clés ne reconnaissent rien, le modèle Apple embarqué (Foundation Models) prend le relais, s'il est disponible sur l'iPhone : gratuit, hors ligne, jamais de cloud. Phrases de plus de 280 caractères ignorées.
- Sa réponse est structurée (oui/non par ajustement, minutes, repas) puis contrôlée comme les mots-clés : temps entre 5 et 120 min, repas seulement si restaurant.
- Phrase toujours non comprise : le coach le dit et propose les ajustements en une touche.

## Historique (`App/History/HistoryView`, `ProgressInsights/SessionHistory`)

- Depuis Progresser, « Historique » ouvre quatre parties : Mesures, Force, Séances, Repas.
- Mesures : courbe des pesées, puis jour par jour le poids, le tour de taille et le taux de gras (balance dans Santé).
- Force : par exercice, courbe du 1RM estimé (Epley) de la meilleure série de chaque séance, puis toutes les séries notées, tests compris.
- Séances : jour par jour, les séances cochées dans l'app et les entraînements lus dans Santé (durée, calories).
- Repas : jour par jour, la saisie d'une touche de chaque repas ou le repas décrit avec ses calories. Les calories d'un repas « comme prévu » ne sont pas gardées : le plan d'un jour passé n'est pas recalculé.
- Démo : `-demoHistory Force` ouvre l'historique sur une partie.
