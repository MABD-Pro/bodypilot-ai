# Règles du coach (lot 1, 100 % local)

Tout est déterministe et calculé sur l'appareil. Aucun appel IA.

## Besoins nutritionnels (`Nutrition/EnergyCalculator`)

- Métabolisme de base : Mifflin-St Jeor. Dépense = métabolisme × facteur d'activité (1,2 à 1,725).
- Objectif unique : la **recomposition** (perdre du gras en gardant ou en gagnant du muscle). L'utilisateur ne choisit pas entre perdre du poids et prendre du muscle.
- Déficit selon l'écart au poids visé : 20 % à 10 kg ou plus, proportionnel en dessous (5 % au minimum), aucun à moins de 0,5 kg du poids visé. Sans poids visé : 10 %. Plafonné à 600 kcal. **Plancher** : jamais sous le métabolisme de base, ni sous 1 500 kcal (homme) / 1 200 kcal (femme). Jamais de surplus.
- Protéines : 2,0 g/kg. Au-delà d'un IMC de 30, calculées sur le poids à IMC 27.
- Lipides : 27 % des calories. Glucides : le reste.
- Le poids utilisé est la **tendance mesurée** dès qu'elle existe, sinon le poids déclaré.

## Repas du jour (`Nutrition/MealPlanner`)

- Répartition : petit-déjeuner 25 %, déjeuner 35 %, collation 10 %, dîner 30 %.
- Modèles de repas tournants (variété sans saisie), portions ajustées entre ×0,5 et ×2, arrondies à 5 g ou à l'unité (œufs, fruits).
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

- L'utilisateur coche ses jours de séance habituels (par défaut lundi, mercredi, vendredi). Chaque semaine, il peut ajouter ou retirer un jour d'une touche ; ce choix ne vaut que pour la semaine en cours. Une semaine sans séance est possible.
- Fondements scientifiques et références : `docs/TRAINING_EVIDENCE.md`.
- Chaque séance enchaîne trois axes : musculation lourde en full body (A et B alternés : à la salle 4 × 5 à 8 répétitions sur les polyarticulaires, repos 2 à 3 min ; au poids du corps, variantes difficiles et tempo lent), puis un cardio varié qui change d'une séance à l'autre (rameur, vélo, corde, elliptique ; à la maison burpees, mountain climbers, jumping jacks, boxe), puis la marche inclinée ou l'escalier (tapis 10 à 12 %, stepper ; à la maison côte ou escaliers), qui sert aussi de retour au calme.
- Répartition : 60 % du temps pour la force, le reste partagé entre cardio et marche. Sous 30 minutes, la force seule.
- Jours sans séance : marche inclinée ou escalier, 30 min (marche tranquille en cas de fatigue).
- « Je n'ai que 20 minutes » : on raccourcit les repos, puis l'échauffement, puis les séries, puis on retire les accessoires. Les exercices essentiels restent. Sous 12 minutes, marche rapide.
- « Je suis fatigué » : une série de moins (minimum 2), variantes sans impact, effort modéré. Nutrition inchangée.
- « J'ai mal au genou » : variantes sans flexion chargée ni impact (pont fessier, hip thrust, bird dog…), et conseil de consulter si la douleur est vive, gonfle ou dure. Jour de repos : mobilité douce.
- « Je pars en déplacement » : séance au poids du corps, 30 minutes maximum.
- « J'ai raté ma séance » : jamais deux séances le même jour. Si le lendemain est un jour de repos, la séance y est proposée ; sinon on reprend au créneau suivant.
- « Machine prise, pas de barre » : chaque exercice a deux ou trois variantes du même mouvement, avec le même matériel. Une touche passe à la variante suivante, puis revient à l'exercice d'origine. Séries, volume et repos ne changent pas. Le choix vaut pour la journée. Les règles de sécurité restent prioritaires : avec un genou douloureux, une variante qui charge le genou est remplacée par la version qui l'épargne, et celle-ci ne se remplace pas.

## Séance sur l'Apple Watch (`Training/GuidedWorkout`)

- La séance envoyée est celle du jour, déjà adaptée (temps, fatigue, genou, déplacement).
- Chaque exercice devient un bloc répété autant de fois qu'il y a de séries : effort puis repos minuté.
- Une série en répétitions reste ouverte (on passe à la suite d'une touche) ; une série chronométrée et le repos ont une durée.
- Envoi via l'aperçu WorkoutKit : l'utilisateur confirme l'ajout sur sa montre, aucune autorisation supplémentaire.

## Records et charges (`Training/StrengthProgress`)

- Une touche sur un exercice de force aux répétitions note la meilleure série du jour (charge ou poids du corps, répétitions). Une seule par exercice et par jour : une nouvelle saisie remplace la précédente.
- Record : meilleur 1RM estimé (Epley, plafonné à 12 répétitions) ; au poids du corps, le plus de répétitions. Une série avec charge passe devant le poids du corps. Une première série n'est pas un record ; un record battu est fêté dans la carte Bouger et listé dans Progresser.
- Objectif suivant : si la dernière série a dépassé les répétitions prévues, charge + ~5 % (pas de 2,5 kg, 1 kg sous 30 kg) ; sinon même charge pour les répétitions prévues. Au poids du corps : une répétition de plus que la dernière fois, une fois les répétitions prévues atteintes.
- Chaque variante (remplacement, genou) a ses propres records : le nom affiché sert de clé.

## Progression (`ProgressInsights/WeightTrendAnalyzer`)

- Poids lissé (moyenne mobile exponentielle, 0,25) pour gommer l'eau et le sel.
- Vitesse : régression linéaire sur 21 jours, au moins 3 pesées sur 7 jours.
- En bonne voie entre −0,1 % et −1 % du poids par semaine ; au-delà de −1 %, le coach suggère +150 kcal. Le coach suggère, l'utilisateur décide.
- Tour de taille : saisi à la main, au plus une fois par semaine suffit. Variation sur 4 semaines, avec deux mesures espacées d'au moins 10 jours. Une baisse d'au moins 1 cm montre que le gras part, même si le poids ne bouge pas : le coach ne parle pas de stagnation.

## Régularité (`ProgressInsights/ConsistencyAnalyzer`)

- L'utilisateur coche « J'ai fait ma séance » (dans l'app ou par Siri). Un jour compte une fois ; un rattrapage un jour de repos compte aussi.
- Semaine du lundi au dimanche : séances faites sur séances prévues, une pastille par séance.
- Série : semaines complètes d'affilée, la semaine en cours comprise dès qu'elle est bouclée.
- Le message dit ce qui reste à faire pour boucler la semaine, sans culpabiliser.

## Bilan de la semaine (`Coach/WeeklyCheckIn`)

- Au plus une fois par semaine, sur la carte Progresser. Le coach propose, l'utilisateur applique ou repousse.
- Perte trop rapide (plus de 1 % par semaine) : +150 kcal. Prise trop rapide (plus de 0,5 %) : −150 kcal.
- Stagnation ou mauvaise direction : correction seulement si c'était déjà le cas une semaine plus tôt (pas de réaction à l'eau). Si le tour de taille a baissé d'au moins 1 cm, aucune correction : la recomposition fonctionne. Sans mesure de taille, le coach propose −150 kcal et demande de mesurer la taille.
- Corrections cumulées limitées à ±450 kcal ; jamais sous le plancher de sécurité, jamais de surplus. Sans effet réel, pas de proposition.

## Pesées importées de Santé (`ProgressInsights/WeightImportPlanner`)

- Lecture seule du poids (HealthKit, `bodyMass`), 90 jours en arrière à la connexion, puis à chaque retour dans l'app. Aucune donnée ne quitte l'iPhone.
- Une pesée par jour : la première de la journée (le plus souvent le matin à jeun).
- Un jour déjà renseigné n'est jamais écrasé : la saisie manuelle garde la main.
- Valeurs hors 25–350 kg écartées ; une mesure déjà importée (même identifiant Santé) ne revient pas.

## Ma semaine et séance en plus (`ProgressInsights/WeekActivityAnalyzer`, `Training/TrainingPlanner`)

- La carte Bouger montre la semaine en cours : minutes bougées par jour, puis chaque activité (séances cochées dans l'app et entraînements de Santé, Apple Watch comprise), avec durée et kcal.
- Une séance cochée sans renforcement enregistré dans Santé le même jour s'affiche à part ; avec un enregistrement de la Watch, elle n'apparaît qu'une fois.
- Une activité de Santé d'au moins 20 minutes, hors marche, compte comme une séance dans la régularité, même un jour non prévu.
- Les jours cochés sont un repère, pas une limite : « J'ai envie de bouger » (bouton des jours de repos, phrase libre ou Siri) donne une séance en plus. Elle enchaîne sur la séance qui suit la dernière cochée, pour faire travailler d'autres muscles. Un jour de séance, la séance prévue ne change pas. « Pas envie de bouger » ne déclenche rien.
- Apple Watch : la séance du jour ou la marche du jour de repos s'envoie d'une touche. « Planifier ma semaine sur la Watch » place les séances et les marches d'aujourd'hui à dimanche dans l'app Exercice (7 h). Aujourd'hui garde ses ajustements, les jours suivants partent du plan de base. Chaque envoi remplace le précédent.

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
