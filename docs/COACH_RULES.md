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

## Séance du jour (`Training/TrainingPlanner`)

- Calendrier fixe selon le nombre de séances (ex. 3 : lundi, mercredi, vendredi), deux full body alternés, poids du corps ou salle.
- Jours sans séance : repos actif (marche 30 min en perte de gras, 20 min sinon).
- « Je n'ai que 20 minutes » : on raccourcit les repos, puis l'échauffement, puis les séries, puis on retire les accessoires. Les exercices essentiels restent. Sous 12 minutes, marche rapide.
- « Je suis fatigué » : une série de moins (minimum 2), variantes sans impact, effort modéré. Nutrition inchangée.
- « J'ai raté ma séance » : jamais deux séances le même jour. Si le lendemain est un jour de repos, la séance y est proposée ; sinon on reprend au créneau suivant.

## Progression (`ProgressInsights/WeightTrendAnalyzer`)

- Poids lissé (moyenne mobile exponentielle, 0,25) pour gommer l'eau et le sel.
- Vitesse : régression linéaire sur 21 jours, au moins 3 pesées sur 7 jours.
- Perte de gras : en bonne voie entre −0,1 % et −1 % du poids par semaine ; au-delà de −1 %, le coach suggère +150 kcal. Le coach suggère, l'utilisateur décide.
