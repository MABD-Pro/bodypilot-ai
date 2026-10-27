# Règles du coach (lot 1, 100 % local)

Tout est déterministe et calculé sur l'appareil. Aucun appel IA.

## Besoins nutritionnels (`Nutrition/EnergyCalculator`)

- Métabolisme de base : Mifflin-St Jeor. Dépense = métabolisme × facteur d'activité (1,2 à 1,725).
- Perte de gras : déficit de 20 %, plafonné à 600 kcal. **Plancher** : jamais sous le métabolisme de base, ni sous 1 500 kcal (homme) / 1 200 kcal (femme).
- Prise de muscle : surplus de 10 %, plafonné à 300 kcal.
- Protéines : 2,0 g/kg (perte), 1,6 (maintien), 1,8 (prise). Au-delà d'un IMC de 30, calculées sur le poids à IMC 27.
- Lipides : 27 % des calories. Glucides : le reste.
- Le poids utilisé est la **tendance mesurée** dès qu'elle existe, sinon le poids déclaré.

## Repas du jour (`Nutrition/MealPlanner`)

- Répartition : petit-déjeuner 25 %, déjeuner 35 %, collation 10 %, dîner 30 %.
- Modèles de repas tournants (variété sans saisie), portions ajustées entre ×0,5 et ×2, arrondies à 5 g ou à l'unité (œufs, fruits).
- Valeurs nutritionnelles : moyennes arrondies, ordre de grandeur Ciqual. À remplacer par une vraie base.
- « Je mange au restaurant » : le prochain repas principal (déjeuner avant 15 h, dîner ensuite) devient « Au restaurant » avec quatre repères (protéine, légumes, une portion de féculents, un seul extra parmi sauce, dessert ou alcool). La collation est supprimée et son budget va au restaurant.
- « Je n'ai pas faim » : 85 % des calories, sans descendre sous le plancher de sécurité, collation dense en protéines.

## Séance du jour (`Training/TrainingPlanner`)

- Calendrier fixe selon le nombre de séances (ex. 3 : lundi, mercredi, vendredi), deux full body alternés, poids du corps ou salle.
- Jours sans séance : repos actif (marche 30 min en perte de gras, 20 min sinon).
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

## Progression (`ProgressInsights/WeightTrendAnalyzer`)

- Poids lissé (moyenne mobile exponentielle, 0,25) pour gommer l'eau et le sel.
- Vitesse : régression linéaire sur 21 jours, au moins 3 pesées sur 7 jours.
- Perte de gras : en bonne voie entre −0,1 % et −1 % du poids par semaine ; au-delà de −1 %, le coach suggère +150 kcal. Le coach suggère, l'utilisateur décide.

## Régularité (`ProgressInsights/ConsistencyAnalyzer`)

- L'utilisateur coche « J'ai fait ma séance » (dans l'app ou par Siri). Un jour compte une fois ; un rattrapage un jour de repos compte aussi.
- Semaine du lundi au dimanche : séances faites sur séances prévues, une pastille par séance.
- Série : semaines complètes d'affilée, la semaine en cours comprise dès qu'elle est bouclée.
- Le message dit ce qui reste à faire pour boucler la semaine, sans culpabiliser.

## Bilan de la semaine (`Coach/WeeklyCheckIn`)

- Au plus une fois par semaine, sur la carte Progresser. Le coach propose, l'utilisateur applique ou repousse.
- Perte trop rapide (plus de 1 % par semaine) : +150 kcal. Prise trop rapide (plus de 0,5 %) : −150 kcal.
- Stagnation ou mauvaise direction : correction seulement si c'était déjà le cas une semaine plus tôt (pas de réaction à l'eau).
- Corrections cumulées limitées à ±450 kcal ; jamais sous le plancher de sécurité, jamais de surplus pendant une perte de gras. Sans effet réel, pas de proposition.

## Pesées importées de Santé (`ProgressInsights/WeightImportPlanner`)

- Lecture seule du poids (HealthKit, `bodyMass`), 90 jours en arrière à la connexion, puis à chaque retour dans l'app. Aucune donnée ne quitte l'iPhone.
- Une pesée par jour : la première de la journée (le plus souvent le matin à jeun).
- Un jour déjà renseigné n'est jamais écrasé : la saisie manuelle garde la main.
- Valeurs hors 25–350 kg écartées ; une mesure déjà importée (même identifiant Santé) ne revient pas.

## Phrase libre (`Coach/CommandInterpreter`)

- « Je suis crevé, j'ai 15 min et resto ce soir » → fatigue + 15 minutes + restaurant.
- Passe par l'AIRouter au niveau déterministe : mots-clés français, sans accents ni casse, gratuit et hors ligne. Un temps précis (5 à 120 min) remplace les 20 minutes par défaut.
- Si les mots-clés ne reconnaissent rien, le modèle Apple embarqué (Foundation Models) prend le relais, s'il est disponible sur l'iPhone : gratuit, hors ligne, jamais de cloud. Phrases de plus de 280 caractères ignorées.
- Sa réponse est structurée (oui/non par ajustement, minutes, repas) puis contrôlée comme les mots-clés : temps entre 5 et 120 min, repas seulement si restaurant.
- Phrase toujours non comprise : le coach le dit et propose les ajustements en une touche.
